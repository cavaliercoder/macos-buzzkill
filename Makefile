PREFIX ?= /usr/local

buzzkilld: buzzkilld.swift
	swiftc -O $< -o $@

.PHONY: install clean
install: buzzkilld
	install -d $(PREFIX)/bin
	install -m 755 buzzkilld $(PREFIX)/bin/buzzkilld

clean:
	rm -f buzzkilld
