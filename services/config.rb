coreo_aws_rule "sns-topics-inventory" do
  action :define
  service :sns
  link "http://kb.cloudcoreo.com/mydoc_all-inventory.html"
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

coreo_aws_rule "sns-topics-inventory-internal" do
  action :define
  service :sns
  include_violations_in_count false
  link "http://kb.cloudcoreo.com/mydoc_unused-alert-definition.html"
  display_name "CloudCoreo Use Only"
  description "This is an internally defined alert."
  category "Internal"
  suggested_action "Ignore"
  level "Internal"
  objectives ["topics"]
  audit_objects ["object.topics.topic_arn"]
  operators ["=~"]
  raise_when [//]
  id_map "object.topics.topic_arn"
end

coreo_aws_rule "sns-subscriptions-inventory" do
  action :define
  service :sns
  link "http://kb.cloudcoreo.com/mydoc_all-inventory.html"
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

coreo_aws_rule "sns-subscriptions-inventory-internal" do
  action :define
  service :sns
  include_violations_in_count false
  link "http://kb.cloudcoreo.com/mydoc_unused-alert-definition.html"
  display_name "CloudCoreo Use Only"
  description "This is an internally defined alert."
  category "Internal"
  suggested_action "Ignore"
  level "Internal"
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
                {'GLOBAL::number_violations' => '0'}
            ])
end


coreo_aws_rule_runner "advise-sns" do
  action :run
  rules ${AUDIT_AWS_SNS_ALERT_LIST}
  service :sns
  regions ${AUDIT_AWS_SNS_REGIONS}
  filter(${FILTERED_OBJECTS}) if ${FILTERED_OBJECTS}
end

coreo_uni_util_variables "sns-update-planwide-1" do
  action :set
  variables([
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.results' => 'COMPOSITE::coreo_aws_rule_runner.advise-sns.report'},
                {'GLOBAL::number_violations' => 'COMPOSITE::coreo_aws_rule_runner.advise-sns.number_violations'},

            ])
end

coreo_uni_util_jsrunner "tags-to-notifiers-array-sns" do
  action :run
  data_type "json"
  provide_composite_access true
  packages([
               {
                   :name => "cloudcoreo-jsrunner-commons",
                   :version => "1.9.7-beta34"
               },
               {
                   :name => "js-yaml",
                   :version => "3.7.0"
               }
           ])
  json_input '{ "compositeName":"PLAN::stack_name",
                "planName":"PLAN::name",
                "cloudAccountName": "PLAN::cloud_account_name",
                "violations": COMPOSITE::coreo_aws_rule_runner.advise-sns.report}'
  function <<-EOH

const compositeName = json_input.compositeName;
const planName = json_input.planName;
const cloudAccount = json_input.cloudAccountName;
const cloudObjects = json_input.violations;

const NO_OWNER_EMAIL = "${AUDIT_AWS_SNS_ALERT_RECIPIENT}";
const OWNER_TAG = "${AUDIT_AWS_SNS_OWNER_TAG}";
const ALLOW_EMPTY = "${AUDIT_AWS_SNS_ALLOW_EMPTY}";
const SEND_ON = "${AUDIT_AWS_SNS_SEND_ON}";

const alertListArray = ${AUDIT_AWS_SNS_ALERT_LIST};
const ruleInputs = {};

let userSuppression;
let userSchemes;

const fs = require('fs');
const yaml = require('js-yaml');

function setSuppression() {
  userSuppression = yaml.safeLoad(fs.readFileSync('./suppression.yaml', 'utf8'));
  coreoExport('suppression', JSON.stringify(userSuppression));
}

function setTable() {
  userSchemes = yaml.safeLoad(fs.readFileSync('./table.yaml', 'utf8'));
  coreoExport('table', JSON.stringify(userSchemes));
}
setSuppression();
setTable();

const argForConfig = {
    NO_OWNER_EMAIL, cloudObjects, userSuppression, OWNER_TAG,
    userSchemes, alertListArray, ruleInputs, ALLOW_EMPTY,
    SEND_ON, cloudAccount, compositeName, planName
}


function createConfig(argForConfig) {
    let JSON_INPUT = {
        compositeName: argForConfig.compositeName,
        planName: argForConfig.planName,
        violations: argForConfig.cloudObjects,
        userSchemes: argForConfig.userSchemes,
        userSuppression: argForConfig.userSuppression,
        alertList: argForConfig.alertListArray,
        disabled: argForConfig.ruleInputs,
        cloudAccount: argForConfig.cloudAccount
    };
    let SETTINGS = {
        NO_OWNER_EMAIL: argForConfig.NO_OWNER_EMAIL,
        OWNER_TAG: argForConfig.OWNER_TAG,
        ALLOW_EMPTY: argForConfig.ALLOW_EMPTY, SEND_ON: argForConfig.SEND_ON,
        SHOWN_NOT_SORTED_VIOLATIONS_COUNTER: false
    };
    return {JSON_INPUT, SETTINGS};
}

const {JSON_INPUT, SETTINGS} = createConfig(argForConfig);
const CloudCoreoJSRunner = require('cloudcoreo-jsrunner-commons');

const emails = CloudCoreoJSRunner.createEmails(JSON_INPUT, SETTINGS);
const suppressionJSON = CloudCoreoJSRunner.createJSONWithSuppress(JSON_INPUT, SETTINGS);

coreoExport('JSONReport', JSON.stringify(suppressionJSON));
coreoExport('report', JSON.stringify(suppressionJSON['violations']));

callback(emails);
  EOH
end

coreo_uni_util_variables "sns-update-planwide-3" do
  action :set
  variables([
                {'COMPOSITE::coreo_uni_util_variables.sns-planwide.results' => 'COMPOSITE::coreo_uni_util_jsrunner.tags-to-notifiers-array-sns.JSONReport'},
                {'COMPOSITE::coreo_aws_rule_runner.advise-sns.report' => 'COMPOSITE::coreo_uni_util_jsrunner.tags-to-notifiers-array-sns.report'},
                {'GLOBAL::table' => 'COMPOSITE::coreo_uni_util_jsrunner.tags-to-notifiers-array-sns.table'}
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

