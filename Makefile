# Output directory for install target (can be overridden)
INSTALL_DIR := /var/lib/portables/scouter-analytics.raw.v

# Root filesystem build directory (can be overridden)
ROOTFS := $(CURDIR)/rootfs

# Version parsed from mix.exs (can be overridden)
VERSION := $(shell grep -A1 'defp version do' mix.exs | tail -1 | sed 's/[^0-9.]//g')

RELEASE := 1

IMAGE_DIR := .

# Image filename
IMAGE := scouter-analytics_$(VERSION)-$(RELEASE).raw

# Find all .service files in dist/systemd/
SYSTEMD_SERVICES := $(wildcard dist/systemd/usr/lib/systemd/system/*.service)
ROOTFS_SERVICES := $(patsubst dist/systemd/%,$(ROOTFS)/%,$(SYSTEMD_SERVICES))
ROOTFS_MOUNT_POINT_DIRS := $(ROOTFS)/proc/ $(ROOTFS)/sys/ $(ROOTFS)/dev/ $(ROOTFS)/run/ $(ROOTFS)/tmp/ $(ROOTFS)/var/tmp/ $(ROOTFS)/var/lib/scouter/analytics/
ROOTFS_MOUNT_POINT_FILES := $(ROOTFS)/etc/resolv.conf $(ROOTFS)/etc/machine-id

# Aggregate all rootfs contents
ROOTFS_CONTENTS := $(ROOTFS)/usr/bin/scouter-analytics $(ROOTFS_SERVICES) $(ROOTFS_MOUNT_POINT_DIRS) $(ROOTFS_MOUNT_POINT_FILES)

# Default target: build the .raw image locally
$(IMAGE_DIR)/$(IMAGE): $(ROOTFS_CONTENTS)
	mkfs.erofs -zzstd --all-root $@ $(ROOTFS)/

.PHONY: install
install:
	install -D -m 444 $(IMAGE_DIR)/$(IMAGE) $(INSTALL_DIR)/$(IMAGE)

$(ROOTFS)/:
	mkdir -p $@

$(ROOTFS)/usr/bin/scouter-analytics: | $(ROOTFS)/
	podman build --output=type=local,dest=$(ROOTFS) .

$(ROOTFS)/%.service: dist/systemd/%.service | $(ROOTFS)/
	@mkdir -p $(@D)
	cp $< $@

$(ROOTFS)/%/: | $(ROOTFS)/
	mkdir -p $@

$(ROOTFS)/%: | $(ROOTFS)/
	@mkdir -p $(@D)
	echo -n > $@

.PHONY: clean
clean:
	git clean -fd
