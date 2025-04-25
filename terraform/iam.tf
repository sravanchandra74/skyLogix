resource "aws_iam_role" "ec2_cw_role" {
  name_prefix          = "ec2-cw-role-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "EC2CloudWatchRole"
  }
}

resource "aws_iam_policy" "ec2_cw_policy" {
  name_prefix = "ec2-cw-policy-"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ],
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = {
    Name = "EC2CloudWatchPolicy"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_cw_attach" {
  role       = aws_iam_role.ec2_cw_role.name
  policy_arn = aws_iam_policy.ec2_cw_policy.arn
  depends_on = [aws_iam_role.ec2_cw_role, aws_iam_policy.ec2_cw_policy]
}

resource "aws_iam_instance_profile" "ec2_cw_profile" {
  name_prefix = "ec2-cw-profile-"
  role       = aws_iam_role.ec2_cw_role.name

  tags = {
    Name = "EC2CloudWatchProfile"
  }
  depends_on = [aws_iam_role.ec2_cw_role]
}