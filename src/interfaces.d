/* Copyright (C) 2014 Jeffrey Tsang. All rights reserved. See /LICENCE.md */

class OutOfInputException : object.Exception {
	this() {
		super("Input exhausted");
	}
};

struct Derivation {
	size_t offset;
	bool success = false;
	// value;
}

interface InputBuffer {
	dchar opIndex(size_t); // retrieve the nth character, blocking
	dstring opSlice(size_t, size_t); // retrieve a range of characters, blocking
	@property nothrow size_t available() const; // number of characters available
	@property nothrow bool eof() const; // if more characters could become available
}

