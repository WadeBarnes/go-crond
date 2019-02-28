SOURCE = $(wildcard *.go)
TAG ?= $(shell git describe --tags)
GOBUILD_OSX = go build --ldflags '-w'
GOBUILD_DYNAMIC = go build --ldflags '\''-w'\''
GOBUILD_STATIC = go build --ldflags '\''-linkmode external -extldflags "-static" -w'\''
.PHONY: docker docker-dev docker-run-dev all build test clean release dependencies

ALL = \
	$(foreach arch,64 32,\
	$(foreach suffix,linux osx,\
		build/go-crond-$(arch)-$(suffix))) \
	$(foreach arch,arm arm64,\
		build/go-crond-$(arch)-linux)


docker:
	docker build . -t webdevops/go-crond

docker-dev:
	docker build -f Dockerfile.develop . -t webdevops/go-crond:develop

docker-run: docker-dev
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd):ro" --name=cron webdevops/go-crond:develop bash

build-env: docker-dev
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop bash

all: test build

dependencies:
	go get -u github.com/robfig/cron
	go get -u github.com/jessevdk/go-flags

build: clean dependencies test $(ALL)

# cram is a python app, so 'easy_install/pip install cram' to run tests
test:
	echo test todo
	#cram tests/main.test

clean:
	rm -rf build/

# os is determined as thus: if variable of suffix exists, it's taken, if not, then
# suffix itself is taken
osx = darwin

build/go-crond-64-osx: $(SOURCE)
	@mkdir -p $(@D)
	CGO_ENABLED=1 GOOS=$(firstword $($*) $*) GOARCH=amd64 $(GOBUILD_OSX) -o $@

build/go-crond-32-osx: $(SOURCE)
	@mkdir -p $(@D)
	CGO_ENABLED=1 GOOS=$(firstword $($*) $*) GOARCH=386 $(GOBUILD_OSX) -o $@

build/go-crond-64-linux: $(SOURCE)
	@mkdir -p $(@D)
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop sh -c 'CGO_ENABLED=1 GOOS=$(firstword $($*) $*) GOARCH=amd64 $(GOBUILD_DYNAMIC) -o ${@}-dynamic'
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop sh -c 'CGO_ENABLED=1 GOOS=$(firstword $($*) $*) GOARCH=amd64 $(GOBUILD_STATIC) -o ${@}'

build/go-crond-32-linux: $(SOURCE)
	@mkdir -p $(@D)
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop sh -c 'CGO_ENABLED=1 GOOS=$(firstword $($*) $*) GOARCH=386 $(GOBUILD_DYNAMIC) -o ${@}-dynamic'
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop sh -c 'CGO_ENABLED=1 GOOS=$(firstword $($*) $*) GOARCH=386 $(GOBUILD_STATIC) -o ${@}'

build/go-crond-arm-linux: $(SOURCE)
	@mkdir -p $(@D)
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop sh -c 'CC=arm-linux-gnueabi-gcc CGO_ENABLED=1 GOOS=linux GOARCH=arm GOARM=6 $(GOBUILD_DYNAMIC) -o ${@}-dynamic'
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop sh -c 'CC=arm-linux-gnueabi-gcc CGO_ENABLED=1 GOOS=linux GOARCH=arm GOARM=6 $(GOBUILD_STATIC) -o ${@}'

build/go-crond-arm64-linux: $(SOURCE)
	@mkdir -p $(@D)
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop sh -c 'CC=aarch64-linux-gnu-gcc CGO_ENABLED=1 GOOS=linux GOARCH=arm64 $(GOBUILD_STATIC) -o ${@}'
	winpty docker run -ti --rm -w "/$$(pwd)" -v "/$$(pwd):/$$(pwd)" --name=cron webdevops/go-crond:develop sh -c 'CC=aarch64-linux-gnu-gcc CGO_ENABLED=1 GOOS=linux GOARCH=arm64 $(GOBUILD_DYNAMIC) -o ${@}-dynamic'


release:
	github-release release -u webdevops -r go-crond -t "$(TAG)" -n "$(TAG)" --description "$(TAG)"
	@for x in build/*; do \
		echo "Uploading $$x" && \
		github-release upload -u webdevops \
                              -r go-crond \
                              -t $(TAG) \
                              -f "$$x" \
                              -n "$$(basename $$x)"; \
	done
