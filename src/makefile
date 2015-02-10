#!/usr/bin/make
# Makefile for deermouse/src/
#
# Copyright (C) 2014-2015 Jeffrey Tsang
# All rights reserved. See /licence.md

.PHONY: default clean debug

DC = ldc
DFLAGS = -O5
DEBUGFLAGS = $(DFLAGS) -g -d-debug=4
OBJECTS = interfaces.o io.o output.o parser.o transform.o

default: debug

clean:
	rm *.o

debug: $(OBJECTS)
	$(DC) $(DEBUGFLAGS) $^ -of=deermouse

%.o: %.d
	$(DC) $(DEBUGFLAGS) -c $< -of=$@
