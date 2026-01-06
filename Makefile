# Output directory for install target (can be overridden)
OUTPUT_DIR := /var/lib/portables

# Root filesystem build directory (can be overridden)
ROOTFS := $(CURDIR)/rootfs

# Version parsed from mix.exs (can be overridden)
VERSION := $(shell grep -A1 'defp version do' mix.exs | tail -1 | sed 's/[^0-9.]//g')

# Image filename
IMAGE := scouter-analytics_$(VERSION).raw

# Find all .service files in dist/systemd/
SYSTEMD_SERVICES := $(wildcard dist/systemd/usr/lib/systemd/system/*.service)
ROOTFS_SERVICES := $(patsubst dist/systemd/%,$(ROOTFS)/%,$(SYSTEMD_SERVICES))
ROOTFS_MOUNT_POINT_DIRS := $(ROOTFS)/proc $(ROOTFS)/sys $(ROOTFS)/dev $(ROOTFS)/run $(ROOTFS)/tmp $(ROOTFS)/var/tmp
ROOTFS_MOUNT_POINT_FILES := $(ROOTFS)/etc/resolve.conf $(ROOTFS)/etc/machine-id

# Aggregate all rootfs contents
ROOTFS_CONTENTS := $(ROOTFS)/usr/lib/os-release $(ROOTFS)/opt/scouter/analytics/ $(ROOTFS_SERVICES) $(ROOTFS_MOUNT_POINT_DIRS) $(ROOTFS_MOUNT_POINT_FILES)

# Default target: build the .raw image locally
$(IMAGE): $(ROOTFS_CONTENTS)
	mkfs.erofs $@ $(ROOTFS)/

# Install target: copy to OUTPUT_DIR (may require root)
.PHONY: install
install: $(IMAGE)
	@mkdir -p $(OUTPUT_DIR)
	cp $(IMAGE) $(OUTPUT_DIR)/$(IMAGE)

$(ROOTFS)/:
	mkdir -p $@

$(ROOTFS)/opt/scouter/analytics/: _build/prod/rel/analytics/
	rsync --mkpath -a _build/prod/rel/analytics/ $@

_build/prod/rel/analytics/:
	mix release \
		--overwrite \
		--force

$(ROOTFS)/usr/lib/os-release: | $(ROOTFS)/
	sudo dnf \
		--use-host-config \
		--installroot=$(ROOTFS)/ \
		--setopt=metadata_expire=never \
		--setopt=install_weak_deps=False \
		--setopt=tsflags=nodocs \
		--assumeyes \
		install \
			bash \
			coreutils-single \
			sed \
			grep \
			zlib \
			libstdc++ \
			openssl-libs \
			glibc-langpack-en

$(ROOTFS)/%.service: dist/systemd/%.service | $(ROOTFS)/
	@mkdir -p $(@D)
	cp $< $@

$(ROOTFS_MOUNT_POINT_DIRS): | $(ROOTFS)/
	mkdir -p $@

$(ROOTFS_MOUNT_POINT_FILES): | $(ROOTFS)/
	@mkdir -p $(@D)
	touch $@

