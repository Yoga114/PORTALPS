# ─── Security Group for ALB ───────────────────────────────────────────────────
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP and HTTPS inbound to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}

# ─── Application Load Balancer ────────────────────────────────────────────────
resource "aws_lb" "arcgis_alb" {
  name               = "arcgis-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = { Name = "arcgis-alb" }
}

# ─── Target Group: Portal ─────────────────────────────────────────────────────
resource "aws_lb_target_group" "portal" {
  name        = "tg-portal"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/portal/portalinfo"
    protocol            = "HTTPS"
    matcher             = "200-399"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "tg-portal" }
}

# ─── Target Group: Server ─────────────────────────────────────────────────────
resource "aws_lb_target_group" "server" {
  name        = "tg-server"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/server/rest/info"
    protocol            = "HTTPS"
    matcher             = "200-399"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "tg-server" }
}

# ─── Register EC2 into both Target Groups ─────────────────────────────────────
resource "aws_lb_target_group_attachment" "portal" {
  target_group_arn = aws_lb_target_group.portal.arn
  target_id        = var.target_instance_id
  port             = 443
}

resource "aws_lb_target_group_attachment" "server" {
  target_group_arn = aws_lb_target_group.server.arn
  target_id        = var.target_instance_id
  port             = 443
}

# ─── HTTP Listener → redirect to HTTPS ───────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.arcgis_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ─── HTTPS Listener ───────────────────────────────────────────────────────────
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.arcgis_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  # Default action: 404 if no path matches
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# ─── Listener Rule: /portal* ──────────────────────────────────────────────────
resource "aws_lb_listener_rule" "portal" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/portal", "/portal/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portal.arn
  }
}

# ─── Listener Rule: /server* ──────────────────────────────────────────────────
resource "aws_lb_listener_rule" "server" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  condition {
    path_pattern {
      values = ["/server", "/server/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server.arn
  }
}

# ─── Route53: alias record domain -> ALB ──────────────────────────────────────
resource "aws_route53_record" "alb_alias" {
  zone_id = var.hosted_zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_lb.arcgis_alb.dns_name
    zone_id                = aws_lb.arcgis_alb.zone_id
    evaluate_target_health = true
  }
}
