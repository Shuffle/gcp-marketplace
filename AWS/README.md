# Shuffle AWS Marketplace Deployment Guide

## Overview

This guide provides complete instructions for deploying Shuffle SOAR Platform on AWS through the AWS Marketplace using CloudFormation templates.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [AWS Permissions Required](#aws-permissions-required)
- [Resource Requirements](#resource-requirements)
- [Deployment Instructions](#deployment-instructions)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Architecture Comparison: GCP vs AWS](#architecture-comparison-gcp-vs-aws)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)

---

## Architecture Overview

The Shuffle AWS deployment creates a highly available Docker Swarm cluster with the following components:

### Infrastructure Components

1. **VPC & Networking**
   - Custom VPC with configurable CIDR
   - Public subnet with Internet Gateway
   - Route tables and network ACLs
   - Security groups for internal and external access

2. **Compute Resources**
   - EC2 instances (1-10 nodes) in Auto Scaling Group
   - All nodes act as Docker Swarm managers
   - Ubuntu 22.04 LTS base image
   - Configurable instance types (t3.large to m6i.2xlarge)

3. **Storage**
   - EBS volumes (120-1000 GB, gp3/gp2/io1/io2)
   - NFS shared storage for Shuffle apps and files
   - Local OpenSearch data directories

4. **Security**
   - Security groups for internal cluster communication
   - External access only on port 3001 (Shuffle UI)
   - Optional SSH access with configurable CIDR
   - Encrypted EBS volumes
   - IAM roles with least privilege

5. **Shuffle Services (Docker Swarm)**
   - **Frontend**: Shuffle UI (port 3001)
   - **Backend**: API and workflow engine
   - **Orborus**: Workflow orchestrator
   - **OpenSearch**: Data storage and indexing
   - **Workers**: Workflow execution engines
   - **Memcached**: In-memory caching
   - **Load Balancer**: Nginx for traffic distribution

---

## Prerequisites

### AWS Account Requirements

1. **AWS Account** with:
   - Valid payment method
   - Service limits that support your deployment size
   - Region where you want to deploy selected

2. **EC2 Key Pair**
   - Create an EC2 Key Pair in your target region
   - Download the private key (.pem file)
   - Secure the private key file (`chmod 400 keypair.pem`)

3. **AWS CLI** (optional but recommended)
   - Install: `pip install awscli`
   - Configure: `aws configure`

4. **IAM Permissions**
   - See [AWS Permissions Required](#aws-permissions-required) section

### Technical Requirements

- **Minimum Configuration**: 1 node, t3.large (2 vCPUs, 8GB RAM)
- **Recommended for Production**: 3 nodes, m5.xlarge (4 vCPUs, 16GB RAM each)
- **High Availability**: 5+ nodes distributed across availability zones

---

## AWS Permissions Required

### For CloudFormation Deployment

The IAM user or role deploying the stack needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:DescribeStackResources",
        "cloudformation:GetTemplate",
        "cloudformation:ValidateTemplate"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:CreateSubnet",
        "ec2:CreateInternetGateway",
        "ec2:CreateRouteTable",
        "ec2:CreateRoute",
        "ec2:CreateSecurityGroup",
        "ec2:CreateNetworkInterface",
        "ec2:CreateTags",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:AttachInternetGateway",
        "ec2:AssociateRouteTable",
        "ec2:ModifyVpcAttribute",
        "ec2:ModifySubnetAttribute",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeImages",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeNetworkInterfaces",
        "ec2:RunInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:CreateAutoScalingGroup",
        "autoscaling:CreateLaunchConfiguration",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:CreateInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:DeleteRole",
        "iam:DeleteInstanceProfile",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRole",
        "iam:GetInstanceProfile",
        "iam:PassRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:DeleteParameter",
        "ssm:DescribeParameters"
      ],
      "Resource": "*"
    }
  ]
}
```

### For EC2 Instances (Managed by CloudFormation)

The CloudFormation template automatically creates an IAM role with these permissions:

- **CloudWatch Logs**: Write logs for monitoring
- **Systems Manager**: Remote management and parameter store
- **EC2 Read-Only**: Discover cluster members
- **Auto Scaling Read**: Determine cluster topology

---

## Resource Requirements

### AWS Resources Created

| Resource Type | Quantity | Purpose |
|--------------|----------|---------|
| VPC | 1 | Network isolation |
| Subnet | 1 | Instance placement |
| Internet Gateway | 1 | External connectivity |
| Route Table | 1 | Network routing |
| Security Groups | 2-3 | Firewall rules |
| EC2 Instances | 1-10 | Compute nodes |
| Auto Scaling Group | 1 | Instance lifecycle |
| Launch Template | 1 | Instance configuration |
| IAM Role | 1 | Instance permissions |
| IAM Instance Profile | 1 | Role attachment |
| CloudWatch Log Group | 1 | Centralized logging |

### Service Limits to Check

Before deployment, verify these AWS service limits in your region:

1. **EC2 Limits**
   - EC2 instances (vCPU quota)
   - VPCs per region (default: 5)
   - Security groups per VPC (default: 500)
   - Rules per security group (default: 60)

2. **EBS Limits**
   - Volume storage (GB)
   - IOPS (for io1/io2 volumes)

3. **Auto Scaling Limits**
   - Auto Scaling groups per region (default: 200)
   - Launch configurations per region (default: 200)

Check your limits:
```bash
aws service-quotas list-service-quotas --service-code ec2 --region us-east-1
```

---

## Deployment Instructions

### Option 1: AWS Console Deployment

1. **Navigate to CloudFormation**
   - Open AWS Management Console
   - Go to CloudFormation service
   - Select your target region

2. **Create Stack**
   - Click "Create stack" → "With new resources (standard)"
   - Choose "Upload a template file"
   - Upload `shuffle-marketplace.yaml`
   - Click "Next"

3. **Configure Stack Parameters**

   **Deployment Configuration:**
   - **Stack name**: `shuffle-production` (or your choice)
   - **DeploymentName**: `shuffle-cluster`
   - **Environment**: `production`

   **Instance Configuration:**
   - **NodeCount**: `1` (start with 1, scale later)
   - **InstanceType**: `t3.large` (2 vCPUs, 8GB RAM)
   - **VolumeSize**: `120` GB
   - **VolumeType**: `gp3` (recommended)
   - **KeyPairName**: Select your EC2 key pair

   **Network Configuration:**
   - **VpcCIDR**: `10.224.0.0/16` (default)
   - **SubnetCIDR**: `10.224.1.0/24` (default)
   - **ExternalAccessCIDRs**: `0.0.0.0/0` (or restrict to your IP)
   - **EnableSSH**: `true`
   - **SSHAccessCIDRs**: `0.0.0.0/0` (or restrict to your IP)

   **Shuffle Configuration:**
   - **DefaultUsername**: Leave empty (set on first login)
   - **DefaultPassword**: Leave empty (set on first login)
   - **EncryptionKey**: Generate a strong 32+ character key
     ```bash
     openssl rand -base64 32
     ```

4. **Configure Stack Options**
   - Tags (optional): Add tags for cost tracking
   - Permissions: Use default
   - Stack failure options: Roll back all stack resources
   - Advanced options: Leave default

5. **Review and Create**
   - Review all parameters
   - Check "I acknowledge that AWS CloudFormation might create IAM resources"
   - Click "Submit"

6. **Monitor Deployment**
   - Watch the "Events" tab for progress
   - Deployment takes 10-15 minutes
   - Look for "CREATE_COMPLETE" status

### Option 2: AWS CLI Deployment

1. **Prepare Parameters File**

Create `parameters.json`:

```json
[
  {
    "ParameterKey": "DeploymentName",
    "ParameterValue": "shuffle-cluster"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "production"
  },
  {
    "ParameterKey": "NodeCount",
    "ParameterValue": "1"
  },
  {
    "ParameterKey": "InstanceType",
    "ParameterValue": "t3.large"
  },
  {
    "ParameterKey": "VolumeSize",
    "ParameterValue": "120"
  },
  {
    "ParameterKey": "VolumeType",
    "ParameterValue": "gp3"
  },
  {
    "ParameterKey": "KeyPairName",
    "ParameterValue": "your-keypair-name"
  },
  {
    "ParameterKey": "VpcCIDR",
    "ParameterValue": "10.224.0.0/16"
  },
  {
    "ParameterKey": "SubnetCIDR",
    "ParameterValue": "10.224.1.0/24"
  },
  {
    "ParameterKey": "ExternalAccessCIDRs",
    "ParameterValue": "0.0.0.0/0"
  },
  {
    "ParameterKey": "EnableSSH",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "SSHAccessCIDRs",
    "ParameterValue": "0.0.0.0/0"
  },
  {
    "ParameterKey": "DefaultUsername",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "DefaultPassword",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "EncryptionKey",
    "ParameterValue": "REPLACE_WITH_STRONG_32_CHAR_KEY"
  }
]
```

2. **Deploy Stack**

```bash
aws cloudformation create-stack \
  --stack-name shuffle-production \
  --template-body file://shuffle-marketplace.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

