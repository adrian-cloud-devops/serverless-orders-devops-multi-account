[Back to README](../../README.md)  
[Next: Sprint-02 Terraform →](sprint-02-terraform-automation.md)

# Sprint 01 — Manual Setup and Architecture Validation

## Overview

The goal of Sprint 01 was to design and validate the core architecture without
Infrastructure as Code, using only the AWS Console.

Building manually first was a deliberate decision — it forces a deep understanding
of IAM trust relationships, STS behavior, and cross-account dependencies before
any automation is introduced. Problems that would be obscured by Terraform error
messages became immediately visible at this stage.

---

## Objectives

- provision the core infrastructure manually across two AWS accounts
- validate cross-account communication via STS AssumeRole
- confirm the architecture works end-to-end before introducing automation

---

## Infrastructure Components

| Resource | Account | Description |
|---|---|---|
| `OrdersTable` | B — Data | DynamoDB table storing order records |
| `DataAccessRole` | B — Data | IAM role granting Lambda access to DynamoDB |
| `create_order` | A — Application | Lambda function handling POST /orders |
| `get_order` | A — Application | Lambda function handling GET /orders/{id} |
| Lambda execution role | A — Application | IAM role allowing Lambda to call STS |
| HTTP API | A — Application | API Gateway with two routes |

---

## Account Structure
```
Account A — Application        Account B — Data
─────────────────────          ─────────────────
API Gateway                    DynamoDB (OrdersTable)
Lambda (create_order)          DataAccessRole
Lambda (get_order)
Lambda execution role
```

The DevOps account (Account C) is not used in this sprint — Terraform
is introduced in Sprint 02.

---

## DynamoDB Table (Account B)

The data layer is isolated in a dedicated account with no public access.

Configuration:

| Setting | Value |
|---|---|
| Table name | `OrdersTable` |
| Partition key | `orderId` (String) |
| Billing mode | On-Demand (PAY_PER_REQUEST) |

On-Demand billing was chosen to avoid capacity planning at this stage —
the table scales automatically and charges only for actual usage.

---

## DataAccessRole (Account B)

An IAM role was created to allow controlled access to DynamoDB from Account A.

The role grants only the minimum permissions required:

- `dynamodb:PutItem`
- `dynamodb:GetItem`
- `dynamodb:Query`

Access is scoped to the `OrdersTable` ARN — not the entire DynamoDB service.
This means even if the role were misused, it could not access any other table
in Account B.

The trust relationship allows only Account A to assume this role:
```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::<ACCOUNT_A_ID>:role/OrdersLambdaRole"
  },
  "Action": "sts:AssumeRole"
}
```

The trust policy references the specific Lambda execution role ARN rather than
the account root — only OrdersLambdaRole in Account A can assume this role.
No other principal in Account A has access to the data layer, even if they
have sts:AssumeRole permissions in their own policies.

---

## Lambda Functions (Account A)

Two Lambda functions were created — one per API operation.

### `create_order`

Handles `POST /orders` requests.

Flow:
1. receives order payload from API Gateway
2. assumes `DataAccessRole` in Account B via STS
3. writes the order item to DynamoDB using temporary credentials
4. returns the created order ID to the client

### `get_order`

Handles `GET /orders/{id}` requests.

Flow:
1. receives order ID from API Gateway path parameter
2. assumes `DataAccessRole` in Account B via STS
3. queries DynamoDB for the matching item
4. returns the order data to the client

Both functions use the same AssumeRole pattern — credentials are requested
fresh on each invocation and are never stored or reused between calls.

---

## Cross-Account Access Design

Lambda functions in Account A do not have direct access to DynamoDB.
Instead, they call STS to assume a role in Account B and receive temporary
credentials scoped to DynamoDB operations only.
```
Lambda (Account A)
        │
        │ sts:AssumeRole
        ▼
DataAccessRole (Account B)
        │
        ▼
DynamoDB — OrdersTable
```

This pattern provides three important guarantees:

- no static credentials are stored anywhere in the system
- credentials expire automatically — no rotation needed
- if Account A is compromised, the attacker still cannot access DynamoDB
  without going through the role boundary enforced by Account B

