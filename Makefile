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
	flyctl deploy
	@git tag -a --message $$(flyctl info -j |jq -r '.App | "fcuny.net/v\(.Version)"') $$(flyctl info -j |jq -r '.App | "fcuny.net/v\(.Version)"')
	@git push origin --all
	@git push origin --tags

docker-build:
	@echo "Building Docker image ..."
	$(DOCKER) build $(DOCKER_BUILD_ARGS) \
		--tag "${DOCKER_IMAGE}:${DOCKER_IMAGE_REF}" \
		--file "$(DOCKERFILE)" \
		"$(PROJECT_DIR)"

docker-run: docker-build
	@echo "Running Docker image ..."
	$(DOCKER) run -ti --rm -p 8080:8080 "${DOCKER_IMAGE}:${DOCKER_IMAGE_REF}"
