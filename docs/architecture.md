# TradeVault Architecture

This document explains the architecture of the TradeVault cloud-native DevOps project.

TradeVault is a FastAPI + PostgreSQL application deployed on AWS using Terraform, Kubernetes, EKS, GitHub Actions, ECR, ArgoCD, AWS ALB, AWS Secrets Manager, External Secrets Operator, and RDS PostgreSQL.

---

## 1. High-Level Architecture

```text
Developer Machine
  |
  | git push
  v
GitHub Repository
  |
  | GitHub Actions builds Docker image
  v
Amazon ECR
  |
  | Kubernetes Deployment pulls image
  v
Amazon EKS
  |
  | ArgoCD syncs Kubernetes manifests from Git
  v
TradeVault API Pods
  |
  | Connect using environment variables
  v
Amazon RDS PostgreSQL
```

External traffic reaches the application through an AWS Application Load Balancer:

```text
User / Browser / curl
  |
  v
AWS Application Load Balancer
  |
  v
Kubernetes Ingress
  |
  v
Kubernetes ClusterIP Service
  |
  v
TradeVault API Pods
```

Secrets are handled separately:

```text
AWS Secrets Manager
  |
  v
External Secrets Operator
  |
  v
Kubernetes Secret
  |
  v
TradeVault API Pods
```

---

## 2. Core Components

## 2.1 FastAPI Application

TradeVault uses a Python FastAPI backend.

The API provides endpoints such as:

| Endpoint | Purpose |
|---|---|
| `/` | Root application response |
| `/health` | Health check endpoint |
| `/metrics` | Metrics endpoint |
| `/db-check` | Verifies RDS PostgreSQL connectivity |

The `/db-check` endpoint proves that the application pod can connect to the private RDS database.

---

## 2.2 Docker

The FastAPI application is packaged into a Docker image.

Docker solves the problem of application consistency.

Instead of depending on a specific machine setup, the application runs inside a container with its dependencies packaged together.

Flow:

```text
Source Code
  |
  v
Docker Build
  |
  v
Docker Image
  |
  v
Container running in Kubernetes
```

---

## 2.3 GitHub Actions

GitHub Actions handles CI/CD automation.

When code is pushed to GitHub, GitHub Actions can:

1. Checkout the source code
2. Build the Docker image
3. Authenticate to AWS using OIDC
4. Push the image to Amazon ECR

This avoids manual Docker build and push steps.

---

## 2.4 Amazon ECR

Amazon Elastic Container Registry stores the Docker image.

EKS pulls the TradeVault API image from ECR when creating application pods.

Flow:

```text
GitHub Actions
  |
  | docker push
  v
Amazon ECR
  |
  | image pull
  v
EKS Worker Nodes
```

---

## 2.5 Terraform

Terraform manages AWS infrastructure as code.

Terraform is responsible for creating and managing cloud resources such as:

- VPC
- Public subnets
- Private subnets
- Internet Gateway
- NAT Gateway
- Route Tables
- Security Groups
- ECR Repository
- RDS PostgreSQL
- EKS Cluster
- EKS Managed Node Group
- IAM Roles
- OIDC Provider
- IAM Policies

Terraform allows the environment to be recreated consistently.

The key idea:

```text
Terraform code = desired AWS infrastructure
terraform apply = create/update AWS resources
terraform destroy = remove AWS resources
```

---

## 2.6 Terraform Remote State

Terraform state tracks what Terraform created.

This project uses remote state so the state is not stored only on one local machine.

Backend resources:

- S3 bucket stores Terraform state
- DynamoDB table can be used for state locking

Remote state helps prevent accidental drift and makes the project easier to continue later.

---

## 2.7 VPC Networking

The VPC is the private network boundary for the AWS infrastructure.

TradeVault uses:

- Public subnets
- Private subnets
- Internet Gateway
- NAT Gateway
- Route Tables

General design:

```text
VPC
├── Public Subnets
│   ├── ALB
│   └── NAT Gateway
└── Private Subnets
    ├── EKS Worker Nodes
    └── RDS PostgreSQL
```

Public subnets allow internet-facing components.

Private subnets protect internal components such as EKS worker nodes and RDS.

---

## 2.8 Amazon EKS

Amazon EKS is AWS-managed Kubernetes.

EKS provides the Kubernetes control plane, while worker nodes run the application pods.

TradeVault runs on EKS using:

- Kubernetes Deployments
- Services
- Ingress
- ConfigMaps
- Secrets
- ExternalSecrets

EKS gives the application:

- Self-healing
- Declarative deployment
- Scaling foundation
- Service discovery
- GitOps compatibility
- Kubernetes-native operations

---

## 2.9 EKS Worker Nodes

Worker nodes are EC2 instances attached to the EKS cluster.

