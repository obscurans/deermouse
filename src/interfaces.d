/* Copyright (C) 2014 Jeffrey Tsang. All rights reserved. See /LICENCE.md */

class OutOfInputException : object.Exception {
	this() {
		super("Input exhausted");
	}
};

struct Derivation {
	enum Type {
		_dstring,
		_null,
		_failure
	}

	union Value {
		dstring _dstring;
	}

	size_t offset;
	Type type = Type._failure;
	Value value;

	this(size_t offset) {
		this.offset = offset;
		type = Type._null;
		value._dstring = null;
	}

	this(size_t offset, dstring value) {
		this.offset = offset;
		type = Type._dstring;
		this.value._dstring = value;
	}

	@property dstring _dstring() const {
		assert(type == Type._dstring);
		return value._dstring;
	}

	@property bool success() const {
		return type != Type._failure;
	}
}

interface InputBuffer {
	dchar opIndex(size_t); // retrieve the nth character, blocking
	dstring opSlice(size_t, size_t); // retrieve a range of characters, blocking
	@property nothrow size_t available() const; // number of characters available
	@property nothrow bool eof() const; // if more characters could become available
}

