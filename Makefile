.PHONY: all build run test clean bootstrap

all: build

bootstrap:
	./scripts/bootstrap.sh

build: bootstrap
	zig build

run: bootstrap
	zig build run

test:
	zig build test

clean:
	rm -rf zig-out .zig-cache

# Development helpers
fmt:
	zig fmt src/

check:
	zig build --summary all
