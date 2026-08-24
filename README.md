# AWS Kubernetes Lab

This project provisions a small Kubernetes cluster on AWS with Terraform and deploys an nginx application through an internet-facing Network Load Balancer (NLB).

## Architecture

- One VPC with a public subnet and internet gateway
- One Kubernetes control-plane EC2 instance
- Two Kubernetes worker EC2 instances
- Kubernetes installed with `kubeadm`
- Cilium installed as the cluster CNI
- nginx deployed as two Kubernetes replicas
- nginx exposed with a Kubernetes `NodePort` on `30080`
- AWS NLB listening on port `80` and forwarding to worker nodes on port `30080`
- Terraform state stored in an S3 bucket

Traffic follows this path:

```text
Client -> NLB:80 -> worker:30080 -> Kubernetes Service -> nginx pod:80
```

The control plane is used for cluster administration only. Application traffic is sent to the worker nodes.

## Repository Structure

```text
application/
  main.tf                         AWS infrastructure and NLB
  variables.tf                    Terraform input variables
  outputs.tf                      Instance and NLB outputs
  provider.tf                     AWS provider and S3 backend
  versions.tf                     Terraform and provider versions
  nginx-k8s/deployment.yaml       nginx Deployment and NodePort Service
  scripts/install_k8s_tools.sh    Build the Kubernetes tools AMI
  scripts/kubeadm.sh              Kubernetes node setup helper
  scripts/setup_cp.sh             Initialize the control plane and install Cilium
.github/
  workflows/main.yml              Run bootstrap, then deployment
  workflows/bootstrap.yml         Create state bucket and tools AMI
  workflows/deploy.yml            Provision infrastructure and deploy nginx
  workflows/destroy-resources.yaml Destroy Terraform resources
```

## Prerequisites

- An AWS account with permissions to create the resources in `application/main.tf`
- AWS credentials configured locally or stored as GitHub Actions secrets
- Terraform `>= 1.5.0`
- AWS provider `~> 5.0`
- AWS CLI, `kubectl`, and SSH tools for manual operation
- A globally unique S3 bucket name

The Terraform AMI lookup expects an AMI owned by the account with a name matching:

```text
k8s-tools-ubuntu-24-04-*
```

The bootstrap workflow creates this AMI when one is not already available.

## GitHub Actions Deployment

1. Configure these repository secrets:

   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. Open **Actions** in GitHub and run **AWS K8s Lab - Main Pipeline**.
3. Provide a globally unique S3 bucket name.
4. Optionally change the AWS region. The default is `us-east-1`.

The main workflow runs these stages:

1. Creates or verifies the versioned S3 state bucket.
2. Builds the Kubernetes tools AMI if necessary.
3. Provisions the VPC, EC2 instances, security groups, NLB, and target group.
4. Initializes the control plane and joins both workers.
5. Deploys nginx and verifies the NLB endpoint.

The nginx endpoint is available from the `nginx_load_balancer_dns_name` Terraform output after deployment.

## Local Terraform Usage

From the `application` directory:

```bash
terraform init \
  -backend-config="bucket=<bucket-name>" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform fmt -check -recursive
terraform validate
terraform plan \
  -var="region=us-east-1" \
  -var="bucket_name=<bucket-name>"
terraform apply \
  -var="region=us-east-1" \
  -var="bucket_name=<bucket-name>"
```

To view the public nginx endpoint:

```bash
terraform output -raw nginx_load_balancer_dns_name
```

## Security Groups

- The load balancer security group allows public TCP port `80`.
- The worker security group allows TCP port `30080` only from the load balancer security group.
- The control-plane security group does not allow application HTTP traffic.
- SSH is currently allowed from `0.0.0.0/0` for the lab. Restrict this rule to a trusted CIDR for real deployments.

## Cleanup

Run the **AWS K8s Lab - Destroy Application** workflow with the same bucket name and region, or run locally:

```bash
terraform destroy \
  -var="region=us-east-1" \
  -var="bucket_name=<bucket-name>"
```

The destroy workflow removes the Terraform-managed application infrastructure. The S3 state bucket and the Kubernetes tools AMI are managed by the bootstrap workflow and may require separate cleanup.
