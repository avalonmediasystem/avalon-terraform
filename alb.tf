resource "aws_alb" "alb" {  
  name            = "${local.namespace}-alb"
  subnets         = ["${module.vpc.public_subnets}"]
  security_groups = ["${aws_security_group.alb.id}"]
#   internal        = "${var.internal_alb}"  
#   idle_timeout    = "${var.idle_timeout}"   
#   tags {    
#     Name    = "${var.alb_name}"    
#   }   
#   access_logs {    
#     bucket = "${var.s3_bucket}"    
#     prefix = "ELB-logs"  
#   }
}

resource "aws_security_group" "alb" {
  name        = "${local.namespace}-alb"
  description = "Compose Host Security Group"
  vpc_id      = "${module.vpc.vpc_id}"
  tags        = "${local.common_tags}"
}

resource "aws_security_group_rule" "alb_web" {
  security_group_id = "${aws_security_group.alb.id}"
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress" {
  security_group_id = "${aws_security_group.alb.id}"
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_alb_listener" "alb_web_listener" {  
  load_balancer_arn = "${aws_alb.alb.arn}"  
  port              = "80"
  protocol          = "HTTP"
  
  default_action {    
    target_group_arn = "${aws_alb_target_group.alb_web.arn}"
    type             = "forward"  
  }
}

resource "aws_lb_listener_rule" "alb_web_listener_rule" {
  listener_arn = "${aws_alb_listener.alb_web_listener.arn}"
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.alb_web.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${aws_route53_record.alb.fqdn}"]
  }
}


resource "aws_alb_target_group" "alb_web" {  
  name     = "${local.namespace}-alb-web"  
  port     = "80"  
  protocol = "HTTP"  
  vpc_id   = "${module.vpc.vpc_id}"   
#   tags {    
#     name = "${var.target_group_name}"    
#   }   
  stickiness {    
    type            = "lb_cookie"    
    cookie_duration = 1800    
    enabled         = "true"  
  }   
  health_check {    
    healthy_threshold   = 3    
    unhealthy_threshold = 10    
    timeout             = 5    
    interval            = 10    
    path                = "/"    
    port                = "80"  
  }
}

# resource "aws_alb_listener" "alb_streaming_listener" {  
#   load_balancer_arn = "${aws_alb.alb.arn}"  
#   port              = "80"
#   protocol          = "HTTP"
  
#   default_action {    
#     target_group_arn = "${aws_alb_target_group.alb_streaming.arn}"
#     type             = "forward"  
#   }
# }

resource "aws_lb_listener_rule" "alb_streaming_listener_rule" {
  listener_arn = "${aws_alb_listener.alb_web_listener.arn}"
  priority     = 98

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.alb_streaming.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${aws_route53_record.alb_streaming.fqdn}"]
  }
}

resource "aws_alb_target_group" "alb_streaming" {  
  name     = "${local.namespace}-alb-streaming"  
  port     = "8880"  
  protocol = "HTTP"  
  vpc_id   = "${module.vpc.vpc_id}"   
#   tags {    
#     name = "${var.target_group_name}"    
#   }   
  stickiness {    
    type            = "lb_cookie"    
    cookie_duration = 1800    
    enabled         = "true"  
  }   
  health_check {    
    healthy_threshold   = 3    
    unhealthy_threshold = 10    
    timeout             = 5    
    interval            = 10    
    path                = "/"    
    port                = "8880"  
  }
}

resource "aws_route53_record" "alb" {
  zone_id = "${module.dns.public_zone_id}"
  name    = "web.${local.public_zone_name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_alb.alb.dns_name}"]
}

resource "aws_route53_record" "alb_streaming" {
  zone_id = "${module.dns.public_zone_id}"
  name    = "streaming.${local.public_zone_name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_alb.alb.dns_name}"]
}


#Instance Attachment
resource "aws_alb_target_group_attachment" "alb_compose" {
  target_group_arn = "${aws_alb_target_group.alb_web.arn}"
  target_id        = "${aws_instance.compose.id}"  
  port             = 80
}

resource "aws_alb_target_group_attachment" "alb_compose_streaming" {
  target_group_arn = "${aws_alb_target_group.alb_streaming.arn}"
  target_id        = "${aws_instance.compose.id}"  
  port             = 8880
}