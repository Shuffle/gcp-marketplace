# Shuffle Security Orchestration Platform

This proprietary deployment package deploys the free open-source version of [Shuffle](https://shuffler.io) in Docker Swarm mode on Google Cloud Platform using Terraform.

Shuffle is a Security Orchestration, Automation and Response (SOAR) platform that helps security teams automate repetitive tasks and connect different security tools through a visual workflow editor. This deployment creates a Docker Swarm cluster with automatic NFS configuration, OpenSearch for data storage, and load-balanced frontend/backend services.

**To learn more about the differences between free open-source and enterprise versions, visit:** https://shuffler.io/articles/Shuffle_Open_Source

**By deploying this Software, you agree to the End-User License Agreement at:** https://shuffler.io/legal/GCP_EULA

## Architecture

- **Multi-node Docker Swarm cluster** (1-10 nodes, all as managers)
- **Automatic NFS server** configuration for shared storage
- **OpenSearch 3.0.0** for data persistence and search
- **Load-balanced services** with Nginx
- **Auto-scaling** based on node count
- **Distributed deployment** across zones within a region

## Prerequisites

- Google Cloud Project with billing enabled
- Required APIs enabled:
  - Compute Engine API
  - Cloud Logging API (optional)
  - Cloud Monitoring API (optional)
- Sufficient IAM permissions:
  - `roles/compute.instanceAdmin.v1`
  - `roles/compute.networkAdmin`
  - `roles/compute.securityAdmin`
  - `roles/iam.serviceAccountUser`

## Usage

### Basic Deployment (Single Node)

```hcl
module "shuffle" {
  source = "./"

  project_id              = "your-project-id"
  goog_cm_deployment_name = "shuffle-deployment"
  zone                    = "us-central1-a"
  node_count              = 1
  machine_type            = "e2-standard-2"
}
```

### Multi-Node Deployment (3 Nodes)

```hcl
module "shuffle" {
  source = "./"

  project_id              = "your-project-id"
  goog_cm_deployment_name = "shuffle-deployment"
  zone                    = "us-central1-a"
  node_count              = 3
  machine_type            = "e2-standard-4"
  boot_disk_size          = 250
  boot_disk_type          = "pd-ssd"
  environment             = "production"
  enable_cloud_logging    = true
  enable_cloud_monitoring = true
}
```

### Production Deployment with Custom Network

```hcl
module "shuffle" {
  source = "./"

  project_id              = "your-project-id"
  goog_cm_deployment_name = "shuffle-prod"
  zone                    = "us-east1-b"
  node_count              = 5
  machine_type            = "e2-standard-4"
  boot_disk_size          = 500
  boot_disk_type          = "pd-balanced"
  
  # Network configuration
  subnet_cidr            = "10.100.0.0/16"
  external_access_cidrs  = "203.0.113.0/24,198.51.100.0/24"
  ssh_source_ranges      = "203.0.113.0/24"
  
  # Monitoring
  environment             = "production"
  enable_cloud_logging    = true
  enable_cloud_monitoring = true
}
```

## CLI-Based Deployment Guide

### Prerequisites Setup

1. **Install Google Cloud SDK**
   
   Download and install the gcloud CLI:
   - **Windows**: Download from https://cloud.google.com/sdk/docs/install
   - **macOS**: `brew install google-cloud-sdk`
   - **Linux**: 
     ```bash
     curl https://sdk.cloud.google.com | bash
     exec -l $SHELL
     ```

2. **Install Terraform**
   
   - **Windows**: Download from https://www.terraform.io/downloads or use Chocolatey:
     ```powershell
     choco install terraform
     ```
   - **macOS**: 
     ```bash
     brew tap hashicorp/tap
     brew install hashicorp/tap/terraform
     ```
   - **Linux**:
     ```bash
     wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
     unzip terraform_1.6.0_linux_amd64.zip
     sudo mv terraform /usr/local/bin/
     ```

3. **Verify Installations**
   ```bash
   gcloud --version
   terraform --version
   ```

### Step-by-Step Deployment

#### Step 1: Authenticate with Google Cloud

```bash
# Login to your Google Cloud account
gcloud auth login

# Authenticate Terraform to use your credentials
gcloud auth application-default login

# Set your project (replace with your actual project ID)
gcloud config set project YOUR_PROJECT_ID

# Verify current configuration
gcloud config list
```

#### Step 2: Enable Required APIs

```bash
# Enable Compute Engine API
gcloud services enable compute.googleapis.com

# Enable Cloud Logging API (optional but recommended)
gcloud services enable logging.googleapis.com

# Enable Cloud Monitoring API (optional but recommended)
gcloud services enable monitoring.googleapis.com

# Verify enabled services
gcloud services list --enabled
```

#### Step 3: Configure Deployment Variables

Create a `terraform.tfvars` file with your configuration:

```bash
# For single-node testing deployment
cat > terraform.tfvars << 'EOF'
goog_cm_deployment_name = "shuffle-vm"
zone                    = "us-central1-a"
node_count              = 1
machine_type            = "e2-standard-2"
boot_disk_size          = 120
enable_cloud_logging    = true
enable_cloud_monitoring = true
EOF
```

Or for production multi-node deployment:

```bash
cat > terraform.tfvars << 'EOF'
goog_cm_deployment_name = "shuffle-vm"
zone                    = "us-east1-b"
node_count              = 3
machine_type            = "e2-standard-4"
boot_disk_size          = 250
boot_disk_type          = "pd-ssd"
subnet_cidr             = "10.100.0.0/16"
external_access_cidrs   = "YOUR_IP_ADDRESS/32"
ssh_source_ranges       = "YOUR_IP_ADDRESS/32"
environment             = "production"
enable_cloud_logging    = true
enable_cloud_monitoring = true
EOF
```

Replace `YOUR_IP_ADDRESS` with your actual IP address to restrict access:

#### Step 5: Initialize Terraform

```bash
# Initialize Terraform and download required providers
terraform init

# Validate configuration
terraform validate
```

#### Step 6: Review Deployment Plan

```bash
# Generate and review the execution plan
terraform plan -var project_id=<PROJECT_ID>  -var-file terraform.tfvars    
# Save the plan to a file for review
terraform plan -out=tfplan

# Review the saved plan
terraform show tfplan
```

#### Step 7: Deploy Shuffle

```bash
# Apply the configuration
terraform apply -var project_id=<PROJECT_ID>  -var-file terraform.tfvars

```

**Expected Output**:
```
Apply complete! Resources: XX added, 0 changed, 0 destroyed.

Outputs:

deployment_name = "shuffle-deployment"
shuffle_frontend_url = "http://XX.XX.XX.XX:3001"
manager_instances = [...]
```

**Deployment Time**: Approximately 10-15 minutes

#### Step 8: Verify Deployment

```bash
# Get deployment outputs
terraform output

# Get specific output
terraform output shuffle_frontend_url

# Export outputs to file
terraform output -json > deployment-outputs.json
```

### Post-Deployment CLI Operations

#### Connect to Instances

```bash
# SSH to primary manager
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a

# SSH with custom SSH key
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --ssh-key-file=~/.ssh/my-key

# SSH to specific node
gcloud compute ssh shuffle-vm-manager-2 --zone=us-central1-b
```

#### Monitor Deployment Status

```bash
# Check instance status
gcloud compute instances list --filter="name~'shuffle-vm'"

# View instance details
gcloud compute instances describe shuffle-vm-manager-1 --zone=us-central1-a

# Check instance serial port output (startup logs)
gcloud compute instances get-serial-port-output shuffle-vm-manager-1 --zone=us-central1-a
```

#### Docker Swarm Management via CLI

After SSH into a manager node:

```bash
# Check swarm status
docker node ls

# View all services
docker service ls

# Check service details
docker service ps shuffle_frontend
docker service ps shuffle_backend
docker service ps shuffle_orborus

# View service logs
docker service logs shuffle_frontend --tail 50 --follow
docker service logs shuffle_backend --tail 50 --follow

# Scale services (if needed)
docker service scale shuffle_frontend=2
docker service scale shuffle_backend=2

# Check OpenSearch health
curl http://localhost:9200/_cluster/health?pretty

# View OpenSearch indices
curl http://localhost:9200/_cat/indices?v
```

#### Update Firewall Rules

```bash
# Add additional IP to external access
gcloud compute firewall-rules update shuffle-deployment-allow-external \
  --source-ranges="203.0.113.0/24,198.51.100.0/24"

# Update SSH access rules
gcloud compute firewall-rules update shuffle-deployment-allow-ssh \
  --source-ranges="YOUR_NEW_IP/32"

# List current firewall rules
gcloud compute firewall-rules list --filter="name~'shuffle'"
```

#### Backup Operations

```bash
# Create disk snapshots
gcloud compute disks snapshot shuffle-vm-manager-1 \
  --snapshot-names=shuffle-backup-$(date +%Y%m%d) \
  --zone=us-central1-a

# List snapshots
gcloud compute snapshots list --filter="name~'shuffle'"

# Backup via SSH (execute on manager node)
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "sudo tar -czf /tmp/shuffle-nfs-backup-$(date +%F).tar.gz /srv/nfs/"

# Download backup from instance
gcloud compute scp shuffle-vm-manager-1:/tmp/shuffle-nfs-backup-*.tar.gz ./ \
  --zone=us-central1-a
```

#### Monitoring and Logs

```bash
# View Cloud Logging logs
gcloud logging read "resource.type=gce_instance AND resource.labels.instance_id:shuffle-vm" \
  --limit 50 --format json

# Stream logs in real-time
gcloud logging tail "resource.type=gce_instance AND resource.labels.instance_id:shuffle-vm"

# Check specific service logs
gcloud logging read "resource.type=gce_instance AND textPayload:shuffle" \
  --limit 100

# Export logs to file
gcloud logging read "resource.type=gce_instance AND resource.labels.instance_id:shuffle-vm" \
  --format json > shuffle-logs-$(date +%F).json
```

#### Cleanup and Destruction

```bash
# Preview resources to be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing 'yes' when prompted

# Verify cleanup
gcloud compute instances list --filter="name~'shuffle-vm'"
gcloud compute firewall-rules list --filter="name~'shuffle'"

# Remove local state files (optional)
rm -f terraform.tfstate terraform.tfstate.backup tfplan
```

### Troubleshooting CLI Commands

#### Check Deployment Status

```bash
# If deployment seems stuck, check startup script progress
gcloud compute instances get-serial-port-output shuffle-vm-manager-1 \
  --zone=us-central1-a | grep -A 20 "shuffle-startup"

# Check if services are running
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "docker service ls"

# View startup log file
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "sudo cat /var/log/shuffle-startup.log"
```

#### Network Connectivity Issues

```bash
# Test external connectivity to frontend
curl -I http://$(terraform output -raw shuffle_frontend_url | cut -d'/' -f3)

# Check firewall rules
gcloud compute firewall-rules describe shuffle-deployment-allow-external

# Test from specific source IP
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "curl -I http://localhost:3001"
```

#### Service Health Checks

```bash
# Check all service health
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "docker service ps shuffle_frontend shuffle_backend shuffle_orborus opensearch --no-trunc"

# Restart a service if needed
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "docker service update --force shuffle_frontend"

# Check OpenSearch status
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "curl -s http://localhost:9200/_cluster/health | python3 -m json.tool"
```

#### Manual Redeployment

```bash
# If automatic deployment failed, trigger manually
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "cd /opt/shuffle && sudo ./deploy.sh"

# Monitor deployment progress
gcloud compute ssh shuffle-vm-manager-1 --zone=us-central1-a --command \
  "sudo tail -f /var/log/shuffle-startup.log"
```

### Quick Reference Commands

```bash
# Get frontend URL
terraform output shuffle_frontend_url

# SSH to primary manager
gcloud compute ssh shuffle-vm-manager-1 --zone=$(terraform output -raw zone)

# View all outputs
terraform output -json | jq

# Check instance status
gcloud compute instances list --filter="name~'shuffle-vm'"

# View service logs (from manager node)
docker service logs shuffle_frontend --tail 100

# Check swarm health (from manager node)
docker node ls && docker service ls

# Backup NFS data (from manager node)
sudo tar -czf ~/shuffle-backup-$(date +%F).tar.gz /srv/nfs/

# Update Shuffle images (from manager node)
docker service update --image ghcr.io/shuffle/shuffle-frontend:latest shuffle_frontend
```

## Accessing Shuffle

After deployment completes (approximately 10-15 minutes), access Shuffle:

1. **Get the Frontend URL** from outputs:
   ```bash
   terraform output shuffle_frontend_url
   ```

2. **Access the web interface** at the displayed URL (port 3001)

3. **Complete initial setup** through the web interface to create your admin account

## Post-Deployment

### SSH into Primary Manager

```bash
gcloud compute ssh shuffle-vm-manager-1 --zone=<zone>
```

### Check Docker Swarm Status

```bash
docker node ls
docker stack services shuffle
```

### View Service Logs

```bash
docker service logs shuffle_frontend
docker service logs shuffle_backend
docker service logs shuffle_orborus
```

### Monitor OpenSearch

```bash
curl http://localhost:9200/_cluster/health?pretty
```

## Security Considerations

- **External Access**: Only port 3001 (Shuffle Frontend) is exposed externally
- **HTTPS**: Port 3443 is configured internally but not exposed for security
- **OpenSearch**: Accessible only within the VPC (port 9200)
- **NFS**: Internal network communication only
- **SSH Access**: Configurable via `ssh_source_ranges`
- **Firewall**: Restricted by `external_access_cidrs`

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project\_id | The Google Cloud project ID | `string` | n/a | yes |
| goog\_cm\_deployment\_name | Deployment name from Google Cloud Marketplace | `string` | n/a | yes |
| zone | The zone where Shuffle cluster will be deployed. If more than one node is deployed, they will be distributed across multiple zones within the selected region. | `string` | n/a | yes |
| node\_count | Total number of nodes in the Shuffle cluster (min 1, max 10). Single node for testing, 3+ nodes for production deployments. | `number` | `1` | no |
| machine\_type | GCP machine type for Shuffle nodes. e2-standard-2 (2 vCPUs, 8GB RAM) recommended for single node, e2-standard-4 for multi-node. | `string` | `"e2-standard-2"` | no |
| boot\_disk\_size | Boot disk size in GB (120-1000 GB) | `number` | `120` | no |
| boot\_disk\_type | Boot disk type (pd-standard, pd-ssd, or pd-balanced) | `string` | `"pd-standard"` | no |
| source\_image | Source image for VMs | `string` | `"projects/shuffle-public/global/images/shuffle-ubuntu2404-x86-64-20251208"` | no |
| subnet\_cidr | CIDR range for the Shuffle subnet (must be valid IPv4 CIDR) | `string` | `"10.224.0.0/16"` | no |
| external\_access\_cidrs | Comma-separated CIDR ranges allowed to access Shuffle UI (port 3001, must be valid IPv4 CIDR) | `string` | `"0.0.0.0/0"` | no |
| enable\_ssh | Enable SSH access to nodes | `bool` | `true` | no |
| ssh\_source\_ranges | Comma-separated CIDR ranges allowed for SSH access (must be valid IPv4 CIDR) | `string` | `"0.0.0.0/0"` | no |
| environment | Environment label (dev, staging, or production) | `string` | `"production"` | no |
| enable\_cloud\_logging | Enable Google Cloud Logging | `bool` | `true` | no |
| enable\_cloud\_monitoring | Enable Google Cloud Monitoring | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| deployment\_name | Name of the deployment |
| shuffle\_frontend\_url | URL to access Shuffle Frontend (HTTP on port 3001) |
| opensearch\_internal\_url | Internal URL to access OpenSearch (not exposed externally) |
| manager\_instances | List of manager instance details (name, IPs, zone) |
| total\_nodes | Total number of nodes in the cluster |
| manager\_nodes | Number of manager nodes (same as total\_nodes) |
| network\_name | Name of the VPC network |
| subnet\_name | Name of the subnet |
| nfs\_server\_ip | IP address of the NFS server (primary manager) |
| swarm\_join\_command\_manager | Command to join swarm as manager (retrieve from primary manager) |
| swarm\_join\_command\_worker | Command to join swarm as worker (retrieve from primary manager) |
| post\_deployment\_instructions | Instructions after deployment |

## Troubleshooting

### Deployment Issues

If services don't start automatically:

```bash
# SSH to primary manager
gcloud compute ssh shuffle-vm-manager-1 --zone=<zone>

# Check startup logs
cat /var/log/shuffle-startup.log

# Manually trigger deployment
cd /opt/shuffle
sudo ./deploy.sh
```

### Service Health Check

```bash
# Check all running services
docker service ls

# Check specific service health
docker service ps shuffle_frontend --no-trunc

# View recent logs
docker service logs --tail 100 shuffle_backend
```

### Network Connectivity

```bash
# Test OpenSearch
curl http://localhost:9200/_cluster/health

# Test Frontend
curl http://localhost:3001/api/v1/health

# Check NFS mounts
showmount -e localhost
```

```bash
docker node rm <node-name>
```

## Backup and Disaster Recovery

### Backup Strategy

- **Database**: OpenSearch data stored on NFS (`/srv/nfs/shuffle-database`)
- **Applications**: App data on NFS (`/srv/nfs/shuffle-apps`)
- **Files**: User files on NFS (`/srv/nfs/shuffle-files`)

### Recommended Backup

```bash
# Create snapshot of boot disks
gcloud compute disks snapshot <disk-name> --zone=<zone>

# Backup NFS data
tar -czf shuffle-backup-$(date +%F).tar.gz /srv/nfs/
```

## Upgrading

To upgrade Shuffle:

```bash
# SSH to primary manager
gcloud compute ssh shuffle-vm-manager-1 --zone=<zone>

# Pull latest images
docker service update --image ghcr.io/shuffle/shuffle-frontend:latest shuffle_frontend
docker service update --image ghcr.io/shuffle/shuffle-backend:latest shuffle_backend
docker service update --image ghcr.io/shuffle/shuffle-orborus:latest shuffle_orborus
```

## Resource Requirements

### Minimum Requirements (Single Node)
- **CPU**: 2 vCPUs
- **RAM**: 8 GB
- **Disk**: 120 GB
- **Machine Type**: e2-standard-2

### Recommended Production (3+ Nodes)
- **CPU**: 4 vCPUs per node
- **RAM**: 16 GB per node
- **Disk**: 250+ GB per node
- **Machine Type**: e2-standard-4 or higher

## License

This Software is proprietary and confidential. Unauthorized copying, distribution, modification, or use of this file, via any medium, is strictly prohibited.

Licensed for use only under the End-User License Agreement (EULA) available at: https://shuffler.io/legal/GCP_EULA

By deploying or using this Software, you acknowledge that you have read, understood, and agree to be bound by the terms and conditions of the EULA.

## Support

For support, please visit:
- Website: https://shuffler.io
- Email: support@shuffler.io
- Documentation: https://shuffler.io/docs
- GitHub Issues: https://github.com/Shuffle/Shuffle/issues
- Community Discord: https://discord.gg/B2CBzUm

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | ~> 5.0 |
| random | ~> 3.1 |
| null | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| google | ~> 5.0 |
| random | ~> 3.1 |
| null | ~> 3.0 |
