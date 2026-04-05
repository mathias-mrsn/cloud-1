
TERRAFORM_CODEDIR ?= terraform
TFVARS_FILE ?= $(TERRAFORM_CODEDIR)/main.auto.tfvars.json
WORKSPACE ?= main

TERRAFORM_COMMAND := terraform -chdir="$(TERRAFORM_CODEDIR)"

ifneq ($(realpath $(TFVARS_FILE)),)
	override TFVARS_FILE := $(realpath $(TFVARS_FILE))
endif

ifeq ("$(wildcard $(TFVARS_FILE))","")
$(error $(TFVARS_FILE) is missing)
endif

.PHONY: terraform-print-vars-file
terraform-print-vars-file:
	@echo $(TFVARS_FILE)

.PHONY: terraform-print-code-dir
terraform-print-code-dir:
	@echo $(TERRAFORM_CODEDIR)

.PHONY: terraform-version
terraform-version: ## Show terraform version
	@command -v terraform >/dev/null
	@terraform version

.PHONY: terraform-init
terraform-init: ## Initialize terraform in the code directory
	@${TERRAFORM_COMMAND} init -reconfigure -upgrade

.PHONY: terraform-plan
terraform-plan: ## Run terraform plan in the code directory
	@${TERRAFORM_COMMAND} plan -var-file="$(TFVARS_FILE)" -out=tfplan

.PHONY: terraform-apply
terraform-apply: ## Run terraform apply in the code directory
	@${TERRAFORM_COMMAND} apply -var-file="$(TFVARS_FILE)" -auto-approve tfplan

.PHONY: terraform-destroy
terraform-destroy: ## Run terraform destroy in the code directory
	@read -p "Are you sure you want to destroy the $(WORKSPACE) environment ? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		${TERRAFORM_COMMAND} destroy -var-file="$(TFVARS_FILE)" -auto-approve; \
	else \
		echo "Deployment cancelled"; \
		exit 1; \
	fi

.PHONY: terraform-console
terraform-console: ## Run terraform console in the code directory
	@${TERRAFORM_COMMAND} console -var-file="$(TFVARS_FILE)"

.PHONY: _output
_terraform_output: ## Retrieve terraform output values in JSON format. If OUTPUT_NAME is set, retrieves only that output, otherwise retrieves all outputs.
	OUTPUT=$$(${TERRAFORM_COMMAND} output -json 2>/dev/null); \
	if [ "$$OUTPUT" = "{}" ] || [ "$$OUTPUT" = "null" ] || [ -z "$$OUTPUT" ]; then \
		echo "Error: No Terraform outputs found. Please run 'make init' and 'make plan' first to initialize the project." >&2; \
		exit 1; \
	fi; \
	echo "$$OUTPUT"

.PHONY: terraform-output-json
terraform-output-json:  ## Retrieve terraform output values in JSON format.
	@$(MAKE) _terraform_output

.PHONY: terraform-output-json-pretty
terraform-output-json-pretty:  ## Retrieve terraform output values in pretty-printed JSON format.
	@$(MAKE) _terraform_output | jq .

.PHONY: terraform-output-env
terraform-output-env:  ## Retrieve terraform output values in shell variable format (key=value).
	@$(MAKE) _terraform_output | jq -r 'to_entries[] | "\(.key)=\(.value.value)"'

.PHONY: terraform-output-env-export
terraform-output-env-export: ## Retrieve terraform output values as shell export statements (export KEY=VALUE).
	@$(MAKE) _terraform_output | jq -r 'to_entries[] | "export \(.key)=\(.value.value)"'
	

AWS_REGION := $(shell jq -r '.aws_region // .region // empty' $(TFVARS_FILE) 2>/dev/null)
AWS_ACCOUNT_ID := $(shell jq -r '.aws_account_id // empty' $(TFVARS_FILE) 2>/dev/null)

ifneq ($(shell printf '%s' '$(AWS_ACCOUNT_ID)' | wc -m | tr -d '[:space:]'), 12)
$(error AWS_ACCOUNT_ID must be 12 characters. Got $(AWS_ACCOUNT_ID))
endif

.PHONY: aws-print-account-id
aws-print-account-id: ## Print the AWS Account ID
	@echo $(AWS_ACCOUNT_ID)

.PHONY: aws-print-region
aws-print-region: ## Print the AWS Region
	@echo $(AWS_REGION)
