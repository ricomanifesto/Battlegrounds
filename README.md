# Terraform AWS Cybersecurity Lab

Creates isolated AWS infrastructure for testing security tools and ML threat detection. Three-VPC architecture with full mesh connectivity.

Calculate costs before deployment using AWS cost calculator.

## Infrastructure

- Three VPCs with network isolation (Public, Private, ML)
- Full mesh VPC peering
- Attack Box: vanilla Ubuntu in public subnet
- Target Box: Ubuntu + Docker in private subnet  
- ML Box: Ubuntu + Docker + Python in ML subnet
- SageMaker Domain and notebook instance
- S3 bucket for ML models and training data
- API Gateway + Lambda for ML inference
- Security groups limiting access to authorized traffic

## Structure

```
terraform/
├── main.tf           # All resources and variables
ansible/
├── docker-install.yml # Docker installation playbook
├── inventory.ini     # Host definitions
└── README.md        # Ansible setup guide
```

## Requirements

- [Terraform](https://www.terraform.io/downloads)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- AWS IAM user with EC2 and VPC permissions
- AWS CLI configured (`~/.aws/credentials`)
- AWS EC2 Key Pair (default name: "DemoKey", configurable)

## Setup

Clone and deploy:
```bash
git clone https://github.com/ricomanifesto/Battlegrounds.git
cd Battlegrounds/terraform
terraform init
terraform apply -var="my_public_ip=$(curl -s icanhazip.com)/32"

# Optional: Use different key pair
terraform apply -var="my_public_ip=$(curl -s icanhazip.com)/32" -var="key_name=YourKeyName"
```

Configure with Ansible:
```bash
cd ../ansible
# Update inventory.ini with IPs from terraform output
ansible-playbook -i inventory.ini docker-install.yml
```

Connect to attack box:
```bash
ssh -i ~/.ssh/DemoKey.pem ubuntu@<attack_box_public_ip>
# Or if using different key: ssh -i ~/.ssh/YourKeyName.pem ubuntu@<attack_box_public_ip>
```

Connect to target box from attack box:
```bash
ssh ubuntu@<target_box_private_ip>
```

Connect to ML box from attack box:
```bash
ssh ubuntu@<ml_box_private_ip>
```

## Variables

| Name              | Description                     | Example          | Required |
|-------------------|---------------------------------|------------------|----------|
| `my_public_ip`    | Your public IP for SSH access  | `203.0.113.5/32` | Yes      |
| `key_name`        | AWS EC2 Key Pair name          | `DemoKey`        | No       |
| `attack_box_name` | Attack box instance name        | `Attack Box`     | No       |
| `target_box_name` | Target box instance name        | `Target Box`     | No       |
| `ml_box_name`     | ML box instance name            | `ML Box`         | No       |

## Teardown

```bash
terraform destroy -var="my_public_ip=$(curl -s icanhazip.com)/32"
```

## Usage

**Attack Box**: Deploy tools via Docker containers. SSH access from your IP only.

**Target Box**: Run vulnerable services in Docker containers. Access only from attack box. Configured via Ansible.

**ML Box**: Run ML models and analysis tools. Access from attack and target boxes. Configured via Ansible.

Deploy tools on attack box:
```bash
docker run -it --rm kalilinux/kali-rolling
```

Deploy vulnerable services on target box:
```bash
docker run -d -p 80:80 vulnerables/web-dvwa
docker run -d -p 3306:3306 vulnerable/mysql
```

Deploy ML models on ML box:
```bash
docker run -d -p 8000:8000 ml-threat-detector
```

Test from attack box:
```bash
nmap <target_private_ip>
curl http://<ml_box_private_ip>:8000/detect -d '{"traffic": "..."}'
```

## ML Infrastructure

**SageMaker Domain**: ML development environment (stopped by default)
**S3 Bucket**: Versioned model and training data storage
**API Gateway**: REST endpoints for ML inference (infrastructure only)
**Lambda**: Serverless ML processing

Access SageMaker Studio:
```bash
aws sagemaker describe-domain --domain-id <sagemaker_domain_id>
```

Cost: ~$47/month baseline, ~$50-100/month with ML usage.

## Modern IaC Workflow

This project demonstrates modern Infrastructure as Code best practices:

- **Terraform**: Infrastructure provisioning only
- **Ansible**: Configuration management and Docker installation  
- **Docker**: Application packaging and deployment

**Benefits:**
- Clean separation of concerns
- Version-controlled infrastructure and configuration
- Reproducible environments
- Enterprise-ready patterns

