resource "aws_lb" "app_lb" {
  name               = "application-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id] # Include both public subnets

  security_groups = [aws_security_group.alb_sg.id]

  tags = {
    Name = "application-load-balancer"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "application-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    healthy_threshold   = "3"
    unhealthy_threshold = "3"
    timeout             = "5"
    interval            = "10"
    path                = "/"
    protocol            = "HTTP"
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "private1" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.private[0].id
  port             = 80
  depends_on = [aws_lb_target_group.app_tg, aws_instance.private[0]]
}

resource "aws_lb_target_group_attachment" "private2" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.private[1].id
  port             = 80
  depends_on = [aws_lb_target_group.app_tg, aws_instance.private[1]]
}

resource "aws_lb_target_group_attachment" "private3" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.private[2].id
  port             = 80
  depends_on = [aws_lb_target_group.app_tg, aws_instance.private[2]]
}