IMAGE_NAME=verilator-cocotb
TAG=latest
CONTAINER_NAME=verilator-dev

.PHONY: build
build:
	podman build -t $(IMAGE_NAME):$(TAG) .

.PHONY: run
run:
	podman run --rm -it \
		--name $(CONTAINER_NAME) \
		-v $(PWD)/../../..:/workspace \
		-w /workspace \
		$(IMAGE_NAME):$(TAG)

.PHONY: clean
clean:
	podman rmi $(IMAGE_NAME):$(TAG)
