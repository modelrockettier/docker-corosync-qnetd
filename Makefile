.PHONY: build

ARGS ?= -t corosync-qnetd:v3-arm64v8

build:
	docker pull arm64v8/debian:buster-slim
	docker build $(ARGS) .
