SOURCEDIR=.
SOURCES := $(shell find $(SOURCEDIR) -name '*.go')

define pull_container
	docker pull projectunik/$(1):$(shell cat containers/versions.json  | jq .['"$(1)"'])
endef

define build_container
	cd containers/$(1) && docker build -t projectunik/$(2):$(shell cat containers/versions.json  | jq .['"$(2)"']) -f Dockerfile$(3) .
endef

define remove_container
	docker rmi -f projectunik/$(1):$(shell cat containers/versions.json  | jq .['"$(1)"'])
endef

all: pull ${SOURCES} binary

.PHONY: pull
.PHONY: containers
.PHONY: rump-debugger-qemu
.PHONY: compilers-rump-base-common
.PHONY: compilers-rump-base-hw
.PHONY: compilers-rump-base-xen
.PHONY: compilers-rump-go-hw
.PHONY: compilers-rump-go-hw-no-stub
.PHONY: compilers-rump-go-xen
.PHONY: compilers-rump-nodejs-hw
.PHONY: compilers-rump-nodejs-hw-no-stub
.PHONY: compilers-rump-nodejs-xen
.PHONY: compilers-rump-python3-hw
.PHONY: compilers-rump-python3-hw-no-stub
.PHONY: compilers-rump-python3-xen
.PHONY: compilers-osv-java
.PHONY: compilers
.PHONY: boot-creator
.PHONY: image-creator
.PHONY: vsphere-client
.PHONY: qemu-util
.PHONY: utils
.PHONY: 

#pull containers
pull:
	echo "Pullling containers from docker hub"
	$(call pull_container,vsphere-client)
	$(call pull_container,boot-creator)
	$(call pull_container,qemu-util)
	$(call pull_container,compilers-osv-java)
	$(call pull_container,compilers-rump-go-hw)
	$(call pull_container,compilers-rump-go-hw-no-stub)
	$(call pull_container,compilers-rump-go-xen)
	$(call pull_container,compilers-rump-nodejs-hw)
	$(call pull_container,compilers-rump-nodejs-hw-no-stub)
	$(call pull_container,compilers-rump-nodejs-xen)
	$(call pull_container,compilers-rump-python3-hw)
	$(call pull_container,compilers-rump-python3-hw-no-stub)
	$(call pull_container,compilers-rump-python3-xen)
	$(call pull_container,compilers-rump-base-xen)
	$(call pull_container,compilers-rump-base-hw)
	$(call pull_container,rump-debugger-qemu)
	$(call pull_container,compilers-rump-base-common)
#------

#build containers from source
containers: compilers utils
	echo "Built containers from source"

#compilers
compilers: compilers-rump-go-hw \
           compilers-rump-go-xen \
           compilers-rump-nodejs-hw \
           compilers-rump-nodejs-hw-no-stub \
           compilers-rump-nodejs-xen \
           compilers-osv-java \
           compilers-rump-go-hw-no-stub \
           compilers-rump-python3-hw \
           compilers-rump-python3-hw-no-stub \
           compilers-rump-python3-xen

compilers-rump-base-common: 
	$(call build_container,compilers/rump/base,$@,.common)

compilers-rump-base-hw: compilers-rump-base-common
	$(call build_container,compilers/rump/base,$@,.hw)

compilers-rump-base-xen: compilers-rump-base-common
	$(call build_container,compilers/rump/base,$@,.xen)

compilers-rump-go-hw: compilers-rump-base-hw
	$(call build_container,compilers/rump/go,$@,.hw)

rump-debugger-qemu: compilers-rump-base-hw
	$(call build_container,debuggers/rump/base,$@,.hw)

compilers-rump-go-hw-no-stub: compilers-rump-base-hw
	$(call build_container,compilers/rump/go,$@,.hw.no-stub)
	cd containers/compilers/rump/go && docker build -t projectunik/$@$(CONTAINERTAG) -f Dockerfile.hw.no-stub .

compilers-rump-go-xen: compilers-rump-base-xen
	$(call build_container,compilers/rump/go,$@,.xen)

compilers-rump-nodejs-hw: compilers-rump-base-hw
	$(call build_container,compilers/rump/nodejs,$@,.hw)

compilers-rump-nodejs-hw-no-stub: compilers-rump-base-hw
	$(call build_container,compilers/rump/nodejs,$@,.hw.no-stub)

compilers-rump-nodejs-xen: compilers-rump-base-xen
	$(call build_container,compilers/rump/nodejs,$@,.xen)

