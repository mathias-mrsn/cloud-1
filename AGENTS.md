# AGENTS.md

This file guides coding agents working in `/Users/mathias.mrsn/42/cloud-1`.

## Scope

- Repository type: infrastructure-as-code project for a WordPress deployment on AWS.
- Primary language: Terraform.
- Secondary languages: YAML (`docker-compose.yaml`), Markdown (`README.md`).
- Main working directory for infrastructure commands: `terraform/`.

## Rule Sources

- Existing `AGENTS.md`: not present before this file was created.
- Cursor rules in `.cursor/rules/`: not present.
- `.cursorrules`: not present.
- Copilot instructions in `.github/copilot-instructions.md`: not present.
- Human-facing project guidance lives in `README.md`.

## Repository Layout

- `terraform/versions.tf`: Terraform and provider version constraints.
- `terraform/providers.tf`: AWS provider configuration and aliases.
- `terraform/variables.tf`: all user-facing inputs and validations.
- `terraform/data.tf`: data sources.
- `terraform/outputs.tf`: exported outputs.
- `terraform/*.tf`: infra components split by concern (`vpc`, `alb`, `autoscaling`, `aurora`, `efs`, `cloudfront`, etc.).
- `docker-compose.yaml`: wrapper for running Terraform inside the official container.
- `.env.template`: template for Docker Compose environment variables.

## High-Value Safety Notes

- Treat `terraform/main.auto.tfvars.json` as sensitive. It currently contains real-looking secrets and personal data.
- Do not print, copy, or commit secrets from `.env`, `.env.template`, or `terraform/main.auto.tfvars.json` without explicit user instruction.
- Prefer `terraform plan` before `terraform apply` when changing infrastructure.
- Be careful with destructive commands such as `terraform destroy` and `-replace`; only use them when the user clearly asks.

## Standard Commands

Run native Terraform commands from `terraform/`:

```sh
terraform init
terraform fmt
terraform fmt -check
terraform validate
terraform plan
terraform apply
terraform destroy
terraform output
```

Run the same commands through Docker Compose from the repo root:

```sh
docker-compose run --rm terraform init
docker-compose run --rm terraform fmt
docker-compose run --rm terraform fmt -check
docker-compose run --rm terraform validate
docker-compose run --rm terraform plan
docker-compose run --rm terraform apply -auto-approve
docker-compose run --rm terraform destroy -auto-approve
docker-compose run --rm terraform output
```

## Build / Lint / Test Reality

- There is no application build step in this repository.
- Pre-commit is configured with Terraform-focused hooks, generic file hygiene checks, Markdown TOC updates, and secret scanning.
- There is no automated test suite in the repository.
- The closest equivalents are:
  - formatting: `terraform fmt`
  - static validation: `terraform validate`
  - change preview: `terraform plan`
- Available local quality commands now include:
  - `pre-commit run --all-files`
  - `tflint --config=../.pre-commit-config/.tflint.hcl`
  - `checkov --config-file ../.pre-commit-config/.checkov.yaml -d .`

## Single-Test / Focused Execution Guidance

There is no single-test command because the repo has no tests.

For targeted verification, use the smallest Terraform command that matches the task:

```sh
terraform fmt terraform/alb.tf
terraform fmt terraform/autoscaling.tf
terraform plan -target=module.alb
terraform plan -target=module.autoscaling
terraform plan -target=module.vpc
terraform plan -target=aws_sns_topic.this
docker-compose run --rm terraform plan -target=module.alb
```

Notes:

- `terraform validate` works at the module level, not per file.
- `terraform fmt <file>` is the closest thing to a single-file check.
- `terraform plan -target=...` is useful for local debugging, but avoid relying on targeted apply as a normal workflow.

## Expected Workflow For Changes

1. Read `README.md` and the relevant `.tf` files for the feature area.
2. Edit the smallest set of files possible.
3. Run `terraform fmt` on touched files or the whole `terraform/` directory.
4. Run `terraform validate` from `terraform/`.
5. Run a focused `terraform plan` if the change is isolated; otherwise run a full plan.
6. Summarize any infra impact, especially new resources, replacements, or destructive changes.

## Terraform Style Guidelines

- Use 2-space indentation.
- Keep one concern per file when practical; this repo organizes files by AWS domain.
- Use lowercase snake_case for variable names, local names, output names, and most module labels.
- Preserve existing exceptions for resource names that already use hyphens, such as `asg-policy` and `email-target`.
- Keep arguments vertically aligned in the standard Terraform format that `terraform fmt` produces.
- Resource names exposed to AWS usually follow a prefixed pattern like `alb-${var.name}` or `asg-${var.name}`.
- Reuse `var.name` as the project-wide identifier for resource naming.
- Match filenames to the infra concern: `alb.tf`, `aurora.tf`, `efs.tf`, `vpc.tf`, etc.
- Prefer explicit `description`, `type`, and `default` fields on variables.
- Add `validation` blocks for user-facing constraints when the rule is important.
- Prefer `null` defaults for optional values instead of fake sentinel strings.
- Prefer locals for reusable derived values, such as domain-name fallbacks.
- Prefer module inputs over hand-built resources when the repo already uses a well-known community module.
- Keep provider selection explicit with `providers = { aws = aws.default }` or another alias when required.
- Keep tags consistent across resources and modules.
- Use descriptive module labels such as `alb`, `aurora`, `elasticache`, and `autoscaling_sg`.
- Avoid introducing abbreviations unless they already exist in AWS terminology or the repo.

## Terraform Data And Expressions

- Favor built-in functions already used in the repo: `coalesce`, `try`, `length`, `templatefile`, `jsonencode`, `base64encode`.
- Prefer conditional expressions for optional resources and values.
- Keep data sources minimal and clearly named.
- Use `depends_on` only when Terraform cannot infer the dependency graph.
- Prefer referencing module outputs directly over duplicating values.

## Error Handling And Validation

- Catch invalid user input early with variable validation blocks.
- Prefer plans that fail fast rather than hiding errors with overly defensive expressions.
- When using optional resources, ensure downstream references are protected with `try(...)`, conditionals, or matching counts.
- In agent responses, call out risky changes like instance replacement, data loss, downtime, or DNS impact.

## YAML And Markdown Guidelines

- Use 2-space indentation in `docker-compose.yaml`.
- Keep Docker Compose changes minimal and explicit.
- In `README.md`, follow the existing tutorial style: short sections, fenced `sh` blocks, and deployment-oriented wording.
- If you add commands, document both native Terraform and Docker Compose forms when both are supported.

## Good Agent Output

- Mention which files changed and why.
- Report the exact verification commands you ran.
- Say explicitly if validation or planning could not be run.
- Note any commands that require AWS credentials or live infrastructure access.
- Warn when a suggested command may incur cost or destroy resources.
