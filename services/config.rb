coreo_uni_util_variables "sns-vars" do
  action :set
  variables([
                {'COMPOSITE::coreo_uni_util_variables.sns-vars.readme' => 'SNS rules are coming soon.'}
            ])
end

# coreo_aws_rule "sns-inventory" do
#   action :define
#   service :sns
#   link "http://kb.cloudcoreo.com/mydoc-inventory.html"
#   include_violations_in_count false
#   display_name "KMS Inventory"
#   description "This rule performs an inventory on all sns objects in the target AWS account."
#   category "Inventory"
#   suggested_action "None."
#   level "Informational"
#   meta_cis_id "99.999"
#   objectives ["TBS"]
#   audit_objects ["object.TBS"]
#   operators ["=~"]
#   raise_when [//]
#   id_map "object.TBS"
# end

# coreo_aws_rule_runner "advise-sns" do
#   rules ${AUDIT_AWS_SNS_ALERT_LIST}
#   action :run
#   service :sns
#   regions ${AUDIT_AWS_SNS_REGIONS}
# end
