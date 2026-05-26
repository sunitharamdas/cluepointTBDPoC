# helloworld-demo-python – Kubernetes Deployment PoC

A minimal, reproducible path from development to production for the
[dockersamples/helloworld-demo-python](https://github.com/dockersamples/helloworld-demo-python)
app, following **Trunk-Based Development**.

---

## Table of Contents

1. [Repository layout](#1-repository-layout)
2. [SDLC choices](#2-sdlc-choices)
3. [Running locally](#3-running-locally)
4. [Infrastructure – Terraform](#4-infrastructure--terraform)
5. [CI/CD pipeline](#5-cicd-pipeline)
6. [Promoting dev → prod](#6-promoting-dev--prod)
7. [Rolling back](#7-rolling-back)
8. [Acceptance criteria](#8-acceptance-criteria)
9. [Required secrets & one-time setup](#9-required-secrets--one-time-setup)

---

## 1. Repository layout

```
.
├── app/
│   ├── app.py              # Python HTTP server (source of truth)
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .dockerignore
├── terraform/
│   ├── modules/
│   │   └── k8s-app/        # Reusable module: namespace, configmap,
│   │       ├── main.tf       deployment, service, ingress
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── environments/
│       ├── dev/            # Isolated state for dev
│       │   ├── main.tf
│       │   ├── backend.tf
│       │   ├── variables.tf
│       │   └── terraform.tfvars
│       └── prod/           # Isolated state for prod
│           ├── main.tf
│           ├── backend.tf
│           ├── variables.tf
│           └── terraform.tfvars
└── .github/
    └── workflows/
        ├── ci.yml           # Build, test, push image
        ├── deploy-dev.yml   # Auto-deploy to dev on CI success
        └── deploy-prod.yml  # Manual-approval deploy to prod
```

### Why separate environment directories instead of workspaces?

Terraform workspaces share a single backend configuration and module tree,
making it easy to accidentally target the wrong environment. Separate
directories give each environment its own:

- **state file** – a `terraform apply` in `dev/` physically cannot affect
  prod state;
- **backend block** – different S3 keys, which can be in different buckets or
  accounts if needed;
- **variable defaults** – `terraform.tfvars` carries environment-specific
  values checked into source control.

The trade-off is a small amount of duplication in `main.tf`, which is
acceptable because the shared logic lives in the `k8s-app` module.

---

## 2. SDLC choices

### Branching – Trunk-Based Development

| Practice | Detail |
|---|---|
| Single trunk | `main` is the only long-lived branch. All work merges here. |
| Feature branches | Short-lived (target < 1 day). Opened as a pull request; merged after 1 approval and a green CI run. |
| Feature flags | Incomplete features are merged behind a flag so `main` stays releasable at all times. |
| No release branches | Every commit that passes CI is a release candidate. |

### Versioning

Images are tagged with the **7-character git short-SHA** of the commit that
built them, e.g. `ghcr.io/org/helloworld-demo-python:abc1234`.

- Immutable: a tag always refers to the same image layer digest.
- Traceable: the tag directly links the running workload back to a specific
  commit in GitHub.
- No semantic versioning bump required for continuous deployment; semver tags
  can be added on top for external release announcements.

### Promotion policy

```
commit merged → main
      │
      ▼
   CI passes  ──────────────────────────────►  dev auto-deploys
      │
      │  (image validated in dev by a human or automated smoke test)
      │
      ▼
  operator triggers deploy-prod workflow
  and supplies the image tag
      │
      ▼
  GitHub Environment "production" pauses for ≥1 reviewer approval
      │
      ▼
  prod deploys
```

Policy rules:
- Only images that were built by CI and deployed to dev may be promoted.
- Prod deployments always require an explicit human approval via the GitHub
  Environment protection rule.
- The image tag (commit SHA) is the contract between environments – no
  rebuilding occurs during promotion.

---

## 3. Running locally

### Prerequisites

- Docker Desktop (or any Docker-compatible runtime)
- `kubectl` + access to a Kubernetes cluster (for manifest validation)
- Terraform ≥ 1.7 (for infrastructure commands)

### Build and run the container

```bash
# Build
docker build -t helloworld-demo:local ./app

# Run
docker run --rm -p 8080:8080 helloworld-demo:local

# Test
curl http://localhost:8080/
```

Expected output:

```
         ##         .
   ## ## ##        ==
## ## ## ## ##    ===
/"""""""""""""""""\___/ ===
{                       /  ===-
\______ O           __/
 \    \         __/
  \____\_______/


Hello from Docker!
```

### Validate Kubernetes manifests locally

Use `terraform plan` with a dry-run backend to catch syntax and schema errors
without touching any cluster:

```bash
cd terraform/environments/dev
terraform init -backend=false -reconfigure
terraform validate
terraform plan \
  -var="image=ghcr.io/org/helloworld-demo-python:abc1234" \
  -var="kube_context=<your-local-context>"
```

### Full local deployment with kind (no cloud account needed)

`kind` runs a real Kubernetes cluster inside Docker — useful for end-to-end
testing and demonstrating the stack without AWS.

#### Prerequisites

```bash
brew install kind kubectl
```

#### 1. Create a local cluster

```bash
kind create cluster --name demo
```

#### 2. Install the nginx ingress controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

#### 3. Build the image and load it into kind

GHCR images are built for `linux/amd64` (CI). On Apple Silicon the kind node
runs `linux/arm64`, so build locally and load directly — no registry pull needed.

```bash
docker build -t helloworld-demo:local ./app
kind load docker-image helloworld-demo:local --name demo
```

#### 4. Apply Terraform with a local state file (no S3 needed)

```bash
cd terraform/environments/dev

# Move the S3 backend config aside so Terraform falls back to local state
mv backend.tf backend.tf.bak

terraform init -reconfigure
terraform apply \
  -var="image=helloworld-demo:local" \
  -var="kube_context=kind-demo"
```

#### 5. Verify the deployment

```bash
kubectl get pods,svc,ingress -n helloworld-dev
```

Expected: pod status `Running`, service `helloworld`, ingress with host
`dev.helloworld.example.com`.

#### 6. Test the app

Ingress requires real DNS; use `port-forward` to bypass it locally:

```bash
kubectl port-forward svc/helloworld 9090:80 -n helloworld-dev &
curl http://localhost:9090/
```

Expected output:

```
         ##         .
   ## ## ##        ==
## ## ## ## ##    ===
/"""""""""""""""""\___/ ===
{                       /  ===-
\______ O           __/
 \    \         __/
  \____\_______/


Hello from Docker!
```

#### 7. Clean up

```bash
# Kill the port-forward
kill %1

# Restore the S3 backend config
mv backend.tf.bak backend.tf
rm -f terraform/environments/dev/terraform.tfstate \
       terraform/environments/dev/terraform.tfstate.backup

# Delete the kind cluster
kind delete cluster --name demo
```

---

## 4. Infrastructure – Terraform

### Architecture

Each environment deploys exactly what the app needs:

```
Namespace (helloworld-dev / helloworld-prod)
  └── ConfigMap          – non-secret runtime config (APP_ENV)
  └── Deployment         – rolling-update strategy, non-root security context,
  │                        liveness + readiness probes, resource limits
  └── Service (ClusterIP) – internal routing to pods on port 80 → 8080
       └── Ingress        – external exposure via nginx ingress controller
```

### Prerequisites (one-time, manual)

Create the S3 backend bucket. No DynamoDB table is needed — Terraform 1.10+
uses [native S3 state locking](https://developer.hashicorp.com/terraform/language/backend/s3#use_lockfile)
(`use_lockfile = true`), which writes a `.tflock` file to the same bucket.

```bash
# S3 bucket with versioning
aws s3 mb s3://my-tfstate-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket my-tfstate-bucket \
  --versioning-configuration Status=Enabled
```

Update `bucket` and `region` in `terraform/environments/*/backend.tf` to match
your AWS account.

### Apply dev

```bash
# Populate kubeconfig for the existing EKS cluster
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

cd terraform/environments/dev

terraform init
terraform plan  -var="image=ghcr.io/<org>/helloworld-demo-python:<tag>"
terraform apply -var="image=ghcr.io/<org>/helloworld-demo-python:<tag>"
```

### Apply prod

```bash
cd terraform/environments/prod

terraform init
terraform plan  -var="image=ghcr.io/<org>/helloworld-demo-python:<tag>"
terraform apply -var="image=ghcr.io/<org>/helloworld-demo-python:<tag>"
```

> **Note** – `image` is intentionally not stored in `terraform.tfvars`. Every
> apply must receive an explicit image tag so there is no ambiguity about what
> is deployed.

---

## 5. CI/CD pipeline

### Trigger overview

| Workflow | Trigger | Result |
|---|---|---|
| `ci.yml` | Push or PR to `main` | Lint → test → build → push image → validate Terraform |
| `deploy-dev.yml` | `ci.yml` completes successfully on `main` | Auto-deploy to dev |
| `deploy-prod.yml` | Manual `workflow_dispatch` | Human-gated deploy to prod |

### CI (`ci.yml`) – stages

```
lint               flake8 (Python) + terraform fmt -check
test               Unit tests – placeholder (add pytest)
security-scan      SAST – placeholder (add bandit / semgrep)
build-push         docker build → push to GHCR (main only)
image-scan         Container scan – placeholder (add Trivy / Grype)
tf-validate        terraform init -backend=false && terraform validate
                   (both dev and prod)
```

The image is tagged `ghcr.io/<org>/<repo>:<7-char-sha>` and `:latest`. The
tag is uploaded as a workflow artifact for the deploy-dev job to consume.

### Deploy Dev (`deploy-dev.yml`)

Runs automatically after a successful CI run on `main`. Uses AWS OIDC for
authentication (no long-lived credentials stored as secrets). Downloads the
image tag artifact from the CI run and calls `terraform apply`.

### Deploy Prod (`deploy-prod.yml`) – approval gate

1. Operator visits **Actions → Deploy to Prod → Run workflow** and pastes the
   image tag (e.g. `ghcr.io/org/repo:abc1234`).
2. GitHub pauses the run at the `production` environment gate.
3. A designated reviewer approves in the GitHub UI.
4. Terraform applies the change to the prod namespace.

Configure reviewers at **Settings → Environments → production → Required
reviewers**.

### Pipeline diagram

```
push to main
     │
     ▼
┌──────────────────────────────────────────────┐
│  CI  (ci.yml)                                │
│  lint → test → security-scan                 │
│              └─► build-push → image-scan     │
│  tf-validate (parallel)                      │
└──────────────┬───────────────────────────────┘
               │ workflow_run: completed
               ▼
┌──────────────────────────────────────────────┐
│  Deploy Dev  (deploy-dev.yml)                │
│  download artifact → tf apply (dev)          │
│  smoke test (placeholder)                    │
└──────────────────────────────────────────────┘

        [human decision: promote?]
               │ workflow_dispatch
               ▼
┌──────────────────────────────────────────────┐
│  Deploy Prod  (deploy-prod.yml)              │
│  ⏸  approval gate (production environment)  │
│  tf apply (prod)                             │
│  acceptance test (placeholder)               │
└──────────────────────────────────────────────┘
```

---

## 6. Promoting dev → prod

1. Verify dev is healthy:
   ```bash
   curl http://dev.helloworld.example.com/
   # expect: Hello from Docker!
   ```

2. Note the image tag from the CI run or the dev deployment logs, e.g.
   `ghcr.io/org/helloworld-demo-python:abc1234`.

3. Trigger the prod workflow:
   - GitHub UI: **Actions → Deploy to Prod → Run workflow**
   - Supply `image_tag`: `ghcr.io/org/helloworld-demo-python:abc1234`

4. Approve the deployment when prompted in the GitHub Environment gate.

5. Verify prod:
   ```bash
   curl http://helloworld.example.com/
   # expect: Hello from Docker!
   ```

---

## 7. Rolling back

### Option A – Pipeline rollback (preferred, auditable)

Re-trigger **Deploy to Prod** with an older image tag:

1. Find the last known-good image tag in the GitHub Actions run history.
2. Trigger **Actions → Deploy to Prod → Run workflow** with that tag.
3. Approve. Terraform will update the Deployment's image field, Kubernetes
   performs a rolling update back to the previous image.

### Option B – Emergency kubectl rollback (immediate, no pipeline)

If the pipeline is unavailable or the situation is critical:

```bash
# Show rollout history
kubectl rollout history deployment/helloworld -n helloworld-prod

# Roll back to the previous revision
kubectl rollout undo deployment/helloworld -n helloworld-prod

# Roll back to a specific revision
kubectl rollout undo deployment/helloworld -n helloworld-prod --to-revision=<N>

# Watch rollout progress
kubectl rollout status deployment/helloworld -n helloworld-prod
```

> **Important** – after a kubectl rollback, the Terraform state will be out of
> sync with the cluster. Follow up with a pipeline deployment of the correct
> image tag to reconcile state.

---

## 8. Acceptance criteria

### Dev – done when:

- `curl http://dev.helloworld.example.com/` returns **HTTP 200** with body:
  ```
           ##         .
     ## ## ##        ==
  ## ## ## ## ##    ===
  /"""""""""""""""""\___/ ===
  {                       /  ===-
  \______ O           __/
   \    \         __/
    \____\_______/


  Hello from Docker!
  ```
- `kubectl get pods -n helloworld-dev` shows at least 1 pod in `Running` state.
- `kubectl get ingress -n helloworld-dev` shows the correct host.

### Prod – done when:

- `curl http://helloworld.example.com/` returns **HTTP 200** with the same body.
- `kubectl get pods -n helloworld-prod` shows 2 pods in `Running` state.
- Deployment was triggered via the `deploy-prod.yml` workflow with an explicit
  approval recorded in the GitHub Actions audit log.
- Terraform state (`terraform show`) for prod reflects the deployed image tag.

---

## 9. Required secrets & one-time setup

### GitHub repository secrets

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | ARN of the IAM role to assume via OIDC, e.g. `arn:aws:iam::123456789012:role/github-actions-role` |
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `EKS_CLUSTER_NAME` | Name of the EKS cluster |

### IAM role trust policy (OIDC)

The role must trust `token.actions.githubusercontent.com` and allow the repo:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*"
    }
  }
}
```

Minimum permissions: `eks:DescribeCluster`, `s3:GetObject/PutObject/ListBucket`
on the state bucket, `dynamodb:GetItem/PutItem/DeleteItem` on the lock table.

### GitHub Environments

| Environment | Protection |
|---|---|
| `dev` | None – deploys automatically |
| `production` | Required reviewers: add at least one team member |