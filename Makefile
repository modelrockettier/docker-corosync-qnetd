.PHONY: build

ARGS ?= -t corosync-qnetd:latest
LABELS = --label "org.opencontainers.image.created=$(shell date -u '+%FT%T.%3NZ')" \
         --label "org.opencontainers.image.revision=$(shell git rev-parse HEAD)"

build:
	docker build $(LABELS) $(ARGS) .
