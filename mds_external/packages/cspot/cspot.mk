
################################################################################
#
# cspot
#
################################################################################
CSPOT_VERSION = 92492bbcfc011cf1f780b51617d9d06f564c0258
CSPOT_SITE = https://github.com/feelfreelinux/cspot.git
CSPOT_SUBDIR = targets/cli
CSPOT_GIT_SUBMODULES = YES
CSPOT_SITE_METHOD = git
CSPOT_DEPENDENCIES = mbedtls avahi host-protobuf host-python3 host-python-protobuf

CSPOT_CONF_OPTS = -DUSE_ALSA=ON

# When we're on ARM, but we don't have ARM instructions (only
# Thumb-2), disable the usage of assembly as it is not Thumb-ready.
ifeq ($(BR2_arm)$(BR2_armeb):$(BR2_ARM_CPU_HAS_ARM),y:)
CSPOT_CONF_OPTS += --disable-asm
endif

$(eval $(cmake-package))