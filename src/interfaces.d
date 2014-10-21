/* Copyright (C) 2014 Jeffrey Tsang. All rights reserved. See /LICENCE.md */

class OutOfInputException : object.Exception {
	this() {
		super("Input exhausted");
	}
};

final class Derivation {
	enum Type {
		failure,
		_null,
		_dstring
	}

	size_t offset;
	Type type = Type.failure;

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

	@property nothrow dstring _dstring() const {
		assert(type == Type._dstring);
		return value._dstring;
	}

	@property nothrow dstring _dstring(dstring value) {
		assert(type == Type._dstring);
		return this.value._dstring = value;
	}

	@property nothrow bool success() const {
		return type != Type.failure;
	}

private:
	union Value {
		dstring _dstring;
	}

	Value value;
}

interface InputBuffer {
	dchar opIndex(size_t); // retrieve the nth character, blocking
	dstring opSlice(size_t, size_t); // retrieve a range of characters, blocking
	@property nothrow size_t available() const; // number of characters available
	@property nothrow bool eof() const; // if more characters could become available
}

