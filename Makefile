.PHONY: build

ARGS ?= -t corosync-qnetd:v3

build:
	docker pull debian:buster-slim
	docker build $(ARGS) .