The TradeVault API pods run on these worker nodes.

Flow:

```text
EKS Control Plane
  |
  | schedules pods
  v
EKS Worker Nodes
  |
  v
TradeVault API Pods
```

If a pod crashes, Kubernetes can restart it.

If a node is unavailable, Kubernetes can schedule pods on healthy nodes.

---

## 2.10 Kubernetes Namespace

TradeVault uses a dedicated Kubernetes namespace:

```text
tradevault
```

A namespace separates TradeVault resources from other cluster resources.

Resources inside the namespace include:

- API Deployment
- API Service
- ConfigMap
- ExternalSecret
- Generated Secret
- Ingress

---

## 2.11 Kubernetes Deployment

The Deployment defines how the TradeVault API should run.

It controls:

- Docker image
- Replica count
- Container port
- Environment variables
- Health checks
- Pod template

The Deployment ensures the desired number of API pods are running.

Example concept:

```text
Desired state: 3 API pods
Actual state: 2 API pods
Kubernetes action: create 1 more pod
```

---

## 2.12 Kubernetes Service

The Service provides a stable internal network endpoint for the API pods.

TradeVault uses a `ClusterIP` Service.

Meaning:

```text
Service is reachable inside the cluster only.
It does not directly expose the app to the public internet.
```

Traffic flow:

```text
Ingress
  |
  v
ClusterIP Service
  |
  v
API Pods
```

This is cleaner than exposing pods directly.

---

## 2.13 Kubernetes Ingress

Ingress defines how external HTTP traffic should reach the application.

TradeVault uses an Ingress with AWS Load Balancer Controller.

The Ingress tells AWS to create an Application Load Balancer.

Flow:

```text
Ingress YAML
  |
  v
AWS Load Balancer Controller
  |
  v
AWS Application Load Balancer
```

The Ingress routes public traffic to the internal ClusterIP Service.

---

## 2.14 AWS Load Balancer Controller

AWS Load Balancer Controller watches Kubernetes Ingress resources.

When it sees the TradeVault Ingress, it creates and manages an AWS Application Load Balancer.

This connects Kubernetes with AWS networking.

Without this controller, Kubernetes Ingress would not automatically create an AWS ALB.

---

## 2.15 AWS Application Load Balancer

The AWS ALB exposes the TradeVault API publicly.

The ALB receives HTTP traffic from users and forwards it into the EKS cluster.

Flow:

```text
Browser / curl
  |
  v
AWS ALB
  |
  v
Kubernetes Ingress
  |
  v
ClusterIP Service
  |
  v
TradeVault API Pod
```

Current demo uses HTTP.

Future improvement:

```text
ACM + Route 53 + custom domain + HTTPS
```

---

## 2.16 ConfigMap

The ConfigMap stores non-sensitive application configuration.

Examples:

- Database name
- Database host
- Database port

ConfigMap is appropriate for non-secret values.

It should not store passwords.

---

## 2.17 AWS Secrets Manager

AWS Secrets Manager stores sensitive database credentials.

This includes:

- RDS username
- RDS password

Secrets Manager keeps these values outside Git.

This avoids committing sensitive credentials into the repository.

---

## 2.18 External Secrets Operator

External Secrets Operator syncs secrets from AWS Secrets Manager into Kubernetes.

Flow:

```text
AWS Secrets Manager
  |
  v
External Secrets Operator
  |
  v
Kubernetes Secret
```

The application does not talk directly to AWS Secrets Manager.

Instead, the pod reads values from a Kubernetes Secret created by External Secrets Operator.

---

## 2.19 Kubernetes Secret

The Kubernetes Secret is created automatically from AWS Secrets Manager.

TradeVault pods use the secret as environment variables.

Flow:

```text
Kubernetes Secret
  |
  v
Environment Variables
  |
  v
FastAPI Application
```

This allows the API to connect to RDS without hardcoding credentials.

---

## 2.20 IRSA

IRSA means IAM Roles for Service Accounts.

It allows a Kubernetes service account to assume an AWS IAM role.

External Secrets Operator uses IRSA to read only the required secret from AWS Secrets Manager.

Why this matters:

```text
No static AWS keys inside the cluster.
No broad IAM permissions.
Pod-level AWS access can be scoped securely.
```

---

## 2.21 Amazon RDS PostgreSQL

Amazon RDS hosts the PostgreSQL database.

RDS is managed by AWS, which reduces operational work for:

- Database provisioning
- Backups
- Patching
- Storage management
- Availability options

TradeVault API connects to RDS using:

- Host from ConfigMap
- Port from ConfigMap
- Database name from ConfigMap
- Username from Secret
- Password from Secret

---

## 2.22 ArgoCD

ArgoCD provides GitOps deployment.

It watches the GitHub repository and syncs Kubernetes manifests into EKS.

