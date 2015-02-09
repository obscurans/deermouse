/** Copyright (C) 2014-2015 Jeffrey Tsang. All rights reserved.
 *  See /LICENCE.md */

class OutOfInputException : object.Exception {
	this() {
		super("Input exhausted");
	}
};

/* Semantic derivation for a nonterminal */
final class Derivation {
	/* Value type tag */
	enum Type {
		failure,
		_null,
		_dchar,
		_dstring,
	}

	size_t offset;
	Type type = Type.failure;

	this(size_t offset) {
		this.offset = offset;
		type = Type._null;
		value._dstring = null;
	}

	this(size_t offset, dchar value) {
		this.offset = offset;
		type = Type._dchar;
		this.value._dchar = value;
	}

	this(size_t offset, dstring value) {
		this.offset = offset;
		type = Type._dstring;
		this.value._dstring = value;
	}

	@property nothrow dchar _dchar() const {
		assert(type == Type._dchar);
		return value._dchar;
	}

	@property nothrow dchar _dchar(dchar value) {
		assert(type == Type._dchar);
		return this.value._dchar = value;
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
	/* Tagged union for semantic values */
	union Value {
		dchar _dchar;
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