3. **Monitor Deployment**

```bash
aws cloudformation describe-stacks \
  --stack-name shuffle-production \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

Or watch events:

```bash
aws cloudformation describe-stack-events \
  --stack-name shuffle-production \
  --region us-east-1 \
  --max-items 10
```

### Option 3: Terraform Wrapper (Advanced)

If you prefer Terraform, create a wrapper:

```hcl
# main.tf
provider "aws" {
  region = var.region
}

resource "aws_cloudformation_stack" "shuffle" {
  name = "shuffle-production"
  
  template_body = file("${path.module}/shuffle-marketplace.yaml")
  
  parameters = {
    DeploymentName      = var.deployment_name
    Environment         = var.environment
    NodeCount          = var.node_count
    InstanceType       = var.instance_type
    KeyPairName        = var.key_pair_name
    VpcCIDR            = var.vpc_cidr
    SubnetCIDR         = var.subnet_cidr
    ExternalAccessCIDRs = join(",", var.external_access_cidrs)
    EnableSSH          = var.enable_ssh
    SSHAccessCIDRs     = join(",", var.ssh_access_cidrs)
    EncryptionKey      = var.encryption_key
  }
  
  capabilities = ["CAPABILITY_NAMED_IAM"]
}
```

---

## Post-Deployment Configuration

### 1. Get Instance Public IP

**Via AWS Console:**
- Go to EC2 → Instances
- Find instance tagged with your deployment name
- Copy Public IPv4 address

**Via AWS CLI:**
```bash
aws ec2 describe-instances \
  --filters "Name=tag:DeploymentName,Values=shuffle-cluster" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

