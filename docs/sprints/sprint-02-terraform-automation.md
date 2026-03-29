[← Previous: Sprint-01 Manual Setup](sprint-01-manual-setup.md)
[Back to README](../../README.md)
[Next: Sprint-03 Remote State →](sprint-03-remote-state.md)

# Sprint 02 — Terraform Automation and Multi-Account Deployment

## Overview

The goal of Sprint 02 was to replace the manually created infrastructure
with a fully reproducible Terraform implementation.

The key challenge at this stage was configuring Terraform to deploy across
multiple AWS accounts from a single execution environment — Account C —
without sharing credentials directly between accounts.

---

## Objectives

- re-implement all Sprint 01 infrastructure using Terraform
- configure multi-account provider setup using AssumeRole
- deploy from Account C into Accounts A and B
- resolve real-world IAM and provider configuration issues encountered during automation

---

## Infrastructure Components

| Resource | Account | Managed by | Description |
|---|---|---|---|
| `OrdersTable` | B — Data | Terraform | DynamoDB table |
| `DataAccessRole` | B — Data | Terraform | Cross-account access role for Lambda |
| `TerraformDeployRole` | A and B | Manual | Deployment role trusted by Account C |
| Lambda execution role | A — Application | Terraform | Allows Lambda to call STS |
| `create_order` | A — Application | Terraform | Lambda function |
| `get_order` | A — Application | Terraform | Lambda function |
| HTTP API | A — Application | Terraform | API Gateway with two routes |

`TerraformDeployRole` was created manually in both target accounts before
running Terraform for the first time — Terraform cannot bootstrap the role
it uses to authenticate itself.

---

## Project Structure

At this stage the configuration is a single flat workspace — modularization
is introduced in Sprint 03.
```text
terraform/
│
├── main.tf          # All resources — Account A and B
├── providers.tf     # Multi-account provider configuration
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

All resources across both accounts live in `main.tf` at this stage.
Each resource explicitly references the correct provider alias to ensure
it is deployed into the right account.

---

## Multi-Account Provider Configuration

Terraform is executed from Account C using a local AWS CLI profile.
Two provider aliases are configured — one per target account — each
assuming the appropriate deployment role.
```hcl
provider "aws" {
  alias   = "api"
  region  = var.aws_region
  profile = "tools-local"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_a_id}:role/${var.deploy_role_name}"
  }
}

provider "aws" {
  alias   = "data"
  region  = var.aws_region
  profile = "tools-local"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_b_id}:role/${var.deploy_role_name}"
  }
}
```

This setup means:

- Terraform authenticates once using Account C credentials
- all resources in Account A use the `api` provider alias
- all resources in Account B use the `data` provider alias
- no credentials are passed between accounts directly

Every resource block must explicitly declare which provider it uses:
```hcl
resource "aws_dynamodb_table" "orders" {
  provider = aws.data
  ...
}

resource "aws_lambda_function" "create_order" {
  provider = aws.api
  ...
}
```

Omitting the `provider` argument causes Terraform to use the default provider —
which in a multi-account setup means the resource ends up in the wrong account
with no obvious error message.

---

## Deployment Flow
```
Account C (DevOps)
        │
        │ tools-local profile
        ▼
Terraform
        │
        ├── AssumeRole → TerraformDeployRole (Account A)
        │       └── deploys API Gateway, Lambda, IAM
        │
        └── AssumeRole → TerraformDeployRole (Account B)
                └── deploys DynamoDB, DataAccessRole
```

---

## Challenges and Solutions

This sprint surfaced several real-world IAM and Terraform configuration
problems that are worth documenting.

### Wrong AWS profile used

Terraform defaulted to the system AWS profile instead of the DevOps account profile.

**Fix:** explicitly set `profile = "tools-local"` in both provider blocks.

---

### AssumeRole authorization errors

Terraform could not assume roles in target accounts.

**Fix:** added `sts:AssumeRole` permission to the DevOps account user,
and updated trust relationships in `TerraformDeployRole` in both target accounts.

---

### Insufficient role permissions

`TerraformDeployRole` could not create all required resources.

**Fix:** attached `AdministratorAccess` as a temporary measure for the
development phase. This will be replaced with least-privilege policies in a later sprint.

---

### Resource already exists

Terraform attempted to create the DynamoDB table that was provisioned
manually in Sprint 01.

**Fix:** imported the existing resource into Terraform state using
`terraform import` to avoid recreation.

---

### Reserved Lambda environment variable

Lambda deployment failed because `AWS_REGION` is a reserved environment variable.

**Fix:** removed the variable and relied on the AWS Lambda runtime to
provide region information automatically.

---

### API Gateway endpoint format

Requests were failing because the URL included `/$default` in the path.

**Fix:** used the correct HTTP API base URL without the stage path segment.

---

### Wrong account deployment due to missing provider alias

A resource was accidentally deployed into the wrong account because the
`provider` argument was omitted from the resource block.

**Fix:** explicitly declared `provider = aws.api` or `provider = aws.data`
on every resource — never relying on the default provider in a multi-account
configuration.

---

## Validation

After Terraform deployment, the API was validated using the same
curl commands as Sprint 01.

Validation confirmed:

- all infrastructure deployed successfully via Terraform
- API endpoints respond correctly
- cross-account STS access works as expected
- DynamoDB data persists correctly across requests

---

## Key Takeaways

- Multi-provider Terraform configuration with `alias` is the standard pattern
  for managing resources across multiple AWS accounts in a single workspace
- Every resource in a multi-account workspace must explicitly declare its
  provider — omitting it silently deploys to the wrong account
- `TerraformDeployRole` must be created manually before Terraform runs —
  Terraform cannot reliably bootstrap the role it depends on for authentication
  without introducing a circular dependency, so the role was created manually.
- AssumeRole for deployment is strictly better than sharing credentials —
  Account C is the single entry point and all access is auditable
- Importing manually created resources into Terraform state avoids
  destructive recreation during the IaC migration
- Real IAM problems only surface during actual deployment — the manual
  sprint made them easier to isolate and fix
- Starting with broad permissions and narrowing them down is a pragmatic
  approach during initial automation, as long as it is tracked and addressed

---

## Limitations at This Stage

- Terraform state is stored locally — not reproducible across machines
- No modular structure — single flat configuration
- No CI/CD pipeline — deployment is manual
- No observability or monitoring

---

## Next Steps

Sprint 03 introduces remote state management with S3 and DynamoDB locking,
and refactors the flat configuration into reusable modules.

[⬆ Back to top](#sprint-02--terraform-automation-and-multi-account-deployment)

---
[← Previous: Sprint-01 Manual Setup](sprint-01-manual-setup.md)
[Back to README](../../README.md)
[Next: Sprint-03 Remote State →](sprint-03-remote-state.md)