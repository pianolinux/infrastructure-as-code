##############################################################################
# Providers
##############################################################################

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
  version = "~> 0.1"
}

provider "terraform" {
  version = "~> 0.1"
}

provider "template" {
  version = "~> 0.1"
}

##############################################################################
# Resources
##############################################################################

resource "aws_security_group" "zookeeper" {
  name        = "zookeeper"
  description = "Zookeeper security group"
  vpc_id      = "${data.terraform_remote_state.vpc.network-vpc-id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.aws_bastion_vpc_cidr}"]
  }

  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = ["${var.aws_network_vpc_cidr}"]
  }

  ingress {
    from_port   = 2888
    to_port     = 2888
    protocol    = "tcp"
    cidr_blocks = ["${var.aws_network_vpc_cidr}"]
  }

  ingress {
    from_port   = 3888
    to_port     = 3888
    protocol    = "tcp"
    cidr_blocks = ["${var.aws_network_vpc_cidr}"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["${var.aws_network_vpc_cidr}"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = ["${var.aws_network_vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.aws_network_vpc_cidr}"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Stream = "${var.stream_tag}"
  }
}

resource "aws_iam_role" "zookeeper" {
  name = "zookeeper"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    },
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "zookeeper" {
  name = "zookeeper"
  role = "${aws_iam_role.zookeeper.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeInstances"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
        "Action": [
            "s3:GetObject"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::${var.secrets_bucket_name}/*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "zookeeper" {
  name = "zookeeper"
  role = "${aws_iam_role.zookeeper.name}"
}

data "aws_ami" "zookeeper" {
  most_recent = true

  filter {
    name   = "name"
    values = ["base-${var.base_version}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["${var.account_id}"]
}

data "template_file" "zookeeper_a" {
  template = "${file("provision/zookeeper.tpl")}"

  vars {
    zookeeper_id      = "1"
    aws_region        = "${var.aws_region}"
    environment       = "${var.environment}"
    bucket_name       = "${var.secrets_bucket_name}"
    security_groups   = "${aws_security_group.zookeeper.id}"
    consul_secret     = "${var.consul_secret}"
    consul_datacenter = "${var.consul_datacenter}"
    consul_nodes      = "${replace(var.aws_network_private_subnet_cidr_a, "0/24", "90")},${replace(var.aws_network_private_subnet_cidr_b, "0/24", "90")},${replace(var.aws_network_private_subnet_cidr_c, "0/24", "90")}"
    hosted_zone_name  = "${var.hosted_zone_name}"
    filebeat_version  = "${var.filebeat_version}"
    zookeeper_nodes   = "${replace(var.aws_network_private_subnet_cidr_a, "0/24", "20")},${replace(var.aws_network_private_subnet_cidr_b, "0/24", "20")},${replace(var.aws_network_private_subnet_cidr_c, "0/24", "20")}"
    hosted_zone_dns   = "${replace(var.aws_network_vpc_cidr, "0/16", "2")}"
  }
}

data "template_file" "zookeeper_b" {
  template = "${file("provision/zookeeper.tpl")}"

  vars {
    zookeeper_id      = "2"
    aws_region        = "${var.aws_region}"
    environment       = "${var.environment}"
    bucket_name       = "${var.secrets_bucket_name}"
    security_groups   = "${aws_security_group.zookeeper.id}"
    consul_secret     = "${var.consul_secret}"
    consul_datacenter = "${var.consul_datacenter}"
    consul_nodes      = "${replace(var.aws_network_private_subnet_cidr_a, "0/24", "90")},${replace(var.aws_network_private_subnet_cidr_b, "0/24", "90")},${replace(var.aws_network_private_subnet_cidr_c, "0/24", "90")}"
    hosted_zone_name  = "${var.hosted_zone_name}"
    filebeat_version  = "${var.filebeat_version}"
    zookeeper_nodes   = "${replace(var.aws_network_private_subnet_cidr_a, "0/24", "20")},${replace(var.aws_network_private_subnet_cidr_b, "0/24", "20")},${replace(var.aws_network_private_subnet_cidr_c, "0/24", "20")}"
    hosted_zone_dns   = "${replace(var.aws_network_vpc_cidr, "0/16", "2")}"
  }
}

data "template_file" "zookeeper_c" {
  template = "${file("provision/zookeeper.tpl")}"

  vars {
    zookeeper_id      = "3"
    aws_region        = "${var.aws_region}"
    environment       = "${var.environment}"
    bucket_name       = "${var.secrets_bucket_name}"
    security_groups   = "${aws_security_group.zookeeper.id}"
    consul_secret     = "${var.consul_secret}"
    consul_datacenter = "${var.consul_datacenter}"
    consul_nodes      = "${replace(var.aws_network_private_subnet_cidr_a, "0/24", "90")},${replace(var.aws_network_private_subnet_cidr_b, "0/24", "90")},${replace(var.aws_network_private_subnet_cidr_c, "0/24", "90")}"
    hosted_zone_name  = "${var.hosted_zone_name}"
    filebeat_version  = "${var.filebeat_version}"
    zookeeper_nodes   = "${replace(var.aws_network_private_subnet_cidr_a, "0/24", "20")},${replace(var.aws_network_private_subnet_cidr_b, "0/24", "20")},${replace(var.aws_network_private_subnet_cidr_c, "0/24", "20")}"
    hosted_zone_dns   = "${replace(var.aws_network_vpc_cidr, "0/16", "2")}"
  }
}

resource "aws_instance" "zookeeper_a" {
  ami                         = "${data.aws_ami.zookeeper.id}"
  instance_type               = "${var.zookeeper_instance_type}"
  subnet_id                   = "${data.terraform_remote_state.network.network-private-subnet-a-id}"
  private_ip                  = "${replace(var.aws_network_private_subnet_cidr_a, "0/24", "20")}"
  vpc_security_group_ids      = ["${aws_security_group.zookeeper.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.zookeeper.name}"
  user_data                   = "${data.template_file.zookeeper_a.rendered}"
  associate_public_ip_address = "false"
  key_name                    = "${var.key_name}"

  tags {
    Name   = "zookeeper-a"
    Stream = "${var.stream_tag}"
  }
}

resource "aws_instance" "zookeeper_b" {
  ami                         = "${data.aws_ami.zookeeper.id}"
  instance_type               = "${var.zookeeper_instance_type}"
  subnet_id                   = "${data.terraform_remote_state.network.network-private-subnet-b-id}"
  private_ip                  = "${replace(var.aws_network_private_subnet_cidr_b, "0/24", "20")}"
  vpc_security_group_ids      = ["${aws_security_group.zookeeper.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.zookeeper.name}"
  user_data                   = "${data.template_file.zookeeper_b.rendered}"
  associate_public_ip_address = "false"
  key_name                    = "${var.key_name}"

  tags {
    Name   = "zookeeper-b"
    Stream = "${var.stream_tag}"
  }
}

resource "aws_instance" "zookeeper_c" {
  ami                         = "${data.aws_ami.zookeeper.id}"
  instance_type               = "${var.zookeeper_instance_type}"
  subnet_id                   = "${data.terraform_remote_state.network.network-private-subnet-c-id}"
  private_ip                  = "${replace(var.aws_network_private_subnet_cidr_c, "0/24", "20")}"
  vpc_security_group_ids      = ["${aws_security_group.zookeeper.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.zookeeper.name}"
  user_data                   = "${data.template_file.zookeeper_c.rendered}"
  associate_public_ip_address = "false"
  key_name                    = "${var.key_name}"

  tags {
    Name   = "zookeeper-c"
    Stream = "${var.stream_tag}"
  }
}
