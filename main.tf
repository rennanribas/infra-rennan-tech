provider "aws" {
  region  = var.aws_region
  profile = "personal"
}

resource "aws_ecrpublic_repository" "rennan-tech" {
  repository_name = "rennan-tech"

  catalog_data {
    description      = "Landing page for Rennan Tech built with React 19.1 and SSR"
    architectures    = ["x86-64"]
    operating_systems = ["Linux"]
  }

  tags = {
    Name        = "rennan-tech-ecr"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_ecrpublic_repository" "engineer-lab" {
  repository_name = "engineer-lab"

  catalog_data {
    description      = "Interactive platform for visualizing engineering concepts"
    architectures    = ["x86-64"]
    operating_systems = ["Linux"]
  }

  tags = {
    Name        = "engineer-lab-ecr"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          "StringLike": {
            "token.actions.githubusercontent.com:sub": [
              "repo:rennanribas/rennan-tech-landing:*",
              "repo:rennanribas/engineer-lab:*"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "github_actions_policy" {
  name        = "GitHubActionsPolicy"
  description = "Policy for GitHub Actions to access ECR Public and SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ecr-public:GetAuthorizationToken",
          "sts:GetServiceBearerToken",
          "ecr-public:InitiateLayerUpload",
          "ecr-public:UploadLayerPart",
          "ecr-public:CompleteLayerUpload",
          "ecr-public:PutImage"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "ssm:SendCommand",
        Resource = [
          aws_instance.web_server.arn,
          "arn:aws:ssm:*:*:document/AWS-RunShellScript"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_policy_attachment" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_security_group" "allow_http_https" {
  name        = "allow_http_https"
  description = "Allow HTTP and HTTPS traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

resource "aws_instance" "web_server" {
  ami           = "ami-0866a3c8686eaeeba" # Ubuntu 24.04 LTS (us-east-1)
  instance_type = var.instance_type

  tags = {
    Name        = "${var.project_name}-server"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.allow_http_https.id]

  user_data = <<-EOF
              #!/bin/bash
              # Update and install dependencies
              apt-get update -y
              apt-get install -y docker.io git curl

              # Add ubuntu user to docker group
              usermod -aG docker ubuntu

              # Start and enable Docker
              systemctl start docker
              systemctl enable docker

              # Install Docker Compose V2 (official method)
              mkdir -p /usr/local/lib/docker/cli-plugins
              curl -SL "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
              ln -s /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

              # Install and start SSM Agent (already included in Ubuntu 24.04)
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent

              # Clone the infrastructure repository as the ubuntu user
              sudo -u ubuntu git clone https://github.com/rennanribas/infra-rennan-tech.git /home/ubuntu/infra-rennan-tech
              
              # Set proper ownership
              chown -R ubuntu:ubuntu /home/ubuntu/infra-rennan-tech
              EOF
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.web_server.public_dns
}

output "ecr_rennan_tech_repository_url" {
  description = "URL of the rennan-tech ECR repository"
  value       = aws_ecrpublic_repository.rennan-tech.repository_uri
}

output "ecr_engineer_lab_repository_url" {
  description = "URL of the engineer-lab ECR repository"
  value       = aws_ecrpublic_repository.engineer-lab.repository_uri
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}