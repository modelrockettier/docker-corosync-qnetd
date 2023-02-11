.PHONY: build

ARGS ?= --tag corosync-qnetd:v3-arm64v8

build:
	docker pull arm64v8/debian:buster-slim
	docker buildx build --platform linux/arm64/v8 $(ARGS) .
