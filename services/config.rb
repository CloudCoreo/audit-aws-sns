coreo_aws_rule "sns-topics-inventory" do
  action :define
  service :sns
  link "http://kb.cloudcoreo.com/mydoc-inventory.html"
  include_violations_in_count false
  display_name "SNS Topics Inventory"
  description "This rule performs an inventory on all sns topics in the target AWS account."
  category "Inventory"
  suggested_action "None."
  level "Informational"
  objectives ["topics"]
  audit_objects ["object.topics.topic_arn"]
  operators ["=~"]
  raise_when [//]
  id_map "object.topics.topic_arn"
end

coreo_aws_rule "sns-subscriptions-inventory" do
  action :define
  service :sns
  link "http://kb.cloudcoreo.com/mydoc-inventory.html"
  include_violations_in_count false
  display_name "SNS Subscriptions Inventory"
  description "This rule performs an inventory on all sns subscriptions in the target AWS account."
  category "Inventory"
  suggested_action "None."
  level "Informational"
  objectives ["subscriptions"]
  audit_objects ["object.subscriptions.subscription_arn"]
  operators ["=~"]
  raise_when [//]
  id_map "object.subscriptions.subscription_arn"
end

coreo_uni_util_variables "sns-planwide" do
  action :set
  variables([
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.composite_name' => 'PLAN::stack_name'},
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.plan_name' => 'PLAN::name'},
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.results' => 'unset'},
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.number_violations' => 'unset'}
            ])
end


coreo_aws_rule_runner "advise-sns" do
  action :run
  rules ${AUDIT_AWS_SNS_ALERT_LIST}
  service :sns
  regions ${AUDIT_AWS_SNS_REGIONS}
end

coreo_uni_util_variables "sns-update-planwide-1" do
  action :set
  variables([
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.results' => 'COMPOSITE::coreo_aws_rule_runner.advise-sns.report'},
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.number_violations' => 'COMPOSITE::coreo_aws_rule_runner.advise-sns.number_violations'},

            ])
end

coreo_uni_util_jsrunner "tags-to-notifiers-array-sns" do
  action :run
  data_type "json"
  provide_composite_access true
  packages([
               {
                   :name => "cloudcoreo-jsrunner-commons",
                   :version => "*"
               },
               {
                   :name => "js-yaml",
                   :version => "3.7.0"
               }
           ])
  json_input '{ "composite name":"PLAN::stack_name",
                "plan name":"PLAN::name",
                "cloud account name": "PLAN::cloud_account_name",
                "violations": COMPOSITE::coreo_aws_rule_runner.advise-sns.report}'
  function <<-EOH



function setTableAndSuppression() {
  let table;
  let suppression;

  const fs = require('fs');
  const yaml = require('js-yaml');
  try {
      suppression = yaml.safeLoad(fs.readFileSync('./suppression.yaml', 'utf8'));
  } catch (e) {
      console.log("Error reading suppression.yaml file: " , e);
      suppression = {};
  }
  try {
      table = yaml.safeLoad(fs.readFileSync('./table.yaml', 'utf8'));
  } catch (e) {
      console.log("Error reading table.yaml file: ", e);
      table = {};
  }
  coreoExport('table', JSON.stringify(table));
  coreoExport('suppression', JSON.stringify(suppression));
  
  let alertListToJSON = "${AUDIT_AWS_SNS_ALERT_LIST}";
  let alertListArray = alertListToJSON.replace(/'/g, '"');
  json_input['alert list'] = alertListArray || [];
  json_input['suppression'] = suppression || [];
  json_input['table'] = table || {};
}


setTableAndSuppression();

const JSON_INPUT = json_input;
const NO_OWNER_EMAIL = "${AUDIT_AWS_SNS_ALERT_RECIPIENT}";
const OWNER_TAG = "${AUDIT_AWS_SNS_OWNER_TAG}";
const ALLOW_EMPTY = "${AUDIT_AWS_SNS_ALLOW_EMPTY}";
const SEND_ON = "${AUDIT_AWS_SNS_SEND_ON}";
const SHOWN_NOT_SORTED_VIOLATIONS_COUNTER = false;

const SETTINGS = { NO_OWNER_EMAIL, OWNER_TAG, 
    ALLOW_EMPTY, SEND_ON, SHOWN_NOT_SORTED_VIOLATIONS_COUNTER};

const CloudCoreoJSRunner = require('cloudcoreo-jsrunner-commons');
const AuditSNS = new CloudCoreoJSRunner(JSON_INPUT, SETTINGS);
const letters = AuditSNS.getLetters();

const newJSONInput = AuditSNS.getSortedJSONForAuditPanel();
coreoExport('JSONReport', JSON.stringify(newJSONInput));
coreoExport('report', JSON.stringify(newJSONInput['violations']));

callback(letters);
  EOH
end

coreo_uni_util_variables "sns-update-planwide-3" do
  action :set
  variables([
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.results' => 'COMPOSITE::coreo_uni_util_jsrunner.tags-to-notifiers-array-sns.JSONReport'},
                {'COMPOSITE::coreo_aws_rule_runner.advise-sns.report' => 'COMPOSITE::coreo_uni_util_jsrunner.tags-to-notifiers-array-sns.report'},
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.table' => 'COMPOSITE::coreo_uni_util_jsrunner.tags-to-notifiers-array-sns.table'}
            ])
end

coreo_uni_util_jsrunner "tags-rollup-sns" do
  action :run
  data_type "text"
  json_input 'COMPOSITE::coreo_uni_util_jsrunner.tags-to-notifiers-array-sns.return'
  function <<-EOH
const notifiers = json_input;

function setTextRollup() {
    let emailText = '';
    let numberOfViolations = 0;
    notifiers.forEach(notifier => {
        const hasEmail = notifier['endpoint']['to'].length;
        if(hasEmail) {
            numberOfViolations += parseInt(notifier['num_violations']);
            emailText += "recipient: " + notifier['endpoint']['to'] + " - " + "Violations: " + notifier['num_violations'] + "\\n";
        }
    });

    textRollup += 'Number of Violating Cloud Objects: ' + numberOfViolations + "\\n";
    textRollup += 'Rollup' + "\\n";
    textRollup += emailText;
}


let textRollup = '';
setTextRollup();

callback(textRollup);
  EOH
end

coreo_uni_util_notify "advise-sns-to-tag-values" do
  action((("${AUDIT_AWS_SNS_ALERT_RECIPIENT}".length > 0)) ? :notify : :nothing)
  notifiers 'COMPOSITE::coreo_uni_util_jsrunner.tags-to-notifiers-array-sns.return'
end

coreo_uni_util_notify "advise-sns-rollup" do
  action((("${AUDIT_AWS_SNS_ALERT_RECIPIENT}".length > 0) and (! "${AUDIT_AWS_SNS_OWNER_TAG}".eql?("NOT_A_TAG"))) ? :notify : :nothing)
  type 'email'
  allow_empty ${AUDIT_AWS_SNS_ALLOW_EMPTY}
  send_on '${AUDIT_AWS_SNS_SEND_ON}'
  payload '
composite name: PLAN::stack_name
plan name: PLAN::name
COMPOSITE::coreo_uni_util_jsrunner.tags-rollup-sns.return
  '
  payload_type 'text'
  endpoint ({
      :to => '${AUDIT_AWS_SNS_ALERT_RECIPIENT}', :subject => 'CloudCoreo sns rule results on PLAN::stack_name :: PLAN::name'
  })
end

