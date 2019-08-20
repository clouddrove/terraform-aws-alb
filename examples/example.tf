provider "aws" {
  profile                 = "default"
  region                  = "${var.region}"
}

locals {
  public_cidr_block = "${cidrsubnet("10.0.0.0/16", 1, 0)}"
}

module "vpc" {
  source        = "git::https://github.com/clouddrove/terraform-aws-vpc.git?ref=tags/0.11.0"
  cidr_block  = "10.0.0.0/16"
  name        = "vpc"
  application = "clouddrove"
  environment = "test"
}


module "public_subnets" {
  source        = "git::https://github.com/clouddrove/terraform-aws-public-subnet.git?ref=tags/0.11.0"
  name                = "name"
  application         = "cloudDrove"
  environment         = "test"
  availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  vpc_id              = "${module.vpc.vpc_id}"
  cidr_block          = "${local.public_cidr_block}"
  type                = "public"
  igw_id              = "${module.vpc.igw_id}"
  nat_gateway_enabled = "false"
}
module "bastion" {
  source        = "../../terraform-aws-ec2"
  name                        = "${var.name}"
  instance_count = 2

  application                 = "${var.application}"
  environment                 = "${var.environment}"
  ami                         = "${var.ami_id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.key_name}"
  monitoring                  = false
  vpc_security_group_ids_list = ["${module.sg.security_group_ids}"]
  subnet                      = "${var.subnet}"
  ebs_volume_count            = "0"
  disk_size                   = 10
  user_data_base64            = "${base64encode("${file("../_bin/user_data.sh")}")}"
}

module "sg" {
  source = "git::https://github.com/clouddrove/terraform-aws-security-group.git?ref=tags/0.11.0"
  name = "${var.name}"
  application = "${var.application}"
  environment = "${var.environment}"
  vpc_id = "${var.vpc_id}"
  cidr_blocks = "${var.source_ip}"
  allowed_ports = [
    22]

}
module "alb" {
  source = "./../"
  application                                = "dev"
  environment                            = "${var.environment}"

  name                                       = "backend"
  internal                                   = false
  load_balancer_type                         = "application"
  security_groups                            =  ["${module.sg.security_group_ids}"]
  subnets                                    = ["subnet-0399c34a","subnet-18d8ad35"]
  enable_deletion_protection                 = false
  listener_port                              =  443
  listener_protocol                          = "HTTPS"
  vpc_id                                     = "vpc-7478c912"
  instance_count                             = 1
  target_id                                  = ["i-08da6f78390d2a8c6",]
  target_group_protocol                      = "HTTP"
  target_group_port                          =   80
  target_group_attachment_port               =   80
  listener_certificate_arn                   =  "arn:aws:acm:us-east-1:946010253026:certificate/17247909-1d93-4dbb-80a6-32a31a9a4b9f"
  log_bucket_name                            =       "cloudrove-logs"
}
