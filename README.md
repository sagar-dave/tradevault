# TradeVault

TradeVault is a cloud-native trade journal API built with Python FastAPI and deployed on AWS using Docker, EKS, Terraform, GitHub Actions, ArgoCD, AWS Load Balancer Controller, RDS PostgreSQL, and External Secrets.

This project demonstrates a production-style DevOps workflow: infrastructure as code, containerized application delivery, Kubernetes deployment, GitOps-based synchronization, secure secrets management, managed database connectivity, and public application exposure through an AWS Application Load Balancer.

---

## Project Overview

TradeVault is designed as a backend platform for tracking and managing trading activity. The current version focuses on the DevOps foundation rather than full product features.

The main goal of this project is to show how a real application can be built, containerized, deployed, secured, and operated on AWS using modern DevOps practices.

---

## Architecture

```text
Developer
  |
  | git push
  v
GitHub Repository
  |
  | GitHub Actions builds Docker image
  v
Amazon ECR
  |
  | Kubernetes manifests reference container image
  v
ArgoCD
  |
  | Syncs desired state from Git
  v
Amazon EKS
  |
  | Runs TradeVault API pods
  v
AWS Application Load Balancer
  |
  | Public HTTP traffic
  v
TradeVault FastAPI Service
  |
  | Reads DB credentials from Kubernetes Secret
  v
External Secrets Operator
  |
  | Pulls credentials from AWS Secrets Manager
  v
Amazon RDS PostgreSQL
```

---

## Tech Stack

### Application
- Python
- FastAPI
- SQLAlchemy
- PostgreSQL
- Docker

### DevOps / Cloud
- AWS EKS
- AWS RDS PostgreSQL
- AWS ECR
- AWS ALB
- AWS Secrets Manager
- AWS IAM / IRSA
- Terraform
- Kubernetes
- Helm
- ArgoCD
- GitHub Actions
- External Secrets Operator

### Observability / Operations
- Health endpoint
- Database connectivity endpoint
- Kubernetes readiness/liveness probes
- Terraform remote state using S3
- Terraform state locking using DynamoDB

---

## Key DevOps Features

### 1. Infrastructure as Code with Terraform

AWS infrastructure is provisioned and managed using Terraform.

Terraform manages:

- VPC
- Public and private subnets
- Internet gateway
- NAT gateway
- Route tables
- Security groups
- ECR repository
- RDS PostgreSQL instance
- EKS cluster
- EKS managed node group
- IAM roles and policies
- OIDC/IRSA integrations
- Terraform remote backend resources

Terraform remote state is stored in S3, with locking handled through DynamoDB.

---

### 2. Containerized API

The FastAPI backend is containerized using Docker and pushed to Amazon ECR.

GitHub Actions builds and publishes the image to ECR.

```text
GitHub Actions
  |
  | build Docker image
  v
Amazon ECR
```

---

### 3. Kubernetes Deployment on EKS

TradeVault runs on Amazon EKS with multiple API pods.

Kubernetes resources include:

- Namespace
- Deployment
- ClusterIP Service
- Ingress
- ConfigMap
- ExternalSecret
- Readiness probe
- Liveness probe

The API is deployed with 3 replicas for high availability across worker nodes.

---

### 4. GitOps with ArgoCD

ArgoCD runs inside EKS and watches the GitHub repository.

The ArgoCD application points to:

```text
kubernetes/eks
```

ArgoCD keeps the EKS cluster synchronized with the desired state in Git.

If someone manually changes the cluster, ArgoCD detects drift and restores the Git-defined state.

Tested behavior:

```text
Manual scale deployment to 1 replica
↓
ArgoCD detects drift
↓
ArgoCD restores deployment back to 3 replicas
```

---

### 5. Public Access Through AWS ALB

The application is exposed using AWS Load Balancer Controller and an ALB-backed Kubernetes Ingress.

Current demo traffic flow:

```text
Public ALB DNS
  |
  v
AWS Application Load Balancer
  |
  v
Kubernetes Ingress
  |
  v
ClusterIP Service
  |
  v
TradeVault API Pods
```

Current demo uses HTTP. HTTPS can be added later using AWS ACM, Route 53, and a custom domain.

---

### 6. Secure Secrets Management

Database credentials are not stored directly in Git.

Secrets flow:

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
TradeVault API Pod
```

External Secrets Operator uses IAM Roles for Service Accounts (IRSA) to securely read only the required secret from AWS Secrets Manager.

This replaces the older approach of manually applying a local Kubernetes Secret YAML file.

---

### 7. RDS PostgreSQL Connectivity

TradeVault API connects to Amazon RDS PostgreSQL using environment variables sourced from Kubernetes ConfigMap and Secret.

The `/db-check` endpoint verifies live database connectivity.

Example response:

```json
{
  "database": "connected",
  "result": 1
}
```

---

## API Endpoints

| Endpoint | Purpose |
|---|---|
| `/` | Root API response |
| `/health` | Health check endpoint |
| `/metrics` | Prometheus-style metrics endpoint |
| `/db-check` | Verifies RDS PostgreSQL connectivity |

Example root response:

```json
{
  "message": "Welcome to TradeVault API v3"
}
```

---

## Deployment Flow

```text
1. Developer pushes code to GitHub
2. GitHub Actions builds Docker image
3. Docker image is pushed to Amazon ECR
4. ArgoCD watches the Kubernetes manifests in Git
5. ArgoCD syncs manifests to EKS
6. EKS runs the TradeVault API pods
7. AWS ALB exposes the API publicly
8. API connects securely to RDS PostgreSQL
```

---

## Infrastructure Validation

Terraform confirms the deployed AWS infrastructure matches the code:

```bash
terraform -chdir=terraform/environments/dev plan
```

Expected result:

```text
No changes. Your infrastructure matches the configuration.
```

---

## Kubernetes Validation

Useful verification commands:

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -n tradevault -o wide
kubectl get svc -n tradevault
kubectl get ingress -n tradevault
kubectl get externalsecret -n tradevault
kubectl get secret tradevault-secret -n tradevault
```

