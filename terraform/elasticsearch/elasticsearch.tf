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

data "terraform_remote_state" "volumes" {
    backend = "s3"
    config {
        bucket = "nextbreakpoint-terraform-state"
        region = "${var.aws_region}"
        key = "volumes.tfstate"
    }
}

##############################################################################
# Route 53
##############################################################################

resource "aws_route53_record" "elasticsearch" {
   zone_id = "${data.terraform_remote_state.vpc.hosted-zone-id}"
   name = "elasticsearch.${data.terraform_remote_state.vpc.hosted-zone-name}"
   type = "A"
   ttl = "300"
   records = ["${aws_instance.elasticsearch_server_a.private_ip}","${aws_instance.elasticsearch_server_b.private_ip}"]
}

##############################################################################
# Elasticsearch servers
##############################################################################

resource "aws_security_group" "elasticsearch_server" {
  name = "search server"
  description = "search server security group"
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
    from_port = 9200
    to_port = 9400
    protocol = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  egress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  egress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.network-vpc-cidr}"]
  }

  tags {
    Name = "search server security group"
    Stream = "${var.stream_tag}"
  }
}

data "template_file" "elasticsearch_server_user_data" {
  template = "${file("provision/elasticsearch.tpl")}"

  vars {
    aws_region              = "${var.aws_region}"
    es_cluster              = "${var.es_cluster}"
    es_environment          = "${var.es_environment}"
    security_groups         = "${aws_security_group.elasticsearch_server.id}"
    minimum_master_nodes    = "${var.minimum_master_nodes}"
    availability_zones      = "${var.availability_zones}"
    volume_name             = "${var.volume_name}"
    elasticsearch_data_dir  = "/mnt/elasticsearch/data"
    elasticsearch_logs_dir  = "/mnt/elasticsearch/logs"
    consul_log_file         = "${var.consul_log_file}"
    log_group_name          = "${var.log_group_name}"
    log_stream_name         = "${var.log_stream_name}"
  }
}

resource "aws_iam_instance_profile" "elasticsearch_server_profile" {
    name = "elasticsearch_server_profile"
    roles = ["${var.elastic_profile}"]
}

resource "aws_instance" "elasticsearch_server_a" {
  instance_type = "t2.medium"

  # Lookup the correct AMI based on the region we specified
  ami = "${lookup(var.elasticsearch_amis, var.aws_region)}"

  subnet_id = "${data.terraform_remote_state.network.network-private-subnet-a-id}"
  associate_public_ip_address = "false"
  security_groups = ["${aws_security_group.elasticsearch_server.id}"]
  key_name = "${var.key_name}"

  iam_instance_profile = "${aws_iam_instance_profile.elasticsearch_server_profile.id}"

  connection {
    # The default username for our AMI
    user = "ubuntu"
    type = "ssh"
    # The path to your keyfile
    private_key = "${file(var.key_path)}"
    bastion_user = "ec2-user"
    bastion_host = "${data.terraform_remote_state.bastion.bastion-server-a-public-ip}"
  }

  tags {
    Name = "elasticsearch_server_a"
    Stream = "${var.stream_tag}"
  }
}

resource "aws_instance" "elasticsearch_server_b" {
  instance_type = "t2.medium"

  # Lookup the correct AMI based on the region we specified
  ami = "${lookup(var.elasticsearch_amis, var.aws_region)}"

  subnet_id = "${data.terraform_remote_state.network.network-private-subnet-b-id}"
  associate_public_ip_address = "false"
  security_groups = ["${aws_security_group.elasticsearch_server.id}"]
  key_name = "${var.key_name}"

  iam_instance_profile = "${aws_iam_instance_profile.elasticsearch_server_profile.id}"

  connection {
    # The default username for our AMI
    user = "ubuntu"
    type = "ssh"
    # The path to your keyfile
    private_key = "${file(var.key_path)}"
    bastion_user = "ec2-user"
    bastion_host = "${data.terraform_remote_state.bastion.bastion-server-b-public-ip}"
  }

  tags {
    Name = "elasticsearch_server_b"
    Stream = "${var.stream_tag}"
  }
}

resource "aws_volume_attachment" "elasticsearch_volume_attachment_a" {
  device_name = "${var.volume_name}"
  volume_id = "${data.terraform_remote_state.volumes.elasticsearch-volume-a-id}"
  instance_id = "${aws_instance.elasticsearch_server_a.id}"
  skip_destroy = true
}

resource "aws_volume_attachment" "elasticsearch_volume_attachment_b" {
  device_name = "${var.volume_name}"
  volume_id = "${data.terraform_remote_state.volumes.elasticsearch-volume-b-id}"
  instance_id = "${aws_instance.elasticsearch_server_b.id}"
  skip_destroy = true
}

resource "null_resource" "elasticsearch_server_a" {
  triggers {
    cluster_instance_ids = "${join(",", aws_instance.elasticsearch_server_a.*.id)}"
  }

  connection {
    host = "${element(aws_instance.elasticsearch_server_a.*.private_ip, 0)}"
    # The default username for our AMI
    user = "ubuntu"
    type = "ssh"
    # The path to your keyfile
    private_key = "${file(var.key_path)}"
    bastion_user = "ec2-user"
    bastion_host = "${data.terraform_remote_state.bastion.bastion-server-a-public-ip}"
  }

  provisioner "remote-exec" {
    inline = "${data.template_file.elasticsearch_server_user_data.rendered}"
  }
}

resource "null_resource" "elasticsearch_server_b" {
  triggers {
    cluster_instance_ids = "${join(",", aws_instance.elasticsearch_server_b.*.id)}"
  }

  connection {
    host = "${element(aws_instance.elasticsearch_server_b.*.private_ip, 0)}"
    # The default username for our AMI
    user = "ubuntu"
    type = "ssh"
    # The path to your keyfile
    private_key = "${file(var.key_path)}"
    bastion_user = "ec2-user"
    bastion_host = "${data.terraform_remote_state.bastion.bastion-server-b-public-ip}"
  }

  provisioner "remote-exec" {
    inline = "${data.template_file.elasticsearch_server_user_data.rendered}"
  }
}