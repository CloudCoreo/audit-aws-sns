
coreo_aws_rule "sns-inventory" do
  action :define
  service :sns
  link "http://kb.cloudcoreo.com/mydoc-inventory.html"
  include_violations_in_count false
  display_name "SNS Inventory"
  description "This rule performs an inventory on all sns objects in the target AWS account."
  category "Inventory"
  suggested_action "None."
  level "Informational"
  meta_cis_id "99.999"
  objectives ["topics"]
  audit_objects ["object.topics.topic_arn"]
  operators ["=~"]
  raise_when [//]
  id_map "object.topics.topic_arn"
end

coreo_aws_rule_runner "advise-sns" do
  rules ${AUDIT_AWS_SNS_ALERT_LIST}
  action :run
  service :sns
  regions ${AUDIT_AWS_SNS_REGIONS}
end
