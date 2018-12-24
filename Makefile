SHELL := /bin/bash

build-tool:
	go build -o bin/appcenter-cli cmd/main.go
build:
	./scripts/build.sh
build-nokvm:
	./scripts/build.sh --no-kvm