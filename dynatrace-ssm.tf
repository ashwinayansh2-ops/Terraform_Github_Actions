#create aws_secretsmanager_secret 
data "aws_secretsmanager_secret" "dynatrace_secret" {
  name = "dynatrace-paas-token"
  
}


#Allow ec2 instance to access the system manager parameter store
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-dynatrace-role"
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
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lets the EC2 instance read only the Dynatrace token.
resource "aws_iam_role_policy" "read_dynatrace_token" {
  name = "read-dynatrace-paas-token"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = data.aws_secretsmanager_secret.dynatrace_secret.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-dynatrace-profile"
  role = aws_iam_role.ec2_ssm_role.name
}