### 2. Access Shuffle UI

Open browser and navigate to:
```
http://<INSTANCE_PUBLIC_IP>:3001
```

**Initial Setup:**
1. First access will prompt for admin credentials
2. Create admin username and password (minimum 3 characters)
3. Save credentials securely

### 3. Verify Deployment

**SSH into instance:**
```bash
ssh -i your-keypair.pem ubuntu@<INSTANCE_PUBLIC_IP>
```

**Check Docker Swarm status:**
```bash
sudo docker node ls
```

Expected output (1 node):
```
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS
abc123def456 *                ip-xxx     Ready     Active         Leader
```

**Check running services:**
```bash
sudo docker stack services shuffle
```

Expected services:
- shuffle_backend
- shuffle_frontend
- shuffle_load-balancer
- shuffle_memcached
- shuffle_opensearch
- shuffle_orborus

**View service logs:**
```bash
sudo docker service logs shuffle_frontend --tail 50
sudo docker service logs shuffle_backend --tail 50
sudo docker service logs shuffle_opensearch --tail 50
```

### 4. Configure DNS (Optional)

For production, configure a DNS record:

**Route 53 Example:**
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "shuffle.yourdomain.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<INSTANCE_PUBLIC_IP>"}]
      }
    }]
  }'
```

### 5. Setup HTTPS (Recommended)

**Option A: Application Load Balancer with ACM**

Create an ALB with AWS Certificate Manager (ACM) certificate:

```bash
# Create ALB
aws elbv2 create-load-balancer \
  --name shuffle-alb \
  --subnets <subnet-id> \
  --security-groups <sg-id>

