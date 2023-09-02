.PHONY: build

ARGS ?= -t corosync-qnetd:latest

build:
	docker build $(ARGS) .
