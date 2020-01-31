.PHONY: build

ARGS ?= -t corosync-qnetd:v2

build:
	docker build $(ARGS) .