# Create target group pointing to port 3001
aws elbv2 create-target-group \
  --name shuffle-tg \
  --protocol HTTP \
  --port 3001 \
  --vpc-id <vpc-id>

# Register instances
aws elbv2 register-targets \
  --target-group-arn <tg-arn> \
  --targets Id=<instance-id>

# Create HTTPS listener with ACM certificate
aws elbv2 create-listener \
  --load-balancer-arn <alb-arn> \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=<acm-cert-arn> \
  --default-actions Type=forward,TargetGroupArn=<tg-arn>
```

**Option B: Let's Encrypt on instance**

SSH to instance and configure:

```bash
# Install certbot
sudo apt-get update
sudo apt-get install -y certbot

# Get certificate
sudo certbot certonly --standalone -d shuffle.yourdomain.com

# Update nginx configuration
# (see GCP nginx-main.conf for SSL configuration example)
```

---

## Architecture Comparison: GCP vs AWS

### Infrastructure Mapping

| Component | GCP | AWS |
|-----------|-----|-----|
| **Compute** | Compute Engine Instances | EC2 Instances |
| **Networking** | VPC Network | VPC |
| **Subnets** | Subnetwork | Subnet |
| **External Access** | Cloud Load Balancing (optional) | Internet Gateway + Public IP |
| **Firewall** | Firewall Rules | Security Groups |
| **Instance Groups** | Managed Instance Groups | Auto Scaling Groups |
| **Instance Template** | Instance Template | Launch Template |
| **IAM** | Service Accounts | IAM Roles + Instance Profiles |
| **Logging** | Cloud Logging | CloudWatch Logs |
| **Monitoring** | Cloud Monitoring | CloudWatch Metrics |
| **Metadata Service** | metadata.google.internal | EC2 instance metadata |
| **Zones** | Zones (europe-west3-a) | Availability Zones (us-east-1a) |

### Key Differences

#### 1. **Networking**

**GCP:**
- Uses global VPC with regional subnets
- Firewall rules are VPC-level
- Implicit egress allowed
- Metadata server: `http://metadata.google.internal`

**AWS:**
- VPC is regional
- Security groups are stateful firewalls
- Network ACLs are stateless
- Metadata server: `http://169.254.169.254`

#### 2. **Instance Initialization**

**GCP:**
```bash
# Get metadata
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/my-attribute
```

**AWS:**
```bash
# Get metadata
curl http://169.254.169.254/latest/meta-data/instance-id

# Or use helper
ec2-metadata --instance-id
```

#### 3. **Managed Instance Groups vs Auto Scaling**

**GCP:**
- Instance template defines configuration
- Managed Instance Group maintains desired count
- Built-in health checking
- Easy rolling updates

**AWS:**
- Launch Template defines configuration
- Auto Scaling Group maintains desired count
- Health checks via EC2 or ELB
- Rolling updates via CloudFormation or manual

#### 4. **Service Discovery**

**GCP:**
```bash
# Get all instances in instance group
gcloud compute instance-groups managed list-instances <group-name>
```

**AWS:**
```bash
# Get all instances in auto scaling group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <asg-name> \
  --query 'AutoScalingGroups[0].Instances'
```

### Terraform Equivalence

