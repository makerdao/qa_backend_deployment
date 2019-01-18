GOOS ?= linux
GOARCH ?= amd64
SRV = $(notdir $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))))
PROJECT = github.com/makerdao/${SRV}
TAG ?= latest
PORT ?= 5001
API_TOKEN ?= $(shell cat .apiToken)
CA_DIR ?= certs
PWD ?= $(pwd)

build: vendor lint certs
	@echo "+ $@ ${GOOS}"
	@CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH} go build -a -installsuffix cgo \
		-o bin/${GOOS}-${GOARCH}/service ${PROJECT}/cmd
.PHONY: build

vendor:
	@echo "+ $@"
	@GO111MODULE=on go mod tidy
	@GO111MODULE=on go mod vendor
.PHONY: vendor

run: build
	@echo "+ $@ ${GOOS}"
	@bin/${GOOS}-${GOARCH}/service
.PHONY: run

test:
	@echo "+ $@"
	@mkdir ${PWD}/.testdir && echo "testdir created" || echo "testdir already exists"
	@TCD_GITHUB="apiToken=${API_TOKEN};workDir=${PWD}/.testdir" go test -count=1 -parallel 1 ./...
.PHONY: test

lint:
	@echo "+ $@"
	@docker run --rm -i  \
		-v ${GOPATH}/src/${PROJECT}:/go/src/${PROJECT} \
		-w /go/src/${PROJECT} golangci/golangci-lint:v1.12 golangci-lint run --enable-all --skip-dirs vendor,version,pkg/gen ./...
.PHONY: lint

build-image: build
	@echo "+ $@"
	@docker build -t ${SRV}:${TAG} .
.PHONY: build-image

stop-image:
	@echo "+ $@"
	@docker stop ${SRV} && echo "container stoped" || echo "container is not runned"
	@docker rm -f ${SRV} && echo "container removed" || echo "container not exists"
.PHONY: build-image

run-image: stop-image build-image
	@echo "+ $@"
	@docker run -d -p ${PORT}:${PORT} \
		-e TCD_PORT='${PORT}' \
		-e TCD_GITHUB="apiToken=${API_TOKEN}" \
		--name=${SRV} ${SRV}:${TAG}
.PHONY: run-image

logs:
	@echo "+ $@"
	@docker logs -f ${SRV}
.PHONY: image-logs

certs:
ifeq ("$(wildcard $(CA_DIR)/ca-certificates.crt)","")
	@echo "+ $@"
	@docker run --name ${SRV}-certs -d alpine:latest sh -c "apk --update upgrade && apk add ca-certificates && update-ca-certificates"
	@docker wait ${SRV}-certs
	@mkdir -p ${CA_DIR}
	@docker cp ${SRV}-certs:/etc/ssl/certs/ca-certificates.crt ${CA_DIR}
	@docker rm -f ${SRV}-certs
endif
.PHONY: certs