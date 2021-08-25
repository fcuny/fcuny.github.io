DOCKER := DOCKER_BUILDKIT=1 docker
DOCKER_BUILD_ARGS :=
DOCKER_IMAGE := fcuny/fcuny.net
DOCKER_IMAGE_REF := $(shell git rev-parse HEAD)
DOCKERFILE := Dockerfile
PROJECT_DIR := $(realpath $(CURDIR))

.PHONY: server deploy docker-build docker-run worktree-clean

server:
	@echo "Running hugo server ..."
	hugo server

worktree-clean:
	git diff --exit-code
	git diff --staged --exit-code

deploy: worktree-clean docker-build
	@echo "Deploying to fly ..."
	flyctl deploy \
		--build-arg IMAGE_REF=$(DOCKER_IMAGE_REF)
	@sleep 5
	git tag --message $(shell flyctl info -j |jq '.App | "\(.Name)/v\(.Version)"') $(shell flyctl info -j |jq '.App | "\(.Name)/v\(.Version)"')

docker-build:
	@echo "Building Docker image ..."
	$(DOCKER) build $(DOCKER_BUILD_ARGS) \
		--tag "${DOCKER_IMAGE}:${DOCKER_IMAGE_REF}" \
	  --build-arg IMAGE_REF=$(DOCKER_IMAGE_REF) \
		--file "$(DOCKERFILE)" \
		"$(PROJECT_DIR)"

docker-run: docker-build
	@echo "Running Docker image ..."
	$(DOCKER) run -ti --rm -p 8080:8080 $(DOCKER_IMAGE)