Flow:

```text
GitHub Repository
  |
  v
ArgoCD
  |
  v
EKS Cluster
```

ArgoCD compares:

```text
Desired state in Git
vs.
Actual state in Kubernetes
```

If they differ, ArgoCD can sync the cluster back to the Git-defined state.

This enables self-healing deployment behavior.

---

## 3. End-to-End Deployment Flow

```text
1. Developer pushes code to GitHub

2. GitHub Actions builds Docker image

3. Docker image is pushed to Amazon ECR

4. Terraform provisions AWS infrastructure

5. EKS cluster runs Kubernetes workloads

6. ArgoCD syncs Kubernetes manifests from GitHub

7. Kubernetes creates TradeVault API pods

8. External Secrets Operator syncs DB credentials from AWS Secrets Manager

9. AWS Load Balancer Controller creates an ALB from the Ingress

10. Public traffic reaches the API through the ALB

11. API connects to RDS PostgreSQL
```

---

## 4. Request Flow

When a user calls the public API:

```text
User
  |
  v
AWS Application Load Balancer
  |
  v
Kubernetes Ingress
  |
  v
Kubernetes ClusterIP Service
  |
  v
TradeVault API Pod
  |
  v
RDS PostgreSQL
```

For `/health`, the API responds without database dependency.

For `/db-check`, the API connects to RDS and returns a successful database result.

---

## 5. Secret Flow

```text
AWS Secrets Manager
  |
  | stores POSTGRES_USER and POSTGRES_PASSWORD
  v
External Secrets Operator
  |
  | reads secret using IRSA
  v
Kubernetes Secret
  |
  | mounted/injected as environment variables
  v
TradeVault API Pod
```

This keeps sensitive credentials out of Git.

---

## 6. GitOps Flow

```text
GitHub Repository
  |
  | Kubernetes manifests committed
  v
ArgoCD
  |
  | watches repository path
  v
EKS Cluster
  |
  | syncs desired state
  v
Kubernetes Resources
```

If someone manually changes Kubernetes resources, ArgoCD detects the difference.

Example:

```text
Manual change: scale API deployment from 3 replicas to 1
Git desired state: 3 replicas
ArgoCD action: restore deployment to 3 replicas
```

---

## 7. Infrastructure Lifecycle

### Create

```bash
terraform -chdir=terraform/environments/dev apply
```

### Validate

```bash
terraform -chdir=terraform/environments/dev plan
```

Expected when healthy:

```text
No changes. Your infrastructure matches the configuration.
```

### Destroy

```bash
terraform -chdir=terraform/environments/dev destroy
```

Before destroy, delete GitOps and Ingress resources to avoid orphaned ALB resources:

```bash
kubectl delete application tradevault-eks -n argocd --ignore-not-found
kubectl delete ingress tradevault-api-alb -n tradevault --ignore-not-found
```

---

## 8. Why This Architecture Matters

This architecture demonstrates practical DevOps skills:

- Infrastructure as Code using Terraform
- Container image delivery using GitHub Actions and ECR
- Kubernetes deployment using EKS
- GitOps deployment using ArgoCD
- Public traffic routing using AWS ALB
- Secret management using AWS Secrets Manager and External Secrets Operator
- Database integration using RDS PostgreSQL
- Secure AWS access using IAM and IRSA
- Cost-aware cleanup using Terraform destroy and post-destroy verification

---

## 9. Current Limitations

Current limitations:

- HTTP only, no HTTPS yet
- No custom domain yet
- Uses `latest` image tag
- No full monitoring stack deployed yet
- No production/staging separation yet
- No automated database migration workflow yet

---

## 10. Future Improvements

Possible next improvements:

- Add HTTPS with AWS ACM
- Add Route 53 custom domain
- Add immutable image tags
- Add ArgoCD Image Updater
- Add Prometheus and Grafana
- Add CloudWatch or Loki logging
- Add HPA autoscaling
- Add staging and production environments
- Add database migrations with Alembic
- Add CI test stage before image build
- Add backup and restore process for RDS

---

## 11. Interview Explanation Summary

TradeVault is a production-style DevOps portfolio project.

The application is a FastAPI backend containerized with Docker. GitHub Actions builds the image and pushes it to Amazon ECR. Terraform provisions AWS infrastructure including VPC, EKS, RDS, ECR, IAM, and networking resources. EKS runs the application pods. ArgoCD watches the GitHub repository and syncs Kubernetes manifests into the cluster using GitOps. AWS Load Balancer Controller creates an ALB from the Kubernetes Ingress to expose the API publicly. Database credentials are stored in AWS Secrets Manager and synced into Kubernetes using External Secrets Operator with IRSA. The application connects securely to RDS PostgreSQL, and the full environment can be destroyed using Terraform for cost control.