compilers-rump-python3-hw: compilers-rump-base-hw
	$(call build_container,compilers/rump/python3,$@,.hw)

compilers-rump-python3-hw-no-stub: compilers-rump-base-hw
	$(call build_container,compilers/rump/python3,$@,.hw.no-stub)

compilers-rump-python3-xen: compilers-rump-base-xen
	$(call build_container,compilers/rump/python3,$@,.xen)

compilers-osv-java:
	cd containers/compilers/osv/java-compiler && GOOS=linux go build
	$(call build_container,compilers/osv/java-compiler,$@,)
	cd containers/compilers/osv/java-compiler && rm java-compiler

#utils
utils: boot-creator image-creator vsphere-client qemu-util

boot-creator: 
	cd containers/utils/boot-creator && GO15VENDOREXPERIMENT=1 GOOS=linux go build
	$(call build_container,utils/boot-creator,$@,)
	cd containers/utils/boot-creator && rm boot-creator

image-creator: 
	cd containers/utils/image-creator && GO15VENDOREXPERIMENT=1 GOOS=linux go build
	$(call build_container,utils/image-creator,$@,)
	cd containers/utils/image-creator && rm image-creator

vsphere-client: 
	cd containers/utils/vsphere-client && mvn package
	$(call build_container,utils/vsphere-client,$@,)
	cd containers/utils/vsphere-client && rm -rf target

qemu-util: 
	$(call build_container,utils/qemu-util,$@,)

#------

#binary

BINARY=unik

# don't override if provided already
ifeq (,$(TARGET_OS))
    UNAME:=$(shell uname)
	ifeq ($(UNAME),Linux)
		TARGET_OS:=linux
	else ifeq ($(UNAME),Darwin)
		TARGET_OS:=darwin
	endif
endif

binary: ${SOURCES}
ifeq (,$(TARGET_OS))
	echo "Unknown platform $(UNAME)"
	echo "Unknown platform $(TARGET_OS)"
	exit 1
endif
	echo Building for platform $(UNAME)
	docker build -t projectunik/$@ -f Dockerfile .
	mkdir -p ./_build
	docker run --rm -v $(shell pwd)/_build:/opt/build -e TARGET_OS=$(TARGET_OS) -e CONTAINERVER=$(CONTAINERVER) projectunik/$@
	#docker rmi -f projectunik/$@
	echo "Install finished! UniK binary can be found at $(shell pwd)/_build/unik"
#----

# local build - useful if you have development env setup. if not - use binary! (this can't depend on binary as binary depends on it via the Dockerfile)
CONTAINER_VERSIONS_JSON:=$(shell echo $(shell cat containers/versions.json | sed 's/"/\\\"/g') | sed 's/"/\\\"/g' | sed 's/ //g')
localbuild: instance-listener/bindata/instance_listener_data.go  ${SOURCES}
	GOOS=${TARGET_OS} go build -ldflags "-X github.com/emc-advanced-dev/unik/pkg/util.containerVersionsJson=$(CONTAINER_VERSIONS_JSON)" -v .

instance-listener/bindata/instance_listener_data.go:
	go-bindata -o instance-listener/bindata/instance_listener_data.go --ignore=instance-listener/bindata/ instance-listener/... && \
	perl -pi -e 's/package main/package bindata/g' instance-listener/bindata/instance_listener_data.go
    
#clean up
.PHONY: uninstall remove-containers clean

uninstall:
	rm $(which ${BINARY})

remove-containers:
	-docker rmi -f projectunik/binary
	-$(call remove_container,vsphere-client)
	-$(call remove_container,image-creator)
	-$(call remove_container,boot-creator)
	-$(call remove_container,compilers-osv-java)
	-$(call remove_container,compilers-rump-go-xen)
	-$(call remove_container,compilers-rump-go-hw)
	-$(call remove_container,compilers-rump-go-hw-no-stub)
	-$(call remove_container,compilers-rump-nodejs-hw)
	-$(call remove_container,compilers-rump-nodejs-hw-no-stub)
	-$(call remove_container,compilers-rump-nodejs-xen)
	-$(call remove_container,compilers-rump-python3-hw)
	-$(call remove_container,compilers-rump-python3-hw-no-stub)
	-$(call remove_container,compilers-rump-python3-xen)
	-$(call remove_container,compilers-rump-base-xen)
	-$(call remove_container,compilers-rump-base-hw)
	-$(call remove_container,rump-debugger-qemu)
	-$(call remove_container,compilers-rump-base-common)

clean:
	rm -rf ./_build
#---
