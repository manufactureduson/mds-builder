
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
CONTAINER?=0
CONTAINER_ENGINE ?= docker

CONTAINER_IMAGE_NAME ?= mds_builder_image
CONTAINER_TAG ?= latest
CONTAINER_COMMAND := ${CONTAINER_ENGINE} run -it --rm \
		--volume="$(CURDIR):$(CURDIR)" \
		-v mds-builder-build:$(CURDIR)/build \
		--workdir="$(CURDIR)" \
		$(CONTAINER_IMAGE_NAME):$(CONTAINER_TAG)

BUILDROOT_VERSION ?= 2024.08

MACHINE ?= network_player

CONFIG_NAME=mds_${MACHINE}_defconfig
CONFIG_FILE?=buildroot_config/${CONFIG_NAME}
OUTPUT_DIR?=../output/${MACHINE}
EXTERNAL_REPOSITORIES?=../../mds_external
BUILD_VERSION ?=  $(shell git describe --tags --dirty --always)

ifeq ($(CONTAINER), 1)
	DEPS = container-image
	PREFIX = $(CONTAINER_COMMAND)
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

### DOWNLOAD Buildroot ###
build/.stamp-br-downloads:
	@echo ">>> Download buildroot source code"
	$(PREFIX) mkdir -p build
	git clone https://gitlab.com/buildroot.org/buildroot.git build/buildroot-${BUILDROOT_VERSION}
	git -C build/buildroot-${BUILDROOT_VERSION} checkout ${BUILDROOT_VERSION}
	### $(PREFIX) curl -s https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz | tar xz -C build/
	touch build/.stamp-br-downloads

br-downloads: build/.stamp-br-downloads ## Download buildroot source code
.PHONY: br-downloads

### bootstrap ###
bootstrap:
	sh ./bootstrap.sh

### CONTAINER RULES ###

container-image: Dockerfile ## Build Docker image
	@${CONTAINER_ENGINE} build \
		--ssh=default \
		--build-arg="USER_UID=$(shell id -u)" \
		--build-arg="USER_GID=$(shell id -g)" \
		--build-arg="PROJECT_PATH=$(CURDIR)" \
		--tag=$(CONTAINER_IMAGE_NAME):$(CONTAINER_TAG) \
		.
.PHONY: container-image

containter-shell: container-image ## Run shell in container
	@$(CONTAINER_COMMAND) /bin/bash
.PHONY: container-shell

container-rm: ## Remove Docker image
	@${CONTAINER_ENGINE} image rm $(CONTAINER_IMAGE_NAME):$(CONTAINER_TAG)
.PHONY: container-rm

### SUPPORT RULES ###
help:           ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "\033[36m%-30s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
.PHONY: help

.EXPORT_ALL_VARIABLES:
CONTAINER_BUILDKIT = 1
COMPOSE_CONTAINER_CLI_BUILD = 1

.DEFAULT_GOAL := help