---

## API Gateway (Account A)

An HTTP API was configured with two routes:

| Method | Route | Lambda |
|---|---|---|
| POST | `/orders` | `create_order` |
| GET | `/orders/{id}` | `get_order` |

HTTP API (v2) was chosen over REST API (v1) for lower cost and lower latency.
The `$default` stage is used with auto-deploy enabled — suitable for a
single-environment setup at this stage.

---

## Request Flow

### POST /orders
```
Client
  │
  │ HTTP POST /orders
  ▼
API Gateway
  │
  │ Lambda invoke
  ▼
create_order (Account A)
  │
  │ sts:AssumeRole → DataAccessRole
  ▼
DynamoDB PutItem (Account B)
  │
  ▼
Response to client
```

### GET /orders/{id}
```
Client
  │
  │ HTTP GET /orders/{id}
  ▼
API Gateway
  │
  │ Lambda invoke
  ▼
get_order (Account A)
  │
  │ sts:AssumeRole → DataAccessRole
  ▼
DynamoDB GetItem (Account B)
  │
  ▼
Response to client
```

---

## Validation

The system was validated using direct API calls after manual setup.

### Create order
```bash
curl "https://<api-url>/orders/<orderId>" \
  -H "Content-Type: application/json" \
  -d '{"customerId": "test123", "totalAmount": 100}'
```

### Get order
```bash
curl "https://<api-url>/orders/<orderId>"
```

Validation confirmed:

- orders are created and stored in DynamoDB (Account B)
- orders can be retrieved via the API
- cross-account access via STS works correctly
- Lambda never holds long-lived credentials
- DynamoDB in Account B is not directly accessible from Account A

---

## Challenges and Solutions

### IAM trust relationship between accounts

Configuring the trust relationship on `DataAccessRole` correctly was the
most critical and error-prone step in this sprint.

The common mistake is assuming that granting `sts:AssumeRole` permission
to the Lambda execution role in Account A is sufficient. In reality, both
sides must explicitly allow the relationship:

- Account A — Lambda execution role must have `sts:AssumeRole` permission
  pointing to the `DataAccessRole` ARN in Account B
- Account B — `DataAccessRole` trust policy must explicitly allow Account A
  to assume it

Missing either side results in an `AccessDenied` error from STS that does
not clearly indicate which side of the trust is misconfigured.

---

### Scoping DynamoDB permissions correctly

Initial attempts used broad DynamoDB permissions (`dynamodb:*` on `*`)
to get the system working quickly, then narrowed them down.

The final policy scopes access to specific actions on the `OrdersTable` ARN
only — any other table in Account B remains inaccessible even with valid
temporary credentials.

---

### API Gateway and Lambda integration

Connecting API Gateway to Lambda required configuring both the integration
and the Lambda resource-based policy that allows API Gateway to invoke the
function.

## Key Takeaways

- Building manually before automating exposed IAM trust relationship behavior
  that would have been difficult to debug through Terraform error messages alone
- STS AssumeRole with scoped permissions is strictly better than static credentials —
  no secret rotation needed, no credential leakage risk
- Separating compute and data into different accounts means a compromised
  Lambda function cannot directly access DynamoDB without going through the
  role boundary
- The `DataAccessRole` trust policy is the single point of control for all
  cross-account data access — a small but critical piece of configuration
- HTTP API v2 is the correct choice for new serverless APIs — lower cost,
  lower latency, simpler configuration than REST API v1
- On-Demand DynamoDB billing removes capacity planning from the equation
  entirely at this stage — cost scales with actual usage

---

## Limitations at This Stage

- No Infrastructure as Code — environment is not reproducible
- Manual configuration is prone to drift
- No remote state or locking
- No CI/CD pipeline
- No observability or monitoring

---

## Next Steps

Sprint 02 replaces the manually created infrastructure with Terraform,
introducing multi-account provider configuration and centralized deployment
from Account C.

[⬆ Back to top](#sprint-01--manual-setup-and-architecture-validation)

---
[Back to README](../../README.md)  
[Next: Sprint-02 Terraform →](sprint-02-terraform-automation.md)