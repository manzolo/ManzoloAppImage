# ManzoloAppImage — convenience targets
#
# Quick start for first-time users:
#     make wizard        # interactive, narrated walkthrough
#
# Direct build targets:
#     make image         # build the Docker builder image
#     make build-go      # build the Go CLI AppImage
#     make build-python  # build the Python GUI AppImage
#     make build-cpp     # build the C++ GTK AppImage
#     make build-all     # build all three
#     make clean         # remove build outputs
#     make distclean     # also remove the Docker image

SHELL          := /usr/bin/env bash
.SHELLFLAGS    := -eu -o pipefail -c
.DEFAULT_GOAL  := help

IMAGE_NAME     ?= manzolo-appimage-builder
IMAGE_TAG      ?= latest
OUT_DIR        ?= $(CURDIR)/out

BUILD_IN_DOCKER := ./scripts/build-in-docker.sh

# ---------- meta ----------

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "; printf "ManzoloAppImage — targets:\n\n"} \
	      /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' \
	      $(MAKEFILE_LIST)
	@echo ""
	@echo "Run 'make wizard' for an interactive, narrated walkthrough."

# ---------- interactive ----------

.PHONY: wizard
wizard: ## Interactive guided walkthrough (recommended for first run)
	@./scripts/wizard.sh

# ---------- docker image ----------

.PHONY: image
image: ## Build the Docker builder image
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) docker/

# ---------- builds ----------

.PHONY: build-go
build-go: image ## Build the Go CLI example AppImage
	$(BUILD_IN_DOCKER) 01-go-cli

.PHONY: build-python
build-python: image ## Build the Python GUI example AppImage
	$(BUILD_IN_DOCKER) 02-python-gui

.PHONY: build-cpp
build-cpp: image ## Build the C++ GTK example AppImage
	$(BUILD_IN_DOCKER) 03-cpp-gtk

.PHONY: build-all
build-all: build-go build-python build-cpp ## Build all three example AppImages

# ---------- run / smoke-test ----------

.PHONY: run-go
run-go: ## Run the produced Go AppImage
	@APPIMAGE_EXTRACT_AND_RUN=1 $(OUT_DIR)/HelloGo-x86_64.AppImage

.PHONY: run-python
run-python: ## Run the produced Python AppImage (needs an X server)
	@APPIMAGE_EXTRACT_AND_RUN=1 $(OUT_DIR)/HelloPython-x86_64.AppImage

.PHONY: run-cpp
run-cpp: ## Run the produced C++ AppImage (needs an X server)
	@APPIMAGE_EXTRACT_AND_RUN=1 $(OUT_DIR)/HelloCpp-x86_64.AppImage

# ---------- cleanup ----------

.PHONY: clean
clean: ## Remove build outputs (keeps Docker image)
	rm -rf $(OUT_DIR) examples/*/AppDir examples/*/build examples/*/squashfs-root
	@echo "Cleaned build outputs."

.PHONY: distclean
distclean: clean ## clean + remove the Docker builder image
	-docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	@echo "Removed Docker image $(IMAGE_NAME):$(IMAGE_TAG)."
