/** Copyright (C) 2014 Jeffrey Tsang. All rights reserved. See /LICENCE.md */

import interfaces;
import std.file, std.stdio, std.utf;

class FastWrapper : InputBuffer {
	this(string name) {
		contents = toUTF32(cast(char[]) read(name));
		validate(contents);
	}

	immutable this(string name) {
		contents = toUTF32(cast(char[]) read(name));
		validate(contents);
	}

	dchar opIndex(size_t index) {
		return contents[index];
	}

	dchar opIndex(size_t index) const {
		return contents[index];
	}

	dstring opSlice(size_t begin, size_t end) in {
		assert(end >= begin);
	} body {
		return contents[begin .. end];
	}

	dstring opSlice(size_t begin, size_t end) const in {
		assert(end >= begin);
	} body {
		return contents[begin .. end];
	}

	@property nothrow size_t available() const {
		return contents.length;
	}

	@property nothrow bool eof() const {
		return true;
	}

private:
	dstring contents;
}

class SlowWrapper : InputBuffer {
	this(string name) {
		stream = File(name, "rb");
		getter = StreamGetter(stream);
	}

	this(File file) {
		stream = file;
		getter = StreamGetter(stream);
	}

	dchar opIndex(size_t index) {
		while (contents.length <= index) {
			readChar();
		}
		return contents[index];
	}

	dstring opSlice(size_t start, size_t end) in {
		assert(end >= start);
	} body {
		while (contents.length <= end) {
			readChar();
		}
		return contents[start .. end];
	}

	@property nothrow size_t available() const {
		return contents.length;
	}

	@property nothrow bool eof() const {
		try {
			return stream.eof();
		} catch (Exception e) {
			return true;
		}
	}

protected:
	void readChar() {
		if (getter.empty()) {
			throw new OutOfInputException();
		}
		contents ~= decodeFront(getter);
	}

private:
	struct StreamGetter {
		char buf;
		File stream;

		this(File stream) {
			this.stream = stream;
			if (!empty()) {
				popFront();
			}
		}

		bool empty() const {
			return stream.eof();
		}

		nothrow char front() const {
			return buf;
		}

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
	return 0;
}

