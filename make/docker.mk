COMPOSE_FILE ?= docker-compose.yaml
SERVICES ?= wordpress nginx phpmyadmin
DOCKER_PLATFORM ?= linux/amd64
BUILDX_BUILDER_NAME ?= default
BUILDX_BUILDER ?= $(BUILDX_BUILDER_NAME)
WORDPRESS_IMAGE_NAME ?= cloud1-wordpress:latest
NGINX_IMAGE_NAME ?= cloud1-nginx:latest
PHPMYADMIN_IMAGE_NAME ?= cloud1-phpmyadmin:latest

export DOCKER_PLATFORM
export BUILDX_BUILDER
export WORDPRESS_IMAGE_NAME
export NGINX_IMAGE_NAME
export PHPMYADMIN_IMAGE_NAME

DOCKER_COMPOSE_CMD := docker compose -f $(COMPOSE_FILE)

ifneq ($(filter docker-build,$(MAKECMDGOALS)),)
  ifeq ($(strip $(BUILDX_BUILDER_NAME)),)
    $(error BUILDX_BUILDER_NAME is not defined. Set BUILDX_BUILDER_NAME=<builder-name>)
  endif
  ifeq ($(shell docker buildx inspect "$(BUILDX_BUILDER_NAME)" >/dev/null 2>&1 && printf yes),)
    $(error Docker buildx builder '$(BUILDX_BUILDER_NAME)' does not exist. Create it first with 'docker buildx create --name $(BUILDX_BUILDER_NAME) --driver docker-container')
  endif
endif

.PHONY: docker-build
docker-build: ## Build docker compose services with an existing buildx builder
	@docker buildx use "$(BUILDX_BUILDER_NAME)" >/dev/null
	@docker buildx inspect "$(BUILDX_BUILDER_NAME)" --bootstrap >/dev/null
	@$(DOCKER_COMPOSE_CMD) build $(SERVICES)

.PHONY: docker-version
docker-version: ## Show docker and docker compose versions
	@command -v docker >/dev/null
	@docker --version
	@docker compose version
