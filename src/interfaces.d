/** Copyright (C) 2014-2015 Jeffrey Tsang.
 *  All rights reserved. See /LICENCE.md */

import std.regex, std.string;

alias Capture = std.regex.Captures!dstring;

/* Single-message exception */
class OutOfInputException : object.Exception {
	this() {
		super("Input exhausted");
	}
};

/* Semantic derivation for a nonterminal
 * TODO: implement mixin template for adding value types */
struct Derivation {
	/* Value type tag */
	enum Type {
		failure,
		_null,
		capture,
		_dchar,
		_real,
	}

	size_t offset; // The codepoint offset in the input string after the parse
	bool recurse; // Whether a left-recursion attempt has been made
	Type type = Type.failure; // Tag type of the associated semantic value

	this(size_t offset, typeof(null) value, bool recurse = false) {
		this.offset = offset;
		type = Type._null;
		this.recurse = recurse;
	}

	this(size_t offset, Capture value, bool recurse = false) {
		this.offset = offset;
		type = Type.capture;
		this.value.capture = value;
		this.recurse = recurse;
	}

	this(size_t offset, dchar value, bool recurse = false) {
		this.offset = offset;
		type = Type._dchar;
		this.value._dchar = value;
		this.recurse = recurse;
	}

	this(size_t offset, real value, bool recurse = false) {
		this.offset = offset;
		type = Type._real;
		this.value._real = value;
		this.recurse = recurse;
	}

	@property pure nothrow Capture capture() const {
		assert(type == Type.capture);
		return cast() value.capture; // Value type, strip const
	}

	@property nothrow Capture capture(Capture value) {
		assert(type == Type.capture);
		return this.value.capture = value;
	}

	@property pure nothrow dchar _dchar() const {
		assert(type == Type._dchar);
		return value._dchar;
	}

	@property nothrow dchar _dchar(dchar value) {
		assert(type == Type._dchar);
		return this.value._dchar = value;
	}

	@property pure nothrow real _real() const {
		assert(type == Type._real);
		return value._real;
	}

	@property nothrow real _real(real value) {
		assert(type == Type._real);
		return this.value._real = value;
	}

	@property pure nothrow bool success() const {
		return type != Type.failure;
	}

	/* Marks the Derivation as being recursive */
	nothrow Derivation markRecursive(bool recurse = true) {
		this.recurse = recurse;
		return this;
	}

	/* Pretty printer for debugging */
	string toString() const {
		string ret = format("%d%s:", offset, recurse ? "LR" : "");
		final switch (type) {
		case Type.failure: return ret ~ "failure";
		case Type._null: return ret ~ "null";
		case Type.capture: return ret ~ format("(match)%s", capture[0]);
		case Type._dchar: return ret ~ format("(char)%c", _dchar);
		case Type._real: return ret ~ format("(real)%g", _real);
		}
	}

private:
	/* Tagged union for semantic values */
	union Value {
		Capture capture;
		dchar _dchar;
		real _real;
	}

	Value value; // Private semantic value
}

/* Interface to a random-access contiguous input wrapper */
interface InputBuffer {
	/* Retrieve the nth character of input, blocking */
	dchar opIndex(size_t);
	/* Retrieve a range of characters, blocking */
	dstring opSlice(size_t, size_t);
	/* The number of characters currently available */
	@property pure nothrow size_t available() const;
	/* If !eof, further characters could become available */
	@property pure nothrow bool eof() const;
}

