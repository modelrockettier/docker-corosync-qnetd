.PHONY: build

ARGS ?= -t corosync-qnetd:v3-arm32v7

build:
	docker pull arm32v7/debian:buster-slim
	docker build $(ARGS) .
