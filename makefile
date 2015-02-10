#!/usr/bin/make
# Makefile for deermouse/
#
# Copyright (C) 2014-2015 Jeffrey Tsang
# All rights reserved. See /licence.md

.PHONY: default clean debug

default: debug

clean:
	rm deermouse
	cd src/; make clean

debug:
	cd src/; make debug
	mv src/deermouse .
