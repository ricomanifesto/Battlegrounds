# Ansible Configuration

Ansible playbooks for configuring the cybersecurity lab infrastructure.

## Setup

1. Install Ansible:
```bash
pip install ansible
```

2. Update inventory.ini with actual IP addresses from Terraform output:
```bash
terraform output
```

3. Run Docker installation playbook:
```bash
ansible-playbook -i inventory.ini docker-install.yml
```

## Files

- `docker-install.yml`: Installs Docker on target and ML boxes
- `inventory.ini`: Defines hosts and connection settings
- `README.md`: This file

## Usage

After running `terraform apply`, update inventory.ini with the actual IP addresses, then run:

```bash
# Install Docker on all boxes
ansible-playbook -i inventory.ini docker-install.yml

# Install Docker on specific group
ansible-playbook -i inventory.ini docker-install.yml --limit target_boxes
```

## Connection

Connect through the attack box (bastion host) to reach private instances:
```bash
ssh -J ubuntu@<attack_box_public_ip> ubuntu@<target_box_private_ip>
```