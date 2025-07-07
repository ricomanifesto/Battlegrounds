provider "aws" {
  region = "us-east-1"
}

# Variable Declarations
variable "my_public_ip" {
  description = "Your public IP address (used for SSH access to public EC2s). Format is: 1.2.3.4/32."
  type        = string

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+/32$", var.my_public_ip))
    error_message = "Must be a valid IPv4 address in CIDR /32 format (e.g. 1.2.3.4/32)."
  }
}


# Name of your attack box (visible in AWS console)
variable "attack_box_name" {
  type    = string
  default = "Attack Box"
}

# Name of your target box (visible in AWS console)
variable "target_box_name" {
  type    = string
  default = "Target Box"
}

# Name of your ML box (visible in AWS console)
variable "ml_box_name" {
  type    = string
  default = "ML Box"
}

# Name of your EC2 Key Pair for SSH access
variable "key_name" {
  description = "Name of the AWS EC2 Key Pair to use for SSH access to instances"
  type        = string
  default     = "DemoKey"
}

# VPCs
resource "aws_vpc" "public_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "PublicVPC" }
}

resource "aws_vpc" "private_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "PrivateVPC" }
}

resource "aws_vpc" "ml_vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "ML-VPC" }
}

# Subnets
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.public_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = { Name = "PublicSubnet" }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.private_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "PrivateSubnet" }
}

resource "aws_subnet" "ml_subnet" {
  vpc_id            = aws_vpc.ml_vpc.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "ML-Subnet" }
}

# Internet Gateway & Route Tables
resource "aws_internet_gateway" "public_igw" {
  vpc_id = aws_vpc.public_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.public_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.private_vpc.id

  tags = {
    Name = "PrivateRouteTable"
  }
}

resource "aws_route_table" "ml_rt" {
  vpc_id = aws_vpc.ml_vpc.id

  tags = {
    Name = "ML-RouteTable"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "ml_rta" {
  subnet_id      = aws_subnet.ml_subnet.id
  route_table_id = aws_route_table.ml_rt.id
}

# VPC Peering Connections
resource "aws_vpc_peering_connection" "public_private" {
  vpc_id        = aws_vpc.public_vpc.id
  peer_vpc_id   = aws_vpc.private_vpc.id
  auto_accept   = true

  tags = {
    Name = "PublicToPrivatePeering"
  }
}

resource "aws_vpc_peering_connection" "private_ml" {
  vpc_id        = aws_vpc.private_vpc.id
  peer_vpc_id   = aws_vpc.ml_vpc.id
  auto_accept   = true

  tags = {
    Name = "PrivateToMLPeering"
  }
}

resource "aws_vpc_peering_connection" "public_ml" {
  vpc_id        = aws_vpc.public_vpc.id
  peer_vpc_id   = aws_vpc.ml_vpc.id
  auto_accept   = true

  tags = {
    Name = "PublicToMLPeering"
  }
}

# Routes between Public and Private VPCs
resource "aws_route" "public_to_private" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = aws_vpc.private_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.public_private.id
}

resource "aws_route" "private_to_public" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = aws_vpc.public_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.public_private.id
}

# Routes between Public and ML VPCs
resource "aws_route" "public_to_ml" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = aws_vpc.ml_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.public_ml.id
}

resource "aws_route" "ml_to_public" {
  route_table_id         = aws_route_table.ml_rt.id
  destination_cidr_block = aws_vpc.public_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.public_ml.id
}

# Routes between Private and ML VPCs
resource "aws_route" "private_to_ml" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = aws_vpc.ml_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.private_ml.id
}

resource "aws_route" "ml_to_private" {
  route_table_id         = aws_route_table.ml_rt.id
  destination_cidr_block = aws_vpc.private_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.private_ml.id
}

