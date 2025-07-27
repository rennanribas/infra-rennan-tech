provider "aws" {
  region = var.aws_region
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_ecrpublic_repository" "rennan-tech" {
  repository_name = "rennan-tech"

  catalog_data {
    description       = "Rennan Tech landing page (React 19.1 + SSR)"
    architectures     = ["x86-64"]
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
    description       = "Engineer Lab interactive platform"
    architectures     = ["x86-64"]
    operating_systems = ["Linux"]
  }

  tags = {
    Name        = "engineer-lab-ecr"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:rennanribas/rennan-tech-landing:*",
            "repo:rennanribas/engineer-lab:*",
            "repo:rennanribas/infra-rennan-tech:*"
          ]
        }
      }
    }]
  })
}

resource "aws_iam_policy" "github_actions_policy" {
  name        = "GitHubActionsPolicy"
  description = "Allow GitHub Actions to use ECR Public, SSM and Terraform state"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ── deploy actions ──────────────────────────────
      {
        Effect   = "Allow",
        Action   = [
          "ecr-public:GetAuthorizationToken",
          "sts:GetServiceBearerToken",
          "ecr-public:BatchCheckLayerAvailability",
          "ecr-public:BatchGetImage",
          "ecr-public:GetDownloadUrlForLayer",
          "ecr-public:InitiateLayerUpload",
          "ecr-public:UploadLayerPart",
          "ecr-public:CompleteLayerUpload",
          "ecr-public:PutImage"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation",
          "ssm:ListCommandInvocations"
        ],
        Resource = [
          aws_instance.web_server.arn,
          "arn:aws:ssm:*:*:document/AWS-RunShellScript",
          "arn:aws:ssm:*:*:*"
        ]
      },

      # ── backend S3 + DynamoDB ───────────────────────
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject"
        ],
        Resource = "arn:aws:s3:::rennan-tech-terraform-state/infrastructure/*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:GetBucketPolicy",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl"
        ],
        Resource = "arn:aws:s3:::rennan-tech-terraform-state"
      },
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTimeToLive"
        ],
        Resource = "arn:aws:dynamodb:*:*:table/rennan-tech-terraform-locks"
      },

      {
        Effect   = "Allow",
        Action   = [
          "s3:Get*",
          "s3:List*",
          "dynamodb:Describe*",
          "dynamodb:ListTagsOfResource",
          "ecr-public:Describe*",
          "ecr-public:GetRepositoryCatalogData",
          "ecr-public:ListTagsForResource",
          "ec2:Describe*",
          "iam:Get*",
          "iam:List*",
          "ssm:ListDocuments",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters",
          "ssm:ListTagsForResource"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_policy_attachment" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ssm_role.name
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
  ami                    = "ami-0866a3c8686eaeeba"              # Ubuntu 24.04 LTS us-east-1
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.allow_http_https.id]

  tags = {
    Name        = "${var.project_name}-server"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io git curl awscli
    usermod -aG docker ubuntu
    systemctl enable --now docker

    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -sSL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
         -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ln -s /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

    systemctl enable --now amazon-ssm-agent

    sudo -u ubuntu git clone https://github.com/rennanribas/infra-rennan-tech.git /home/ubuntu/infra-rennan-tech
    chown -R ubuntu:ubuntu /home/ubuntu/infra-rennan-tech
    
    # Configurar variáveis de ambiente do Doppler diretamente
    RENNAN_TECH_ECR_URI=$(aws ssm get-parameter --name "/doppler/rennan-tech/landing/ECR_REPOSITORY_URI" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    ENGINEER_LAB_ECR_URI=$(aws ssm get-parameter --name "/doppler/rennan-tech/engineer-lab/ECR_REPOSITORY_URI" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    cat > /home/ubuntu/infra-rennan-tech/.env << ENVEOF
# ECR Repository URIs (gerenciado pelo Doppler via Parameter Store)
RENNAN_TECH_ECR_URI=$${RENNAN_TECH_ECR_URI}
ENGINEER_LAB_ECR_URI=$${ENGINEER_LAB_ECR_URI}
ENVEOF
    
    chown ubuntu:ubuntu /home/ubuntu/infra-rennan-tech/.env
  EOF
}

# ── Doppler Integration ──────────────────────────────
resource "aws_iam_role" "doppler_parameter_store_role" {
  name = "doppler-parameter-store-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = "arn:aws:iam::299900769157:user/doppler-integration-operator"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "doppler-parameter-store-role"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "doppler_parameter_store_policy" {
  name        = "DopplerParameterStorePolicy"
  description = "Allow Doppler to manage secrets in Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource",
          "ssm:ListTagsForResource"
        ],
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/doppler/rennan-tech/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "doppler_parameter_store_policy_attachment" {
  role       = aws_iam_role.doppler_parameter_store_role.name
  policy_arn = aws_iam_policy.doppler_parameter_store_policy.arn
}

# ── ECR Repository URIs in Parameter Store ──────────
resource "aws_ssm_parameter" "ecr_rennan_tech_uri" {
  name      = "/doppler/rennan-tech/landing/ECR_REPOSITORY_URI"
  type      = "String"
  value     = aws_ecrpublic_repository.rennan-tech.repository_uri
  overwrite = true

  tags = {
    Name        = "ecr-rennan-tech-uri"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "ecr_engineer_lab_uri" {
  name      = "/doppler/rennan-tech/engineer-lab/ECR_REPOSITORY_URI"
  type      = "String"
  value     = aws_ecrpublic_repository.engineer-lab.repository_uri
  overwrite = true

  tags = {
    Name        = "ecr-engineer-lab-uri"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

output "instance_id"                     { value = aws_instance.web_server.id }
output "instance_public_ip"              { value = aws_instance.web_server.public_ip }
output "instance_public_dns"             { value = aws_instance.web_server.public_dns }
output "github_actions_role_arn"         { value = aws_iam_role.github_actions.arn }
output "doppler_role_arn"                { value = aws_iam_role.doppler_parameter_store_role.arn }
output "parameter_store_path"            { value = "/doppler/rennan-tech" }
output "aws_region"                      { value = var.aws_region }
output "ecr_rennan_tech_repository_url"  { value = aws_ecrpublic_repository.rennan-tech.repository_uri }
output "ecr_engineer_lab_repository_url" {
  value = aws_ecrpublic_repository.engineer-lab.repository_uri
}

