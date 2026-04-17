SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ifndef VERBOSE
MAKEFLAGS += --no-print-directory
endif

################################################################################
# Repository context
################################################################################

REPO_NAME := $(shell basename -s .git "$$(git config --get remote.origin.url 2>/dev/null || pwd)")
GIT_BRANCH ?= $(shell git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo local)
GIT_BRANCH_SHASUM := $(shell printf '%s' '$(GIT_BRANCH)' | shasum -a 256 | awk '{print substr($$1,1,8)}')

################################################################################
# Paths and shared configuration
################################################################################

TERRAFORM_CODEDIR ?= terraform
TFVARS_FILE ?= $(TERRAFORM_CODEDIR)/main.auto.tfvars.json
TFPLAN_FILE ?= tfplan
OUTPUTS_FILE ?= terraform_outputs.json
OUTPUT_NAME ?=

WRK_URL ?= https://mamaurai.fr/

include make/docker.mk
include make/terraform.mk

################################################################################
# Help and validation
################################################################################

.PHONY: help
help: ## Show this help message
	@echo "Available make targets:\n"
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | \
	 awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}' | \
	 sort

.PHONY: precommit
precommit: ## Run precommit check
	@pre-commit run -a

.PHONY: wrk-medium
wrk: ## Run wrk benchmark to test autoscaling
	@command -v wrk >/dev/null
	@wrk -t2 -c8 -d10m "$(WRK_URL)"