| GCP Resource | AWS Resource |
|--------------|--------------|
| `google_compute_network` | `aws_vpc` |
| `google_compute_subnetwork` | `aws_subnet` |
| `google_compute_firewall` | `aws_security_group` + rules |
| `google_compute_instance` | `aws_instance` |
| `google_compute_instance_template` | `aws_launch_template` |
| `google_compute_instance_group_manager` | `aws_autoscaling_group` |
| `google_project_iam_member` | `aws_iam_role` + `aws_iam_policy` |

---

## Troubleshooting

### Instance Initialization Issues

**Problem**: Instance starts but Shuffle doesn't deploy

**Check:**
1. View user data execution logs:
   ```bash
   ssh -i keypair.pem ubuntu@<instance-ip>
   sudo cat /var/log/cloud-init-output.log
   ```

2. Check Docker status:
   ```bash
   sudo systemctl status docker
   sudo docker ps
   ```

3. Check Shuffle logs:
   ```bash
   sudo docker service logs shuffle_backend
   ```

### Swarm Cluster Issues

**Problem**: Nodes not joining swarm

**Solution:**
1. Check security groups allow ports 2377, 7946, 4789
2. Verify internal communication:
   ```bash
   # From one node, ping another
   ping <other-node-private-ip>
   ```

3. Manual join (if needed):
   ```bash
   # On primary manager
   docker swarm join-token manager
   
   # On other node
   docker swarm join --token <token> <primary-ip>:2377
   ```

### OpenSearch Issues

**Problem**: OpenSearch container keeps restarting

**Check:**
1. Memory settings:
   ```bash
   sudo docker service logs shuffle_opensearch
   ```

2. Disk space:
   ```bash
   df -h /opt/shuffle/shuffle-database
   ```

3. Adjust memory (if needed):
   ```bash
   # Edit swarm.yaml memory limits
   # Redeploy: sudo /opt/shuffle/deploy.sh
   ```

### Network Connectivity Issues

**Problem**: Can't access Shuffle UI

