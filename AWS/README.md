# Shuffle – AWS Deployment Guide

> **Note:** The default AMI in this CloudFormation template is in the **us-east-1** region. If you are deploying via the AWS CLI or the CloudFormation console directly, you must use us-east-1, or replace the AMI ID with one from your target region. Deploying through the AWS Marketplace handles this automatically.

## Overview

This CloudFormation template deploys Shuffle on AWS using a Docker Swarm cluster. It provisions EC2 instances, a VPC, and the supporting infrastructure needed to run Shuffle.

![Shuffle Architecture Diagram](https://shuffler.s3.us-east-2.amazonaws.com/config/architecture-diagram.png)

## Prerequisites

1. **AWS Account** – Sufficient permissions to create VPCs, EC2 instances, and IAM roles.
2. **EC2 Key Pair** – An existing key pair **in the same region you are deploying to**. EC2 key pairs are region-specific; a key pair created in one region is not available in another. Required for SSH access to the instances.

## Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| **DeploymentName** | `shuffle-cluster` | Name prefix applied to all created resources. |
| **Environment** | `production` | Environment tag (`dev`, `staging`, `production`). |
| **NodeCount** | `1` | Number of Swarm nodes (1–10). Use 3 or more for multi-node setups. |
| **InstanceType** | `t3.large` | EC2 instance type. `m5.xlarge` is recommended for production workloads. |
| **VolumeSize** | `120` | Root EBS volume size in GB. |
| **VpcCIDR** | `10.224.0.0/16` | CIDR block for the new VPC. |
| **ExternalAccessCIDRs** | `0.0.0.0/0` | CIDR range allowed to reach the Shuffle UI on port 3001. |

## Deployment Steps

1. Log in to your AWS account and go to the [Shuffle listing on AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-typ7upg6kwntk).
2. Click **Purchase options**, scroll down, and click **Subscribe**.
3. Once the subscription is active, click **Launch your software**, then **Launch with CloudFormation**.
4. You will be taken to the CloudFormation launch page. Click **Next**.
5. Enter a **Stack Name**. Set the **Environment** tag to `dev`, `staging`, or `production` as appropriate. Set **NodeCount** to `1` for a single-node setup, or `3` if you want nodes distributed across multiple availability zones.
6. Select an existing **EC2 Key Pair** from the list. This is required to deploy the instance.
7. Click **Next**, scroll down, check the box for **"I acknowledge that AWS CloudFormation might create IAM resources"**, and click **Submit**.
8. Wait for the stack to reach the `CREATE_COMPLETE` state. If you run into any issues, contact us at support@shuffler.io.

## After Deployment

1. **Find the public IP** – Check the EC2 console or the CloudFormation **Outputs** tab.
2. **Open the UI** – Navigate to `http://<PUBLIC_IP>:3001` in your browser.
3. **Create an account** – On first launch, you will be prompted to create an admin account.
4. **Need help?** – If you run into any difficulties during deployment or have questions, contact us at support@shuffler.io.

## Troubleshooting

- **Cluster status** – SSH into a node and run `docker node ls` to check the Swarm state.
- **Service status** – Run `docker service ls` to see if all Shuffle services are running.

## Support

- **Documentation**: [shuffler.io/docs](https://shuffler.io/docs)
- **Discord**: [discord.gg/shuffle](https://discord.gg/shuffle)
- **Website**: [shuffler.io](https://shuffler.io)
