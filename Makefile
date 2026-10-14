PREFIX ?= /usr/local
BIN = .build/release/buzzkilld

.PHONY: build test smoke install clean
build:
	swift build -c release

test:
	swift test

smoke:
	scripts/smoke-test.sh

install: build
	install -d $(PREFIX)/bin
	install -m 755 $(BIN) $(PREFIX)/bin/buzzkilld

clean:
	rm -rf .build
