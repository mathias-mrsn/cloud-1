COMPOSE_FILE ?= docker-compose.yaml
SERVICES ?= wordpress phpmyadmin
DOCKER_PLATFORM ?= linux/arm64/v8
BUILDX_BUILDER_NAME ?= default
BUILDX_BUILDER ?= $(BUILDX_BUILDER_NAME)
WORDPRESS_APACHE_IMAGE_NAME ?= cloud1-wordpress-apache:latest
PHPMYADMIN_IMAGE_NAME ?= cloud1-phpmyadmin:latest
ENABLE_LOCAL_STACK ?= false
LOCAL_STACK_SERVICES ?= db wordpress phpmyadmin

export DOCKER_PLATFORM
export BUILDX_BUILDER
export WORDPRESS_APACHE_IMAGE_NAME
export PHPMYADMIN_IMAGE_NAME
export ENABLE_LOCAL_STACK

DOCKER_COMPOSE_CMD := docker compose -f $(COMPOSE_FILE)

ifneq ($(filter docker-build,$(MAKECMDGOALS)),)
  ifeq ($(strip $(BUILDX_BUILDER_NAME)),)
    $(error BUILDX_BUILDER_NAME is not defined. Set BUILDX_BUILDER_NAME=<builder-name>)
  endif
  ifeq ($(shell docker buildx inspect "$(BUILDX_BUILDER_NAME)" >/dev/null 2>&1 && printf yes),)
    $(error Docker buildx builder '$(BUILDX_BUILDER_NAME)' does not exist. Create it first with 'docker buildx create --name $(BUILDX_BUILDER_NAME) --driver docker-container')
  endif
endif

ifeq ($(strip $(ENABLE_LOCAL_STACK)),true)
	SERVICES = $(LOCAL_STACK_SERVICES)
endif
.PHONY: docker-build
docker-build: ## Build docker compose services with an existing buildx builder
	@docker buildx use "$(BUILDX_BUILDER_NAME)" >/dev/null
	@docker buildx inspect "$(BUILDX_BUILDER_NAME)" --bootstrap >/dev/null
	@$(DOCKER_COMPOSE_CMD) build $(SERVICES)

.PHONY: docker-up
docker-up: ## Start the local Docker stack (requires ENABLE_LOCAL_STACK=true)
	$(MAKE) docker-build
	@if [ "$(ENABLE_LOCAL_STACK)" != "true" ]; then \
		echo "docker-up requires ENABLE_LOCAL_STACK=true" >&2; \
		exit 1; \
	fi
	@$(DOCKER_COMPOSE_CMD) up -d $(SERVICES)

.PHONY: docker-down
docker-down: ## Stop the local Docker stack (requires ENABLE_LOCAL_STACK=true)
	@if [ "$(ENABLE_LOCAL_STACK)" != "true" ]; then \
		echo "docker-down requires ENABLE_LOCAL_STACK=true" >&2; \
		exit 1; \
	fi
	@$(DOCKER_COMPOSE_CMD) down

.PHONY: docker-version
docker-version: ## Show docker and docker compose versions
	@command -v docker >/dev/null
	@docker --version
	@docker compose version