**Check:**
1. Security group allows port 3001 from your IP:
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <sg-id> \
     --query 'SecurityGroups[0].IpPermissions'
   ```

2. Nginx is running:
   ```bash
   sudo docker service ps shuffle_load-balancer
   ```

3. Test locally on instance:
   ```bash
   curl http://localhost:3001
   ```

### Performance Issues

**Symptoms**: Slow workflow execution, high latency

**Solutions:**

1. **Increase instance size:**
   - Update CloudFormation stack
   - Change `InstanceType` to larger size (e.g., t3.xlarge → m5.xlarge)

2. **Add more nodes:**
   - Update `NodeCount` parameter
   - CloudFormation will scale Auto Scaling Group

3. **Optimize OpenSearch:**
   ```bash
   # Check OpenSearch cluster health
   curl http://localhost:9200/_cluster/health?pretty
   
   # View index stats
   curl http://localhost:9200/_cat/indices?v
   ```

4. **Monitor resources:**
   ```bash
   # CPU and memory
   top
   
   # Disk I/O
   iostat -x 1
   
   # Docker stats
   sudo docker stats
   ```

---

## Cost Estimation

### Monthly Cost Breakdown (us-east-1)

#### Single Node (Minimum)
- **EC2**: t3.large (2 vCPUs, 8GB RAM)
  - On-Demand: ~$60/month
  - 1-year Reserved: ~$36/month
  - 3-year Reserved: ~$24/month
- **EBS**: 120GB gp3
  - ~$10/month
- **Data Transfer**: 
  - First 100GB out: Free
  - Additional: $0.09/GB
- **Estimated Total**: **$70-80/month**

#### Production (3 Nodes)
- **EC2**: 3x m5.xlarge (4 vCPUs, 16GB RAM each)
  - On-Demand: ~$420/month
  - 1-year Reserved: ~$252/month
- **EBS**: 3x 200GB gp3
  - ~$50/month
- **Data Transfer**: ~$20/month
- **CloudWatch**: ~$10/month
- **Estimated Total**: **$500-550/month** (on-demand)

#### High Availability (5 Nodes)
- **EC2**: 5x m5.xlarge
  - On-Demand: ~$700/month
  - 1-year Reserved: ~$420/month
- **EBS**: 5x 250GB gp3
  - ~$100/month
- **Application Load Balancer**: ~$20/month
- **Data Transfer**: ~$50/month
- **CloudWatch**: ~$20/month
- **Estimated Total**: **$890-990/month** (on-demand)

### Cost Optimization Tips

1. **Use Reserved Instances**
   - 1-year: ~40% savings
   - 3-year: ~60% savings

2. **Use Savings Plans**
   - Compute Savings Plans: Flexible across instance types
   - EC2 Instance Savings Plans: Higher discount, less flexibility

3. **Use Spot Instances (Non-production)**
   - Up to 90% discount
   - Risk of interruption

4. **Right-size Instances**
   - Start small, monitor usage
   - Use CloudWatch metrics to optimize

5. **Optimize Storage**
   - Use gp3 instead of gp2 (lower cost, better performance)
   - Regular cleanup of old data
   - Consider S3 for long-term storage

6. **Network Optimization**
   - Use VPC endpoints for AWS services
   - Minimize cross-region data transfer
   - Use CloudFront for global users

---

## AWS Marketplace Publishing Requirements

### Prerequisites for AWS Marketplace Listing

1. **AMI Requirements**
   - Based on supported Linux distribution (Ubuntu 22.04 LTS recommended)
   - Must be published to AWS Marketplace AMI Product
   - Product code embedded in AMI
   - Region-specific AMI IDs

2. **CloudFormation Template Requirements**
   - Must use AWS::CloudFormation::Interface metadata
   - Parameter groups and labels for user-friendly UI
   - Proper parameter validation
   - IAM capabilities acknowledgment
   - Output instructions for users

3. **Security Requirements**
   - No hardcoded credentials
   - Use AWS Secrets Manager or Systems Manager Parameter Store
   - Encrypted EBS volumes
   - Security groups follow least privilege
   - IAM roles with minimal permissions

4. **Documentation Requirements**
   - README with deployment instructions
   - Architecture diagram
   - Troubleshooting guide
   - Cost estimation
   - Support contact information

5. **Testing Requirements**
   - Test in multiple AWS regions
   - Test with different parameter combinations
   - Validate all outputs work correctly
   - Test upgrade path
   - Performance benchmarks

### Publishing Process

1. **Prepare AMI**
   - Build Shuffle on Ubuntu 22.04 LTS
   - Install all dependencies
   - Clean up (SSH keys, logs, etc.)
   - Create snapshot
   - Share with AWS Marketplace

2. **Submit to AWS Marketplace**
   - Log in to AWS Marketplace Management Portal
   - Create new product
   - Upload CloudFormation template
   - Provide product details
   - Submit for review

3. **AWS Review Process**
   - Security scan (2-3 days)
   - Template validation (1-2 days)
   - Documentation review (1 day)
   - Total: 5-7 business days

4. **Go Live**
   - Address any review feedback
   - Set pricing (free or paid)
   - Publish to marketplace

---

## Support and Resources

### Shuffle Resources
- Website: https://shuffler.io
- Documentation: https://shuffler.io/docs
- GitHub: https://github.com/Shuffle
- Community: https://discord.gg/shuffle

### AWS Resources
- CloudFormation Docs: https://docs.aws.amazon.com/cloudformation/
- Marketplace Seller Guide: https://docs.aws.amazon.com/marketplace/
- EC2 Best Practices: https://docs.aws.amazon.com/ec2/
- Well-Architected Framework: https://aws.amazon.com/architecture/well-architected/

---

## License

This CloudFormation template is provided as-is for deploying Shuffle on AWS. Shuffle itself is licensed under AGPL-3.0.

---

**Last Updated**: January 2026
**Version**: 1.0.0
**Maintainer**: Shuffle Team
