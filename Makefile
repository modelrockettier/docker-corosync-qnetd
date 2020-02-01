.PHONY: build

ARGS ?= -t corosync-qnetd:v2

build:
	docker pull debian:stretch-slim
	docker build $(ARGS) .
