# TradeVault Runbook

This runbook documents how to deploy, verify, troubleshoot, and safely destroy the TradeVault AWS EKS dev environment.

TradeVault is a cloud-native FastAPI + PostgreSQL application deployed using:

- AWS EKS
- AWS ECR
- AWS RDS PostgreSQL
- AWS Application Load Balancer
- AWS Secrets Manager
- External Secrets Operator
- ArgoCD
- GitHub Actions
- Terraform

---

## 1. Project Region

All AWS resources for this project are deployed in:

```bash
us-east-2
```

Verify AWS CLI region:

```bash
aws configure get region
```

If needed, export the region:

```bash
export AWS_REGION=us-east-2
```

---

## 2. Important Paths

Repository root:

```bash
/Users/sega/devops-projects/tradevault
```

Terraform dev environment:

```bash
terraform/environments/dev
```

Terraform bootstrap backend:

```bash
terraform/bootstrap
```

Kubernetes EKS manifests:

```bash
kubernetes/eks
```

ArgoCD application manifest:

```bash
argocd/eks-tradevault-app.yaml
```

---

## 3. Terraform Backend

Terraform remote state is stored in S3.

The backend is created separately using the bootstrap Terraform configuration.

Backend resources may include:

- S3 bucket for Terraform state
- DynamoDB table for Terraform state locking

Do not destroy bootstrap resources unless the entire project is being permanently removed.

---

## 4. Deploy Infrastructure

From the repository root:

```bash
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev plan
terraform -chdir=terraform/environments/dev apply
```

Approve when prompted:

```bash
yes
```

Terraform creates the AWS dev infrastructure, including:

- VPC
- Subnets
- Internet Gateway
- NAT Gateway
- Security Groups
- ECR repository
- RDS PostgreSQL
- EKS cluster
- EKS managed node group
- IAM roles and policies

---

## 5. Connect kubectl to EKS

After Terraform creates the EKS cluster, update local kubeconfig:

```bash
aws eks update-kubeconfig \
  --region us-east-2 \
  --name tradevault-dev-eks
```

Verify cluster access:

```bash
kubectl get nodes
```

Expected result:

```text
EKS worker nodes should show Ready status.
```

---

## 6. Deploy Kubernetes Resources

ArgoCD manages Kubernetes resources from Git.

Apply the ArgoCD application:

```bash
kubectl apply -f argocd/eks-tradevault-app.yaml
```

Check ArgoCD application status:

```bash
kubectl get applications -n argocd
```

Expected result:

```text
tradevault-eks   Synced   Healthy
```

---

## 7. Verify Application Pods

Check TradeVault namespace resources:

```bash
kubectl get pods -n tradevault -o wide
kubectl get svc -n tradevault
kubectl get ingress -n tradevault
```

Expected results:

- API pods are Running
- Service type is ClusterIP
- Ingress has an AWS ALB address

---

## 8. Verify AWS Load Balancer Controller

Check controller deployment:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

Expected result:

```text
READY 2/2
```

The AWS Load Balancer Controller creates the AWS ALB from the Kubernetes Ingress resource.

---

## 9. Verify External Secrets

Check External Secrets Operator:

```bash
kubectl get pods -n external-secrets
```

Expected result:

```text
external-secrets pods should be Running.
```

Check ExternalSecret sync:

```bash
kubectl get externalsecret -n tradevault
```

Expected result:

```text
STATUS: SecretSynced
READY: True
```

Check generated Kubernetes Secret:

```bash
kubectl get secret tradevault-secret -n tradevault
```

Expected result:

```text
tradevault-secret exists with 2 data values.
```

---

## 10. Verify Public API

Get ALB URL:

```bash
kubectl get ingress -n tradevault
```

Test root endpoint:

```bash
curl http://<ALB-DNS>/
```

Expected response:

```json
{"message":"Welcome to TradeVault API v3"}
```

Test health endpoint:

```bash
curl http://<ALB-DNS>/health
```

Expected response:

```json
{"status":"healthy"}
```

Test RDS connectivity:

```bash
curl http://<ALB-DNS>/db-check
```

Expected response:

```json
{"database":"connected","result":1}
```

---

## 11. Verify Terraform Drift

Run:

```bash
terraform -chdir=terraform/environments/dev plan
```

Expected result when infrastructure is healthy and unchanged:

```text
No changes. Your infrastructure matches the configuration.
```

---

## 12. GitOps Self-Healing Test

Manually scale the API deployment down:

```bash
kubectl scale deployment tradevault-api -n tradevault --replicas=1
```

Watch the deployment:

```bash
kubectl get deployment tradevault-api -n tradevault -w
```

Expected behavior:

```text
ArgoCD detects drift and restores the replica count back to the Git-defined value.
```

Exit watch mode:

```bash
Ctrl + C
```

---

## 13. Safe Destroy Order

To avoid orphaned AWS resources, destroy in this order.

### Step 1: Delete ArgoCD Application

```bash
kubectl delete application tradevault-eks -n argocd --ignore-not-found
```

This prevents ArgoCD from recreating Kubernetes resources during cleanup.

### Step 2: Delete ALB Ingress

```bash
kubectl delete ingress tradevault-api-alb -n tradevault --ignore-not-found
```

This allows AWS Load Balancer Controller to delete the AWS ALB before the EKS cluster is destroyed.

Verify Ingress is gone:

```bash
kubectl get ingress -n tradevault
```

Also verify in AWS Console:

```text
EC2 → Load Balancers
```

### Step 3: Destroy Terraform Dev Infrastructure

