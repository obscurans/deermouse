/** Copyright (C) 2014-2015 Jeffrey Tsang.
 *  All rights reserved. See /LICENCE.md */

import std.string;

class OutOfInputException : object.Exception {
	this() {
		super("Input exhausted");
	}
};

/* Semantic derivation for a nonterminal
 * TODO: implement mixin template for adding value types */
final class Derivation {
	/* Value type tag */
	enum Type {
		failure,
		_null,
		_dchar,
		_dstring,
		_real,
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

	this(size_t offset, real value) {
		this.offset = offset;
		type = Type._real;
		this.value._real = value;
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

	@property nothrow real _real() const {
		assert(type == Type._real);
		return value._real;
	}

	@property nothrow real _real(real value) {
		assert(type == Type._real);
		return this.value._real = value;
	}

	@property nothrow bool success() const {
		return type != Type.failure;
	}

	override string toString() const {
		string ret = format("%d:", offset);
		final switch (type) {
		case Type.failure: return ret ~ "failure";
		case Type._null: return ret ~ "null";
		case Type._dchar: return ret ~ format("(char)%s", _dchar);
		case Type._dstring: return ret ~ format("(string)%s",_dstring);
		case Type._real: return ret ~ format("(real)%g", _real);
		}
	}

private:
	/* Tagged union for semantic values */
	union Value {
		dchar _dchar;
		dstring _dstring;
		real _real;
	}

	Value value;
}

interface InputBuffer {
	dchar opIndex(size_t); // retrieve the nth character, blocking
	dstring opSlice(size_t, size_t); // retrieve a range of characters, blocking
	@property nothrow size_t available() const; // number of characters available
	@property nothrow bool eof() const; // if more characters could become available
}

