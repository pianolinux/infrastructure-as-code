###################################################################
# AWS configuration below
###################################################################

### MANDATORY ###
variable "aws_shared_credentials_file" {
}

variable "aws_region" {
  default = "eu-west-1"
}

variable "aws_profile" {
  default = "default"
}

### MANDATORY ###
variable "key_name" {
  description = "Name of the SSH keypair to use in AWS."
}

### MANDATORY ###
variable "key_path" {
  description = "Path to the private portion of the SSH key specified."
}

variable "stream_tag" {
  default = "terraform"
}

###################################################################
# Volumes
###################################################################

variable "elasticsearch_volume_size" {
  default = "4"
}

variable "elasticsearch_volume_encrypted" {
  default = "false"
}

variable "pipeline_volume_size" {
  default = "4"
}

variable "pipeline_volume_encrypted" {
  default = "false"
}

