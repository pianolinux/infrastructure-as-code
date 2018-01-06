###################################################################
# AWS configuration below
###################################################################

variable "aws_region" {
  default = "eu-west-1"
}

variable "aws_profile" {
  default = "default"
}

###################################################################
# Resources configuration below
###################################################################

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

### MANDATORY ###
variable "hosted_zone_name" {}

### MANDATORY ###
variable "hosted_zone_id" {}

### MANDATORY ###
variable "aws_network_vpc_cidr" {}

### MANDATORY ###
variable "openvpn_ami" {}

### MANDATORY ###
variable "openvpn_instance_type" {
  default = "t2.small"
}

### MANDATORY ###
variable "aws_openvpn_subnet_cidr_a" {}

### MANDATORY ###
variable "aws_openvpn_subnet_cidr_b" {}
