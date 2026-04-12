---
name: tf
description: Terraform conventions, file organization, and best practices for this repo. Trigger whenever the user is writing, reviewing, or modifying Terraform code — including adding resources, refactoring modules, working with workspaces, IAM, SSM, data sources, or any .tf files.
---

# Terraform Skill

Project-specific Terraform conventions. Follow these whenever writing or reviewing `.tf` files.

## Repository Structure

```
terraform/aws/<workspace>/
modules/                      # Reusable Terraform modules (referenced via symlinks)
```

## File Organization

**Never create new files for a feature.** Split files by resource type/concern, placing new resources into existing files that match their type. This applies equally to workspaces and modules.

| File | Purpose |
|---|---|
| `provider.tf` | Provider config, backend block, required_providers |
| `variables.tf` | Input variables |
| `locals.tf` | Local values and computed data |
| `data.tf` | All data sources (`data.*`), including `archive_file`, `aws_iam_policy_document`, etc. |
| `iam.tf` | IAM roles, policies, attachments, and IAM-related module invocations |
| `cloudwatch.tf` | CloudWatch log groups, metric alarms, EventBridge rules/targets |
| `lambda.tf` | Lambda functions and lambda permissions |
| `ssm.tf` | SSM Parameter Store resources |
| `moved.tf` | `moved` and `import` blocks for resource refactoring and imports |
| `README.md` | Workspace description and dependency list |

Only create a new file when adding a resource type that doesn't fit any existing file (e.g., adding the first S3 bucket warrants `s3.tf`). When in doubt, read the existing files and follow the established pattern.

### `data.tf` Ordering

- Place metadata data sources (`aws_caller_identity`, `aws_region`, etc.) at the **top**
- Place `aws_iam_policy_document` blocks at the **bottom**, beneath all other data sources

## Workspace Isolation

**Resources that multiple workspaces reference must live in their own workspace.** Other workspaces look up shared resources via data sources. Deploying shared resources inside a consuming workspace creates tangled cross-workspace dependencies.

When deciding where a resource belongs, ask: "Will any other workspace need to reference this?" If yes, give it its own workspace (or add it to an existing shared workspace like `vpc`, `rds`, `iam`, or `s3`).

## Module Usage

Reusable modules live in the top-level `modules/` directory. Workspaces reference them via **symlinks** from a local `modules/` subdirectory:

```sh
cd aws/dynamodb/modules
ln -s ../../../modules/dynamodb
```

Reference modules in code as `./modules/<module_name>`. **Always create the symlink first** when adding a module reference to a workspace.

Modules have an `examples/` directory — keep it up to date when changing the module interface. Examples should be minimal but illustrative.

### Module Interface Design

Module interfaces should be **opinionated and minimal**. Don't add boolean flags for things that can be inferred from other variables:

```hcl
// Good: iam_role_name being non-empty implies creation
variable "iam_role_name" {
  description = "Name of the IAM role to create. Leave empty to skip."
  type        = string
  default     = ""
}

// Bad: redundant flag
variable "enable_iam_role" { ... }
variable "iam_role_name" { ... }
```

## Conventions

### Provider Configuration

```hcl
terraform {
  backend "s3" {
    bucket               = "sean-terraform"
    region               = "us-east-1"
    workspace_key_prefix = "aws/lot-rat"
    key                  = "terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project   = "lot-rat"
      workspace = terraform.workspace
    }
  }
}
```

Set `region` directly rather than using region-specific aliases.

### Tfvars

Tfvars files follow the naming convention `var.<tier>.tfvars` (e.g., `var.staging.tfvars`, `var.production.tfvars`). They are gitignored and used exclusively for secrets — do not commit them or place non-secret configuration in them.

### Naming

- snake_case for all identifiers (enforced by tflint `terraform_naming_convention` rule)
- Use `"this"` when a module creates a single instance of a resource; use descriptive names for multiple instances
- In workspaces, use descriptive names (e.g., `aws_iam_role.identity_center`)
- Don't rename existing resources needlessly — only if a `moved` block can handle it without disruption

### Ordering

Alphabetize where order doesn't affect behavior (case-insensitive), but only when the list spans multiple lines:

- Data source blocks within a file
- Items in multi-line lists or objects (by `name` or primary key)

### Data-Driven Resources with `for_each`

Define **lists of objects** in `locals.tf` and iterate with `for_each`. Convert to a map using a `for` expression keyed by a unique field. Use `lookup()` for optional fields and `merge()` for shared fields:

```hcl
// locals.tf
locals {
  instances_list = [
    {
      name          = "my-instance"
      instance_type = "g6.8xlarge"
      iops          = 5000
    },
    {
      name          = "my-other-instance"
      instance_type = "m7a.8xlarge"
    },
  ]
}

// ec2.tf
resource "aws_instance" "this" {
  for_each = { for instance in local.instances_list : instance.name => instance }

  instance_type = each.value.instance_type

  root_block_device {
    iops = lookup(each.value, "iops", 10000)
  }
}
```

Prefer lists of objects over maps — easier to extend and review in diffs.

### Dynamic Blocks

Use `dynamic` blocks with a conditional list to conditionally render nested blocks:

```hcl
dynamic "statement" {
  for_each = length(var.iam_principals.read) > 0 ? [true] : []

  content {
    sid       = "ReadBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
    principals {
      type        = "AWS"
      identifiers = var.iam_principals.read
    }
  }
}
```

### SSM Parameters Managed Outside Terraform

For values managed via ClickOps or external processes, use `value_wo` / `value_wo_version`:

```hcl
resource "aws_ssm_parameter" "discord" {
  name             = "/${local.name}/discord"
  type             = "SecureString"
  value_wo_version = 1
  value_wo = jsonencode({
    channel_id = var.discord_channel_id
    public_key = var.discord_public_key
    bot_token  = var.discord_bot_token
  })
}
```

### Meta-Argument Spacing

Place a blank line between meta-arguments (`count`, `for_each`, `depends_on`, `provider`, `lifecycle`) and the resource's own attributes:

```hcl
// Good
data "aws_lb" "public" {
  count = local.has_domain ? 1 : 0

  name = "${local.name}-public"
}

// Bad
data "aws_lb" "public" {
  count = local.has_domain ? 1 : 0
  name  = "${local.name}-public"
}
```

### Variables and Outputs

- Include `description` on all variables and outputs (enforced by tflint)
- Use `validation` blocks where necessary
- Use `optional()` in object types for flexible configurations

## Pre-PR Checklist

Before creating a pull request that includes Terraform changes, run `terraform fmt -recursive` from the repository root to format all workspaces.
