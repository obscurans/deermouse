/** Copyright (C) 2014-2015 Jeffrey Tsang.
 *  All rights reserved. See /LICENCE.md */

import interfaces, parser;
import std.file, std.stdio, std.utf;

/* A fast input file, i.e. all input is read in at once */
class FastWrapper : InputBuffer {
	/* Filename constructor, widens input for stepping */
	this(string name) {
		contents = toUTF32(cast(char[]) read(name));
		validate(contents);
	}

	/* Restore default constructor */
	this() {}

	/* Take a single character from the input */
	dchar opIndex(size_t index) const {
		if (index >= contents.length) {
			throw new OutOfInputException();
		}

		return contents[index];
	}

	/* Take a range of characters from the input */
	dstring opSlice(size_t begin, size_t end) const in {
		assert(end >= begin);
	} body {
		if (end > contents.length) {
			throw new OutOfInputException();
		}

		return contents[begin .. end];
	}

	/* The available length is total input length */
	@property nothrow size_t available() const {
		return contents.length;
	}

	/* Entire file has been read, no further input available */
	@property nothrow bool eof() const {
		return true;
	}

private:
	dstring contents;
}

/* Wrapper around a string used as an InputBuffer */
class StringWrapper : FastWrapper {
	/* Widen string and otherwise use FastWrapper */
	this(string input) {
		contents = toUTF32(input);
		validate(contents);
	}
}

/* A slow input file, i.e. lazily reads characters as needed */
class SlowWrapper : InputBuffer {
	/* Filename constructor, opens named file */
	this(string name) {
		stream = File(name, "rb");
		getter = StreamGetter(stream);
	}

	/* File reference constructor */
	this(File file) {
		stream = file;
		getter = StreamGetter(stream);
	}

	/* Take a single character from input, reads until available */
	dchar opIndex(size_t index) {
		while (contents.length <= index) {
			readChar();
		}
		return contents[index];
	}

	/* Take a range of characters from input, reads until available */
	dstring opSlice(size_t start, size_t end) in {
		assert(end >= start);
	} body {
		while (contents.length <= end) {
			readChar();
		}
		return contents[start .. end];
	}

	/* Current length of input available */
	@property nothrow size_t available() const {
		return contents.length;
	}

	/* Whether the input is exhausted and no further input available */
	@property nothrow bool eof() const {
		try {
			return stream.eof();
		} catch (Exception e) {
			return true;
		}
	}

protected:
	/* Read a single unicode code point and widen it for stepping */
	void readChar() {
		if (getter.empty()) {
			throw new OutOfInputException();
		}
		contents ~= decodeFront(getter);
	}

private:
	/* Thin InputRange structure wrapping a File reference */
	struct StreamGetter {
		char buf;
		File stream;

		/* Constructor using File reference, get first character */
		this(File stream) {
			this.stream = stream;
			if (!empty()) {
				popFront();
			}
		}

		/* Empty if underlying file is eof */
		bool empty() const {
			return stream.eof();
		}

		/* Front of range is buffer character */
		nothrow char front() const {
			return buf;
		}

		/* Read a single byte into buffer character */
		void popFront() {
			int read = getc(stream.getFP());
			if (read >= 0 && read < 256) {
				buf = cast(char) read;
			} else if (!empty()) {
				throw new Exception("Read error");
			}
		}
	}

	File stream;
	StreamGetter getter;
	dstring contents = "";
}

int main(string[] args) {
	InputBuffer input = new StringWrapper(args[1]);
	Parser parser = new Parser(input);

	writeln(parser.parse());
	return 0;
}

