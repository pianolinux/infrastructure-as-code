##############################################################################
# Provider
##############################################################################

provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
  shared_credentials_file = "${var.aws_shared_credentials_file}"
}

##############################################################################
# Remote state
##############################################################################

data "terraform_remote_state" "vpc" {
    backend = "s3"
    config {
        bucket = "nextbreakpoint-terraform-state"
        region = "${var.aws_region}"
        key = "vpc.tfstate"
    }
}

data "terraform_remote_state" "network" {
    backend = "s3"
    config {
        bucket = "nextbreakpoint-terraform-state"
        region = "${var.aws_region}"
        key = "network.tfstate"
    }
}

data "terraform_remote_state" "bastion" {
    backend = "s3"
    config {
        bucket = "nextbreakpoint-terraform-state"
        region = "${var.aws_region}"
        key = "bastion.tfstate"
    }
}

##############################################################################
# Route 53
##############################################################################

resource "aws_route53_record" "consul" {
   zone_id = "${data.terraform_remote_state.vpc.hosted-zone-id}"
   name = "consul.${data.terraform_remote_state.vpc.hosted-zone-name}"
   type = "A"
   ttl = "300"
   records = ["${module.consul_servers_a.private-ips}","${module.consul_servers_b.private-ips}","${module.consul_servers_c.private-ips}"]
}

##############################################################################
# Consul servers
##############################################################################

resource "aws_security_group" "consul_server" {
  name = "consul server"
  description = "Consul server, UI and maintenance"
  vpc_id = "${data.terraform_remote_state.vpc.network-vpc-id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8300
    to_port = 8302
    protocol = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  ingress {
    from_port = 8300
    to_port = 8302
    protocol = "udp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  ingress {
    from_port = 8400
    to_port = 8400
    protocol = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  ingress {
    from_port = 8500
    to_port = 8500
    protocol = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  ingress {
    from_port = 8600
    to_port = 8600
    protocol = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  ingress {
    from_port = 8600
    to_port = 8600
    protocol = "udp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  egress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "consul server security group"
    stream = "${var.stream_tag}"
  }
}

data "template_file" "consul_server_user_data" {
  template = "${file("provision/consul.tpl")}"

  vars {
    aws_region              = "${var.aws_region}"
    environment             = "${var.environment}"
    consul_log_file         = "${var.consul_log_file}"
    log_group_name          = "${var.log_group_name}"
    log_stream_name         = "${var.log_stream_name}"
    bootstrap_expect        = "3"
  }
}

module "consul_servers_a" {
  source = "./consul"

  name = "consul_server_a"
  region = "${var.aws_region}"
  ami = "${lookup(var.consul_amis, var.aws_region)}"
  subnet = "${data.terraform_remote_state.network.network-private-subnet-a-id}"
  instance_type = "t2.micro"
  security_groups = "${aws_security_group.consul_server.id}"
  key_name = "${var.key_name}"
  key_path = "${var.key_path}"
  stream_tag = "${var.stream_tag}"
  user_data = "${data.template_file.consul_server_user_data.rendered}"
  bastion_user = "ec2-user"
  bastion_host = "${data.terraform_remote_state.bastion.bastion-server-a-public-ip}"
  instance_profile = "${var.consul_profile}"
}

module "consul_servers_b" {
  source = "./consul"

  name = "consul_server_b"
  region = "${var.aws_region}"
  ami = "${lookup(var.consul_amis, var.aws_region)}"
  subnet = "${data.terraform_remote_state.network.network-private-subnet-b-id}"
  instance_type = "t2.micro"
  security_groups = "${aws_security_group.consul_server.id}"
  key_name = "${var.key_name}"
  key_path = "${var.key_path}"
  stream_tag = "${var.stream_tag}"
  user_data = "${data.template_file.consul_server_user_data.rendered}"
  bastion_user = "ec2-user"
  bastion_host = "${data.terraform_remote_state.bastion.bastion-server-a-public-ip}"
  instance_profile = "${var.consul_profile}"
}

module "consul_servers_c" {
  source = "./consul"

  name = "consul_server_c"
  region = "${var.aws_region}"
  ami = "${lookup(var.consul_amis, var.aws_region)}"
  subnet = "${data.terraform_remote_state.network.network-private-subnet-c-id}"
  instance_type = "t2.micro"
  security_groups = "${aws_security_group.consul_server.id}"
  key_name = "${var.key_name}"
  key_path = "${var.key_path}"
  stream_tag = "${var.stream_tag}"
  user_data = "${data.template_file.consul_server_user_data.rendered}"
  bastion_user = "ec2-user"
  bastion_host = "${data.terraform_remote_state.bastion.bastion-server-a-public-ip}"
  instance_profile = "${var.consul_profile}"
}