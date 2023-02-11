.PHONY: build

ARGS ?= -t corosync-qnetd:latest

build:
	docker pull debian:buster-slim
	docker build $(ARGS) .