# Security Groups
resource "aws_security_group" "attack_box_sg" {
  name        = "attack_box_sg"
  description = "Allow SSH from user IP and full egress for attack box"
  vpc_id      = aws_vpc.public_vpc.id

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_public_ip]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "target_box_sg" {
  name        = "target_box_sg"
  description = "Allow traffic from attack box and Docker containers"
  vpc_id      = aws_vpc.private_vpc.id

  ingress {
    description = "Allow all traffic from attack box subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  ingress {
    description = "Allow Docker container traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.17.0.0/16"]
  }

  egress {
    description = "Allow all outbound traffic (for Docker pulls, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ml_box_sg" {
  name        = "ml_box_sg"
  description = "Allow traffic from attack/target boxes for ML workloads"
  vpc_id      = aws_vpc.ml_vpc.id

  ingress {
    description = "Allow traffic from attack box subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  ingress {
    description = "Allow traffic from target box subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.private_subnet.cidr_block]
  }

  ingress {
    description = "Allow Docker container traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.17.0.0/16"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sagemaker_sg" {
  name        = "sagemaker_sg"
  description = "Security group for SageMaker services"
  vpc_id      = aws_vpc.ml_vpc.id

  ingress {
    description = "HTTPS from ML subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.ml_subnet.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Attack Box in Public Subnet (Vanilla Ubuntu)
resource "aws_instance" "attack_box" {
  ami                         = "ami-0866a3c8686eaeeba" # Ubuntu 24.04 LTS (us-east-1)
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.attack_box_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = var.attack_box_name
  }
}

# Target Box in Private Subnet (Ubuntu + Docker)
resource "aws_instance" "target_box" {
  ami                    = "ami-0866a3c8686eaeeba" # Ubuntu 24.04 LTS (us-east-1)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  key_name               = "DemoKey"
  vpc_security_group_ids = [aws_security_group.target_box_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
  EOF

  tags = {
    Name = var.target_box_name
  }
}

# ML Box in ML Subnet (Ubuntu + Docker + Python)
resource "aws_instance" "ml_box" {
  ami                    = "ami-0866a3c8686eaeeba" # Ubuntu 24.04 LTS (us-east-1)
  instance_type          = "t3.medium" # Larger instance for ML workloads
  subnet_id              = aws_subnet.ml_subnet.id
  key_name               = "DemoKey"
  vpc_security_group_ids = [aws_security_group.ml_box_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3-pip python3-venv
    
    # Install AWS CLI for ML services integration
    pip3 install awscli boto3
  EOF

  tags = {
    Name = var.ml_box_name
  }
}

# Random suffix for unique resource names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for ML models and data storage
resource "aws_s3_bucket" "ml_models" {
  bucket = "cybersec-lab-ml-models-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name = "ML Models Bucket"
    Project = "CybersecurityLab"
  }
}

resource "aws_s3_bucket_versioning" "ml_models_versioning" {
  bucket = aws_s3_bucket.ml_models.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role for SageMaker
resource "aws_iam_role" "sagemaker_role" {
  name = "cybersec-sagemaker-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "SageMaker Execution Role"
    Project = "CybersecurityLab"
  }
}

# SageMaker execution policy
resource "aws_iam_role_policy_attachment" "sagemaker_execution" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# S3 access for SageMaker
resource "aws_iam_role_policy" "sagemaker_s3_policy" {
  name = "sagemaker-s3-access"
  role = aws_iam_role.sagemaker_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ml_models.arn,
          "${aws_s3_bucket.ml_models.arn}/*"
        ]
      }
    ]
  })
}

# SageMaker Domain for Studio (newer interface)
resource "aws_sagemaker_domain" "ml_domain" {
  domain_name = "cybersec-ml-domain"
  auth_mode   = "IAM"
  vpc_id      = aws_vpc.ml_vpc.id
  subnet_ids  = [aws_subnet.ml_subnet.id]
  
  default_user_settings {
    execution_role = aws_iam_role.sagemaker_role.arn
    security_groups = [aws_security_group.sagemaker_sg.id]
  }
  
  tags = {
    Name = "Cybersecurity ML Domain"
    Project = "CybersecurityLab"
  }
}

# SageMaker notebook instance (stopped by default)
resource "aws_sagemaker_notebook_instance" "ml_workbench" {
  name                  = "cybersec-ml-workbench"
  role_arn             = aws_iam_role.sagemaker_role.arn
  instance_type        = "ml.t3.medium"
  subnet_id            = aws_subnet.ml_subnet.id
  security_groups      = [aws_security_group.sagemaker_sg.id]
  
  tags = {
    Name = "ML Workbench"
    Project = "CybersecurityLab"
  }
}

# Model package group for organizing ML models
resource "aws_sagemaker_model_package_group" "threat_models" {
  model_package_group_name        = "threat-detection-models"
  model_package_group_description = "Collection of threat detection model versions"
  
  tags = {
    Name = "Threat Detection Models"
    Project = "CybersecurityLab"
  }
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "cybersec-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "Lambda Execution Role"
    Project = "CybersecurityLab"
  }
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda SageMaker access policy
resource "aws_iam_role_policy" "lambda_sagemaker_policy" {
  name = "lambda-sagemaker-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:InvokeEndpoint"
        ]
        Resource = "*"
      }
    ]
  })
}

# API Gateway for ML endpoints (infrastructure only)
resource "aws_api_gateway_rest_api" "ml_api" {
  name        = "cybersec-ml-api"
  description = "API Gateway for ML threat detection services"
  
  tags = {
    Name = "ML API Gateway"
    Project = "CybersecurityLab"
  }
}

# Placeholder Lambda function
data "archive_file" "lambda_placeholder" {
  type        = "zip"
  output_path = "/tmp/lambda_placeholder.zip"
  source {
    content = <<EOF
def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'body': '{"message": "ML infrastructure ready - no model deployed yet"}'
    }
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "ml_processor" {
  filename         = data.archive_file.lambda_placeholder.output_path
  function_name    = "cybersec-ml-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256
  
  tags = {
    Name = "ML Processor Lambda"
    Project = "CybersecurityLab"
  }
}

# Output the attack box public IP for easy SSH access
output "attack_box_public_ip" {
  description = "Public IP address of the attack box"
  value       = aws_instance.attack_box.public_ip
}

# Output the target box private IP for reference
output "target_box_private_ip" {
  description = "Private IP address of the target box"
  value       = aws_instance.target_box.private_ip
}

# Output the ML box private IP for reference
output "ml_box_private_ip" {
  description = "Private IP address of the ML box"
  value       = aws_instance.ml_box.private_ip
}

# Output SageMaker domain information
output "sagemaker_domain_id" {
  description = "SageMaker Domain ID for Studio access"
  value       = aws_sagemaker_domain.ml_domain.id
}

# Output S3 bucket for ML models
output "ml_models_bucket" {
  description = "S3 bucket name for ML models and data"
  value       = aws_s3_bucket.ml_models.bucket
}

# Output API Gateway URL
output "ml_api_url" {
  description = "API Gateway URL for ML services (ready for endpoint configuration)"
  value       = aws_api_gateway_rest_api.ml_api.execution_arn
}