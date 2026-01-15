.PHONY: all build run test clean bootstrap wayland-protocols

all: build

bootstrap: wayland-protocols
	./scripts/bootstrap.sh

# Generate Wayland protocol headers (Linux only)
wayland-protocols:
	@if [ "$$(uname)" = "Linux" ]; then \
		mkdir -p vendor/wayland-protocols && \
		WL_PROTO=$$(pkg-config --variable=pkgdatadir wayland-protocols) && \
		WL_CORE=/usr/share/wayland && \
		cd vendor/wayland-protocols && \
		wayland-scanner client-header $$WL_CORE/wayland.xml wayland-client-protocol.h && \
		wayland-scanner public-code $$WL_CORE/wayland.xml wayland-client-protocol-code.h && \
		wayland-scanner client-header $$WL_PROTO/stable/xdg-shell/xdg-shell.xml xdg-shell-client-protocol.h && \
		wayland-scanner public-code $$WL_PROTO/stable/xdg-shell/xdg-shell.xml xdg-shell-client-protocol-code.h && \
		wayland-scanner client-header $$WL_PROTO/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml xdg-decoration-unstable-v1-client-protocol.h && \
		wayland-scanner public-code $$WL_PROTO/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml xdg-decoration-unstable-v1-client-protocol-code.h && \
		wayland-scanner client-header $$WL_PROTO/stable/viewporter/viewporter.xml viewporter-client-protocol.h && \
		wayland-scanner public-code $$WL_PROTO/stable/viewporter/viewporter.xml viewporter-client-protocol-code.h && \
		wayland-scanner client-header $$WL_PROTO/unstable/relative-pointer/relative-pointer-unstable-v1.xml relative-pointer-unstable-v1-client-protocol.h && \
		wayland-scanner public-code $$WL_PROTO/unstable/relative-pointer/relative-pointer-unstable-v1.xml relative-pointer-unstable-v1-client-protocol-code.h && \
		wayland-scanner client-header $$WL_PROTO/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml pointer-constraints-unstable-v1-client-protocol.h && \
		wayland-scanner public-code $$WL_PROTO/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml pointer-constraints-unstable-v1-client-protocol-code.h && \
		wayland-scanner client-header $$WL_PROTO/staging/fractional-scale/fractional-scale-v1.xml fractional-scale-v1-client-protocol.h && \
		wayland-scanner public-code $$WL_PROTO/staging/fractional-scale/fractional-scale-v1.xml fractional-scale-v1-client-protocol-code.h && \
		wayland-scanner client-header $$WL_PROTO/staging/xdg-activation/xdg-activation-v1.xml xdg-activation-v1-client-protocol.h && \
		wayland-scanner public-code $$WL_PROTO/staging/xdg-activation/xdg-activation-v1.xml xdg-activation-v1-client-protocol-code.h && \
		wayland-scanner client-header $$WL_PROTO/unstable/idle-inhibit/idle-inhibit-unstable-v1.xml idle-inhibit-unstable-v1-client-protocol.h && \
		wayland-scanner public-code $$WL_PROTO/unstable/idle-inhibit/idle-inhibit-unstable-v1.xml idle-inhibit-unstable-v1-client-protocol-code.h; \
	fi

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
