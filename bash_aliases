alias pk_create='packer build --var-file=../../config/config_vars.json --var-file=../../config/other_vars.json --var-file=../../config/network_vars.json --var-file=../../config/version_vars.json packer.json'
alias tf_init='terraform init -input=false -var-file=../../config/config.tfvars -var-file=../../config/other.tfvars -var-file=../../config/network.tfvars -var-file=../../config/consul.tfvars -var-file=../../config/version.tfvars'
alias tf_plan='terraform plan -input=false -out=tfplan -var-file=../../config/config.tfvars -var-file=../../config/other.tfvars -var-file=../../config/network.tfvars -var-file=../../config/consul.tfvars -var-file=../../config/version.tfvars'
alias tf_apply='terraform apply -input=false tfplan'
alias tf_destroy='terraform destroy -force -var-file=../../config/config.tfvars -var-file=../../config/other.tfvars -var-file=../../config/network.tfvars -var-file=../../config/consul.tfvars -var-file=../../config/version.tfvars'
alias tf_refresh='terraform refresh -input=false -var-file=../../config/config.tfvars -var-file=../../config/other.tfvars -var-file=../../config/network.tfvars -var-file=../../config/consul.tfvars -var-file=../../config/version.tfvars'