```bash
terraform -chdir=terraform/environments/dev destroy
```

Approve when prompted:

```bash
yes
```

This destroys the dev infrastructure.

Do not destroy bootstrap unless intentionally removing the Terraform backend.

---

## 14. Post-Destroy Verification

After destroy completes, verify that expensive resources are gone.

### EKS

```bash
aws eks list-clusters --region us-east-2
```

Direct check:

```bash
aws eks describe-cluster \
  --name tradevault-dev-eks \
  --region us-east-2
```

Expected:

```text
ResourceNotFoundException
```

### EC2 Worker Nodes

```bash
aws ec2 describe-instances \
  --region us-east-2 \
  --filters "Name=tag:eks:cluster-name,Values=tradevault-dev-eks" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table
```

Expected:

```text
No running instances.
```

Terminated instances may appear temporarily. That is okay.

### ALB

```bash
aws elbv2 describe-load-balancers \
  --region us-east-2 \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s') || contains(DNSName, 'tradevau')].[LoadBalancerName,DNSName,State.Code]" \
  --output table
```

Expected:

```text
No TradeVault ALB.
```

### Target Groups

```bash
aws elbv2 describe-target-groups \
  --region us-east-2 \
  --query "TargetGroups[?contains(TargetGroupName, 'k8s')].[TargetGroupName,TargetGroupArn]" \
  --output table
```

Expected:

```text
No TradeVault target groups.
```

### NAT Gateway

```bash
aws ec2 describe-nat-gateways \
  --region us-east-2 \
  --query "NatGateways[?State!='deleted'].{ID:NatGatewayId,State:State,VpcId:VpcId,SubnetId:SubnetId}" \
  --output table
```

Expected:

```text
No active TradeVault NAT Gateway.
```

### RDS

```bash
aws rds describe-db-instances \
  --db-instance-identifier tradevault-dev-postgres \
  --region us-east-2
```

Expected:

```text
DBInstanceNotFound
```

### ECR

```bash
aws ecr describe-repositories \
  --repository-names tradevault-dev-api \
  --region us-east-2
```

Expected:

```text
RepositoryNotFoundException
```

### VPC

```bash
aws ec2 describe-vpcs \
  --vpc-ids vpc-03e8cecdc1ef8d159 \
  --region us-east-2
```

Expected:

```text
InvalidVpcID.NotFound
```

### Elastic IPs

```bash
aws ec2 describe-addresses \
  --region us-east-2 \
  --query "Addresses[].{PublicIp:PublicIp,AllocationId:AllocationId,AssociationId:AssociationId,Tags:Tags}" \
  --output table
```

Expected:

```text
No unused TradeVault Elastic IPs.
```

### EBS Volumes

```bash
aws ec2 describe-volumes \
  --region us-east-2 \
  --filters "Name=status,Values=available" \
  --query "Volumes[].{ID:VolumeId,State:State,Size:Size,Type:VolumeType,Tags:Tags}" \
  --output table
```

Expected:

```text
No leftover available TradeVault EBS volumes.
```

### Secrets Manager

```bash
aws secretsmanager describe-secret \
  --secret-id tradevault/dev/rds \
  --region us-east-2
```

If no longer needed, delete it:

```bash
aws secretsmanager delete-secret \
  --secret-id tradevault/dev/rds \
  --force-delete-without-recovery \
  --region us-east-2
```

### Terraform Backend Resources

The S3 Terraform state bucket may remain:

```bash
aws s3 ls | grep tradevault
```

This is expected.

DynamoDB lock table may also remain if bootstrap created one:

```bash
aws dynamodb list-tables \
  --region us-east-2 \
  --output table
```

This is okay if intentionally kept.

---

## 15. Post-Destroy Terraform Check

After destroy, run:

```bash
terraform -chdir=terraform/environments/dev plan
```

Expected result:

```text
Plan: resources to add, 0 to change, 0 to destroy.
```

Do not apply unless you want to recreate the environment.

---

## 16. Common Issues

### ECR repository cannot be deleted

Error:

```text
RepositoryNotEmptyException
```

Fix:

Add this to the ECR Terraform resource:

```hcl
force_delete = true
```

Then run:

```bash
terraform -chdir=terraform/environments/dev apply
```

After that, run destroy again.

---

### ALB remains after destroy

Cause:

```text
Ingress was not deleted before EKS cluster was destroyed.
```

Fix:

Try to delete the ALB manually from AWS Console:

```text
EC2 → Load Balancers
```

Also check and delete leftover target groups:

```text
EC2 → Target Groups
```

---

### kubectl no longer works after destroy

This is normal because the EKS cluster has been deleted.

If recreating the cluster later, run:

```bash
aws eks update-kubeconfig \
  --region us-east-2 \
  --name tradevault-dev-eks
```

---

## 17. Current Cleanup Status

Last verified cleanup result:

- EKS cluster removed
- EKS EC2 worker nodes terminated
- ALB removed
- Target groups removed
- NAT Gateway deleted
- RDS removed
- ECR repository removed
- VPC removed
- Elastic IPs removed
- EBS volumes removed
- Secrets Manager dev RDS secret deleted
- Terraform state bucket kept
- GitHub repository kept
- Local proof screenshots kept

---

## 18. Next Improvements

Possible future improvements:

- Add HTTPS using ACM
- Add Route 53 custom domain
- Add Prometheus and Grafana on EKS
- Add CloudWatch or Loki-based logging
- Add image tag promotion instead of latest
- Add staging and production environments
- Add CI tests
- Add database migration workflow
- Add automated backup and restore process