---

## Application Validation

Public API test:

```bash
curl http://<ALB-DNS>/
```

Health check:

```bash
curl http://<ALB-DNS>/health
```

Database connectivity check:

```bash
curl http://<ALB-DNS>/db-check
```

Expected DB response:

```json
{
  "database": "connected",
  "result": 1
}
```

---

## Proof Screenshots

The project includes proof screenshots for:

1. EKS worker nodes ready
2. ArgoCD GitOps app synced and healthy
3. TradeVault API pods running on EKS
4. TradeVault service using ClusterIP
5. AWS ALB Ingress active
6. External Secrets synced from AWS Secrets Manager
7. Kubernetes Secret created by External Secrets
8. AWS Load Balancer Controller running
9. External Secrets Operator running
10. Terraform infrastructure matching AWS
11. Public ALB endpoint reaching TradeVault API
12. Public health endpoint working
13. TradeVault API connecting to RDS PostgreSQL
14. Git working tree clean

---

## Repository Structure

```text
tradevault/
├── backend/
│   └── app/
│       ├── main.py
│       └── database.py
├── docs/
│   ├── architecture.md
│   ├── runbook.md
│   ├── proof.md
│   └── screenshots/
├── kubernetes/
│   ├── local/
│   │   ├── namespace.yaml
│   │   ├── api-deployment.yaml
│   │   ├── api-service.yaml
│   │   ├── api-ingress.yaml
│   │   ├── api-secret.example.yaml
│   │   ├── postgres-deployment.yaml
│   │   ├── postgres-pvc.yaml
│   │   ├── postgres-service.yaml
│   │   └── monitoring manifests
│   └── eks/
│       ├── namespace.yaml
│       ├── api-deployment.yaml
│       ├── api-service.yaml
│       ├── api-configmap.yaml
│       ├── api-ingress.yaml
│       └── external-secrets/
│           ├── secret-store.yaml
│           └── external-secret.yaml
├── terraform/
│   ├── bootstrap/
│   └── environments/
│       └── dev/
├── argocd/
│   ├── eks-tradevault-app.yaml
│   └── local-tradevault-app.yaml
├── .github/
│   └── workflows/
│       └── backend-ci.yml
└── README.md
```

---

## Security Notes

- Real database credentials are stored in AWS Secrets Manager.
- Kubernetes secrets are generated by External Secrets Operator.
- IAM access is scoped using IRSA.
- Secret manifest files are excluded from Git.
- The application database is hosted on RDS inside private networking.
- Public access is routed through AWS ALB.

---

## Cost Notes

This project uses paid AWS resources, including:

- EKS cluster
- EC2 worker nodes
- NAT Gateway
- RDS PostgreSQL
- Application Load Balancer

For cost control, the environment should be destroyed when not actively being used.

Terraform destroy command:

```bash
terraform -chdir=terraform/environments/dev destroy
```

Bootstrap resources such as the Terraform state bucket and DynamoDB lock table should only be destroyed if the entire project environment is no longer needed.

---

## Current Status

Completed:

- FastAPI backend
- Dockerized API
- GitHub Actions image build and ECR push
- AWS infrastructure with Terraform
- Terraform remote backend with S3 and DynamoDB
- EKS cluster with managed node group
- RDS PostgreSQL
- Kubernetes deployment on EKS
- AWS ALB public ingress
- ArgoCD GitOps deployment
- External Secrets integration with AWS Secrets Manager
- RDS connectivity validation
- Final proof screenshots

Next possible improvements:

- Add HTTPS with ACM and Route 53
- Add custom domain
- Add Prometheus and Grafana on EKS
- Add app-specific dashboards and alerts
- Add automated image tag promotion
- Add staging/prod environment separation
- Add CI tests and database migration workflow

---

## Summary

TradeVault demonstrates a complete cloud-native DevOps deployment pipeline:

```text
Code
→ Docker
→ GitHub Actions
→ ECR
→ Terraform-managed AWS infrastructure
→ EKS
→ ArgoCD GitOps
→ ALB public access
→ External Secrets
→ RDS PostgreSQL
```

This project is designed to showcase practical DevOps engineering skills using real AWS infrastructure and production-style deployment patterns.

Selected deployment proof screenshots are available here: [Deployment Proof](docs/proof.md)