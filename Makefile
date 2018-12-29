SHELL := /bin/bash

build-tool:
	go build -o bin/appcenter-cli cmd/main.go
build-single:
	./scripts/build.sh single
build-single-nokvm:
	./scripts/build.sh single --no-kvm
deploy-case1:
	./scripts/deploy.sh single app/test/case1.json
delete-cluster:
	./scripts/delete_cluster.sh single