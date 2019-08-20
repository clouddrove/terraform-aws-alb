module "label" {
  source      = "git::https://github.com/clouddrove/terraform-lables.git?ref=tags/0.11.0"
  name        = "${var.name}"
  application = "${var.application}"
  environment = "${var.environment}"
}
## ALB
resource "aws_lb" "main" {
  name                             = "${module.label.id}"
  internal                         = "${var.internal}"
  load_balancer_type               = "${var.load_balancer_type}"
  security_groups                  = ["${var.security_groups}"]
  subnets                          = ["${var.subnets}"]
  enable_deletion_protection       = "${var.enable_deletion_protection}"
  idle_timeout                     = "${var.idle_timeout}"
  enable_cross_zone_load_balancing = "${var.enable_cross_zone_load_balancing}"
  enable_http2                     = "${var.enable_http2}"
  ip_address_type                  = "${var.ip_address_type}"
  tags = "${module.label.tags}"

  timeouts {
    create = "${var.load_balancer_create_timeout}"
    delete = "${var.load_balancer_delete_timeout}"
    update = "${var.load_balancer_update_timeout}"
  }
  access_logs {
    enabled = "${var.access_logs}"
    bucket  = "${var.log_bucket_name}"
    prefix  = "${module.label.id}"
  }
}


#####  ALB LISTENER

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "${aws_lb.main.arn}"
  port              = "${var.listener_port}"
  protocol          = "${var.listener_protocol}"
  ssl_policy        = "${var.listener_ssl_policy}"
  certificate_arn   = "${var.listener_certificate_arn}"
  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }
}

#####  ALB TARGET GROUP

resource "aws_lb_target_group" "main" {
  name     = "${module.label.id}"
  port     = "${var.target_group_port}"
  protocol = "${var.target_group_protocol}"
  vpc_id   = "${var.vpc_id}"
}


#####  ALB TARGET GROUP ATTACHMENT 1

resource "aws_lb_target_group_attachment" "attachment1" {
  count            = "${var.instance_count}"
  target_group_arn = "${aws_lb_target_group.main.arn}"
  target_id            = "${element(var.target_id, count.index)}"
  port             = "${var.target_group_attachment_port}"
}

