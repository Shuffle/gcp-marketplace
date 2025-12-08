# Shuffle Security Orchestration Platform

This module deploys [Shuffle](https://shuffler.io), an open-source Security Orchestration, Automation and Response (SOAR) platform, on Google Cloud Platform using Terraform.

Shuffle helps security teams automate repetitive tasks and connect different security tools through a visual workflow editor. This deployment creates a highly available Docker Swarm cluster with automatic NFS configuration, OpenSearch for data storage, and load-balanced frontend/backend services.

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
  source = "./terraform"

  project_id              = "your-project-id"
  goog_cm_deployment_name = "shuffle-deployment"
  region                  = "us-central1"
  node_count              = 1
  machine_type            = "e2-standard-2"
  shuffle_default_username = "admin@example.com"
}
```

### High Availability Deployment (Multi-Node)

```hcl
module "shuffle" {
  source = "./terraform"

  project_id              = "your-project-id"
  goog_cm_deployment_name = "shuffle-ha-deployment"
  region                  = "us-central1"
  node_count              = 3
  machine_type            = "e2-standard-4"
  boot_disk_size          = 250
  boot_disk_type          = "pd-ssd"
  shuffle_default_username = "admin@example.com"
  environment             = "production"
  enable_cloud_logging    = true
  enable_cloud_monitoring = true
}
```

### Production Deployment with Custom Network

```hcl
module "shuffle" {
  source = "./terraform"

  project_id              = "your-project-id"
  goog_cm_deployment_name = "shuffle-prod"
  region                  = "us-east1"
  node_count              = 5
  machine_type            = "e2-standard-4"
  boot_disk_size          = 500
  boot_disk_type          = "pd-balanced"
  
  # Network configuration
  subnet_cidr            = "10.100.0.0/16"
  external_access_cidrs  = "203.0.113.0/24,198.51.100.0/24"
  ssh_source_ranges      = "203.0.113.0/24"
  
  # Admin configuration
  shuffle_default_username = "security-admin@company.com"
  
  # Monitoring
  environment             = "production"
  enable_cloud_logging    = true
  enable_cloud_monitoring = true
}
```

## Accessing Shuffle

After deployment completes (approximately 10-15 minutes), access Shuffle:

1. **Get the Frontend URL** from outputs:
   ```bash
   terraform output shuffle_frontend_url
   ```

2. **Retrieve the admin password**:
   ```bash
   terraform output admin_password
   ```

3. **Access the web interface** at the displayed URL (port 3001)

4. **Login** with:
   - Username: Your configured email address
   - Password: From the output above

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
| shuffle\_default\_username | Default admin username for Shuffle (email format recommended) | `string` | n/a | yes |
| region | The Google Cloud region for deployment (nodes will be distributed across zones within this region) | `string` | `"us-central1"` | no |
| node\_count | Total number of nodes in the Shuffle cluster (min 1, max 10). Single node for testing, 3+ nodes for production HA. | `number` | `1` | no |
| machine\_type | GCP machine type for Shuffle nodes. e2-standard-2 (2 vCPUs, 8GB RAM) recommended for single node, e2-standard-4 for multi-node. | `string` | `"e2-standard-2"` | no |
| boot\_disk\_size | Boot disk size in GB | `number` | `120` | no |
| boot\_disk\_type | Boot disk type | `string` | `"pd-standard"` | no |
| source\_image | Source image for VMs. If empty, uses Ubuntu 22.04 LTS | `string` | `""` | no |
| subnet\_cidr | CIDR range for the Shuffle subnet | `string` | `"10.224.0.0/16"` | no |
| external\_access\_cidrs | Comma-separated CIDR ranges allowed to access Shuffle UI (port 3001) | `string` | `"0.0.0.0/0"` | no |
| enable\_ssh | Enable SSH access to nodes | `bool` | `true` | no |
| ssh\_source\_ranges | Comma-separated CIDR ranges allowed for SSH access | `string` | `"0.0.0.0/0"` | no |
| environment | Environment label (dev, staging, production) | `string` | `"production"` | no |
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
| admin\_username | Default admin username for Shuffle |
| admin\_password | Default admin password for Shuffle (auto-generated, sensitive) |
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

## Scaling

To scale the cluster:

1. Update `node_count` in your Terraform configuration
2. Run `terraform apply`
3. New nodes will automatically join the swarm

**Note**: Scaling down requires manual node removal:

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

<!-- Add EULA here -->

## Support

- **Shuffle Documentation**: https://shuffler.io/docs
- **GitHub Issues**: https://github.com/Shuffle/Shuffle/issues
- **Community Discord**: https://discord.gg/B2CBzUm
- **Support Email**: support@shuffler.io

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
