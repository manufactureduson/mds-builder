
# Detect build architecture
BUILDARCH ?= $(shell uname -m)
ifeq ($(BUILDARCH),aarch64)
    BUILDARCH=arm64
endif
ifeq ($(BUILDARCH),x86_64)
    BUILDARCH=amd64
endif

ifneq ($(wildcard user.env),)
include user.env
endif

# Use containerized environment
DOCKER?=0


DOCKER_IMAGE_NAME ?= mds_builder_image
DOCKER_TAG ?= latest
DOCKER_COMMAND := docker run -it --rm \
		--volume="$(CURDIR):$(CURDIR)" \
		-v mds-builder-build:$(CURDIR)/build \
		--workdir="$(CURDIR)" \
		$(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

BUILDROOT_VERSION ?= 2024.02.2

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

linux-menuconfig: $(DPES)
	make build-linux-menuconfig
	make build-linux-savedefconfig
	$(PREFIX) cp build/output/network_player/build/linux-6.7.2/defconfig mds_external/board/mds_network_player/kernel_defconfig

uboot-menuconfig: $(DPES)
	make build-uboot-menuconfig
	make build-uboot-savedefconfig
	$(PREFIX) cp build/output/network_player/build/uboot-2024.04-rc1/defconfig mds_external/board/mds_network_player/u-boot_defconfig

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
	#@echo ">>> Download buildroot source code"
	#$(PREFIX) mkdir -p build
	#$(PREFIX) curl -s https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz | tar xvz -C build/
	
.PHONY: br-downloads

### bootstrap ###
bootstrap:
	sh ./bootstrap.sh

### DOCKER RULES ###

docker-image: Dockerfile ## Build Docker image
	@docker build \
		--ssh=default \
		--build-arg="USER_UID=$(shell id -u)" \
		--build-arg="USER_GID=$(shell id -g)" \
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
