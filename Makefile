# The following variables can be overridden.
# You can define them on a "user.env" file, to
# avoid giving them on each command line.

ifneq ($(wildcard user.env),)
$(info )
$(info Loading user variables file)
include user.env
endif

# Use containerized environment
DOCKER?=0

USER = $$(id -un)
UID = $$(id -u)
GID = $$(id -g)

DOCKER_IMAGE_NAME ?= build_virtual_payloads_image
DOCKER_TAG ?= latest
DOCKER_COMMAND := docker run -it --rm --volume="$${SSH_AUTH_SOCK}:/ssh-agent" --env="SSH_AUTH_SOCK=/ssh-agent" --volume="$(CURDIR):$(CURDIR)" --workdir="$(CURDIR)" --cap-add=NET_ADMIN --device=/dev/net/tun --network=host $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)
BUILDROOT_VERSION ?= 2023.11

MACHINE ?= network_player

CONFIG_NAME=mds_${MACHINE}_defconfig
CONFIG_FILE?=buildroot_config/${CONFIG_NAME}
OUTPUT_DIR?=../output/${MACHINE}
EXTERNAL_REPOSITORIES?=../../mds_external
BUILD_VERSION ?=  $(shell git describe --tags --dirty --always)

ifeq ($(DOCKER), 1)
	DEPS = docker-image
	PREFIX = $(DOCKER_COMMAND)
else
	DEPS =
	PREFIX =
endif

### DEFAULT TARGET ###

build: $(DEPS) br-downloads config ## Build target.
	@echo ">>> Build target [${MACHINE}]"
	$(PREFIX) make -C build/buildroot-${BUILDROOT_VERSION} BR2_EXTERNAL=$(EXTERNAL_REPOSITORIES) O=$(OUTPUT_DIR)
.PHONY: build

sdk: build ## Build target. 
	@echo ">>> Build SDK [${MACHINE}]"
	$(PREFIX) make -C build/buildroot-${BUILDROOT_VERSION} BR2_EXTERNAL=$(EXTERNAL_REPOSITORIES) O=$(OUTPUT_DIR) BR2_SDK_PREFIX=sdk-mds-${MACHINE}-${BUILD_VERSION} sdk
.PHONY: build

build-%: $(DEPS) br-downloads ## Build specific package
	@echo ">>> Build package [$*] for target [${MACHINE}]"
	$(PREFIX) make -C build/buildroot-${BUILDROOT_VERSION} BR2_EXTERNAL=$(EXTERNAL_REPOSITORIES) O=$(OUTPUT_DIR) $*
.PHONY: build-%

config: $(DEPS)
	$(PREFIX) cp $(CONFIG_FILE) build/buildroot-${BUILDROOT_VERSION}/configs
	$(PREFIX) make -C build/buildroot-${BUILDROOT_VERSION} O=$(OUTPUT_DIR) BR2_EXTERNAL=$(EXTERNAL_REPOSITORIES) $(CONFIG_NAME)
.PHONY: config

menuconfig: $(DEPS)
	$(PREFIX) cp $(CONFIG_FILE) build/buildroot-${BUILDROOT_VERSION}/configs
	$(PREFIX) make -C build/buildroot-${BUILDROOT_VERSION} O=$(OUTPUT_DIR) BR2_EXTERNAL=$(EXTERNAL_REPOSITORIES) $(CONFIG_NAME)
	$(PREFIX) make -C build/buildroot-${BUILDROOT_VERSION} O=$(OUTPUT_DIR) BR2_EXTERNAL=$(EXTERNAL_REPOSITORIES) menuconfig
	$(PREFIX) make -C build/buildroot-${BUILDROOT_VERSION} O=$(OUTPUT_DIR) BR2_EXTERNAL=$(EXTERNAL_REPOSITORIES) savedefconfig
	$(PREFIX) cp build/buildroot-${BUILDROOT_VERSION}/configs/$(CONFIG_NAME) $(CONFIG_FILE)
.PHONY: menuconfig

clean: ## Clean output repository. It will wipe out all the intermediary files generated by buildroot
	rm -rf "$(CURDIR)/build/output"
.PHONY: clean

###Distribution rules ###
DESTDIR?=./build/distribution/${MACHINE}

${DESTDIR}:
	mkdir -p ${DESTDIR}

distrib: ${DESTDIR} ## Copy the output binary of Agenium into a distribution directory. Destination directory can be overriden by setting DESTDIR variable . e.g DESTDIR=build/agenium make distrib-agenium
	mkdir -p ${DESTDIR}/image
	mkdir -p ${DESTDIR}/sdk
	cp build/output/${MACHINE}/images/rootfs.tar.xz ${DESTDIR}/image
	cp build/output/${MACHINE}/images/sdk-mds-${MACHINE}-${BUILD_VERSION}.tar.gz ${DESTDIR}/sdk

.PHONY: distrib

distrib-clean: ## Remove the distribution directory
	rm -rf ${DESTDIR}

### DOWNLOADS Buildroot ###

br-downloads: ## Download buildroot source code
	if [  ! -d build/buildroot-* ]; then \
		mkdir -p build ; \
		curl -s https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz | tar xvz -C build/ ; \
	fi
.PHONY: br-downloads

### DOCKER RULES ###

docker-image: Dockerfile ## Build Docker image
	@docker build \
		--ssh=default \
		--build-arg="USER=$(USER)" \
		--build-arg="UID=$(UID)" \
		--build-arg="GID=$(GID)" \
		--build-arg="PROJECT_PATH=$(CURDIR)" \
		--tag=$(DOCKER_IMAGE_NAME):$(DOCKER_TAG) \
		.
.PHONY: docker-image

docker-shell: docker-image ## Run shell in container
	@$(DOCKER_COMMAND) /bin/bash
.PHONY: docker-shell

docker-rm: ## Remove Docker image
	@docker image rm $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)
.PHONY: docker-rm

### Containers rules ###
container:
	cd evil &&  docker buildx build --platform linux/arm32v7 --tag software-package-evil:latest .
	skopeo copy --override-os linux --override-arch arm32v7  docker-daemon:software-package-evil:latest oci:software-package-evil:latest
	umoci raw unpack --rootless --image alpine build/software-package-evil
	cd build/software-package-evil && tar -Jcvf ../software-package-evil.tar.gz .

### SUPPORT RULES ###
help:           ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "\033[36m%-30s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
.PHONY: help

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT = 1
COMPOSE_DOCKER_CLI_BUILD = 1

.DEFAULT_GOAL := help
