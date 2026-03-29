[← Previous: Sprint-02 Terraform](sprint-02-sprint-02-terraform-automation.md)
[Back to README](../../README.md)
[Next: Sprint-04 CI/CD →](sprint-04-cicd.md)

# Sprint 03 — Remote State, State Locking and Modular Refactor

## Overview

The goal of Sprint 03 was to evolve the Terraform setup from a local, monolithic
configuration into a production-oriented Infrastructure as Code workflow.

The runtime architecture remains unchanged — what this sprint addresses is the
Terraform control plane: how state is stored, how concurrent operations are
prevented, and how the codebase is structured for long-term maintainability.

---

## Objectives

- move Terraform state from local filesystem to S3
- introduce state locking via DynamoDB
- refactor the flat configuration into reusable modules
- migrate existing state safely to avoid resource recreation

---

## Infrastructure Components

| Resource | Account | Description |
|---|---|---|
| S3 bucket | C — DevOps | Remote Terraform state storage |
| DynamoDB table | C — DevOps | State locking mechanism |
| Bootstrap configuration | C — DevOps | One-time setup for backend resources |

The application runtime resources (Lambda, API Gateway, DynamoDB) are unchanged.

---
## Cross-Account Access

Terraform is executed from **Account C (DevOps account)**.

To manage infrastructure in **Account A (application)** and **Account B (data)**,
Terraform uses IAM roles and **STS AssumeRole**.

This enables:

- centralized infrastructure management
- clear separation between runtime and deployment accounts
- improved security boundaries between environments 

## Why This Refactor Was Necessary

The Terraform setup from Sprint 02 had several limitations that would become
critical problems in any real-world environment:

- state stored locally — not reproducible across machines, risk of state loss
- no locking — concurrent `terraform apply` runs could corrupt state
- monolithic configuration — no separation of concerns, difficult to extend
- no safe path for future CI/CD — pipelines require remote state and locking

Addressing these before introducing CI/CD in Sprint 04 was a deliberate decision.
Automating a broken foundation creates pipeline instability and technical debt
that is much harder to fix later.

---

## Remote State

Terraform state is the single source of truth for all managed infrastructure.
Keeping it locally introduces risk of loss, inconsistent deployments, and
no support for collaboration or automation.

State was moved to an S3 backend stored in Account C.

| Setting | Value |
|---|---|
| Storage | S3 bucket (Account C) |
| Encryption | Enabled |
| State locking | DynamoDB table |
| Region | `eu-central-1` |

---

## State Locking

Without locking, two concurrent Terraform operations can read the same state,
make conflicting changes, and write back corrupted state.

DynamoDB locking ensures only one operation modifies state at a time.
If a second operation is attempted while a lock is held, Terraform refuses
to proceed and displays the lock ID.

---

## Backend Bootstrap

Terraform cannot create the S3 bucket and DynamoDB table it uses as a backend.
A separate `bootstrap/` configuration was created to provision these resources
as a one-time setup step applied before the main configuration is initialized.

---

## Modular Structure

The flat configuration was reorganized into five modules:
```text
terraform/
│
├── modules/
│   ├── lambda/           # Lambda functions and packaging
│   ├── api_gateway/      # HTTP API, routes, integrations, stage
│   ├── dynamodb/         # DynamoDB table
│   ├── iam_api_role/     # Lambda execution role and STS permissions
│   └── iam_data_role/    # Cross-account DataAccessRole
│
├── main.tf               # Module composition and provider wiring
├── providers.tf          # Multi-account provider configuration
├── variables.tf
└── outputs.tf
```

The root module is responsible for provider configuration, passing variables,
and connecting modules together. Business logic lives in the modules.

---

## State Migration

After introducing modules, Terraform resource addresses changed — for example:
```
Before:  aws_lambda_function.create_order
After:   module.lambda.aws_lambda_function.create_order
```

Without migration, Terraform would destroy existing resources and recreate
them under the new addresses — causing downtime and permission inconsistencies
across API Gateway, Lambda, and IAM.

`terraform state mv` was used to remap addresses in the state file without
touching any actual AWS resources.

The final Terraform plan after migration:
```
0 to add, 2 to change, 0 to destroy
```

Zero resources recreated — zero downtime refactor.

---

## Challenges and Solutions

### State vs configuration mismatch

After modularization, Terraform detected all resources as new and planned
to destroy and recreate everything.

**Fix:** aligned module resource names with existing state addresses and
used `terraform state mv` to remap each resource.

---

### IAM resource replacement

Changing IAM role and policy names caused Terraform to plan forced replacements,
which would break Lambda execution permissions.

**Fix:** preserved original resource names across the refactor to maintain
continuity and avoid permission disruption.

---

### API Gateway resource mapping

Renaming route and stage resources caused Terraform to treat them as new
resources requiring recreation.

**Fix:** matched module resource names exactly to existing state to prevent
unnecessary replacement.

---

## Validation

### Terraform plan

Final plan after state migration confirmed no resource recreation:
```
0 to add, 2 to change, 0 to destroy
```

### Backend

- state file visible in S3 bucket
- lock entries created and released correctly in DynamoDB during `terraform apply`

### Functional

API tested after refactor — both endpoints respond correctly:
```bash
curl -X POST "https://<api-url>/orders" \
  -H "Content-Type: application/json" \
  -d '{"customerId": "test123", "totalAmount": 100}'

curl "https://<api-url>/orders/<orderId>"
```

---

## Key Takeaways

- Remote state is not optional in any real-world Terraform workflow — local
  state is a liability from the moment a second person or pipeline touches
  the infrastructure
- State locking is the difference between a safe and unsafe `terraform apply`
  in any automated or collaborative environment
- Refactoring before CI/CD was the right order — automating a monolithic,
  locally-stateful configuration creates problems that compound over time
- `terraform state mv` is the correct tool for any structural refactor —
  without it, Terraform has no way to know that a renamed resource is the
  same physical infrastructure
- Preserving resource names during modularization is a practical constraint,
  not just a cosmetic choice — name changes trigger replacements in IAM and
  API Gateway that can break running systems

---

## Limitations at This Stage

- No CI/CD pipeline — deployment is still manual from Account C
- No observability or monitoring
- IAM policies still use broad permissions — least-privilege refinement
  is tracked for a later sprint

---

## Next Steps

Sprint 04 introduces a CI/CD pipeline using GitHub Actions, enabling
automated Terraform deployments triggered by pull requests and merges.

[⬆ Back to top](#sprint-03--remote-state-state-locking-and-modular-refactor)

---
[← Previous: Sprint-02 Terraform](sprint-02-terraform-automation.md)
[Back to README](../../README.md)
[Next: Sprint-04 CI/CD →](sprint-04-cicd.md)