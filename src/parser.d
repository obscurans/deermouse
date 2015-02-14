/** Copyright (C) 2014-2015 Jeffrey Tsang.
 *  All rights reserved. See /LICENCE.md */

import interfaces;
import std.ascii, std.stdio, std.string;

/* Public parsing class, handles setup and use of the memotable */
class Parser {
	DerivsTable memotable;

	/* Create parser bound to this input */
	this(InputBuffer input) {
		memotable = new DerivsTable(input);
	}

	/* Bind a different InputBuffer to the parser, clears entire memotable */
	void bindInputBuffer(InputBuffer newbuf) {
		memotable.bindInputBuffer(newbuf);
	}

	/* Parse the input and return semantic value of starting terminal */
	real parse() {
		Derivation deriv = memotable[0, Nonterminal.expression, 0];

		if (!deriv.success) {
			throw new Exception("Parse failure");
		}
		// If further characters found after the end of entire parse
		else if (!memotable.input.eof || memotable.input.available > deriv.offset) {
			throw new Exception("Input not exhausted");
		}

		debug(3) memotable.debugPrint();
		return deriv._real;
	}
}

private:
/* Enum of all nonterminals, as function pointers to their eponymous parsing
 * functions, with a common interface */
enum Nonterminal : Derivation function(size_t, DerivsTable, CallStack = null) {
	expression = &.expression,
	digit = &.digit
}

/* TODO: left-recursion handling callstack, annotated with precedence levels */
class CallStack {
	byte precedence;

	/* One-field constructor */
	this(byte precedence) {
		this.precedence = precedence;
	}
}

/* Main packrat parsing memotable, includes separate nonterminal and string
 * match memotables */
class DerivsTable {
	/* Index type for the nonterminal memotable */
	struct NonterminalIndex {
		size_t offset;
		Nonterminal type;
		byte precedence;

		/* Pretty printer for debugging */
		string toString() const {
			return format("%s(%d):%d", type, precedence, offset);
		}
	}

	/* Index type for the string matching memotable */
	struct StringIndex {
		size_t offset;
		dstring characters;

		/* Pretty printer for debugging */
		string toString() const {
			return format("string(%s):%d", characters, offset);
		}
	}

	InputBuffer input;
	// Main memotable for nonterminal derivations
	Derivation[NonterminalIndex] memotable;
	bool[StringIndex] stringtable; // String match memotable

	/* One-field constructor */
	this(InputBuffer input) {
		this.input = input;
	}

	/* Bind a different InputBuffer, clears entire memotable */
	void bindInputBuffer(InputBuffer newbuf) {
		input = newbuf;
		memotable = memotable.init; // Clear memotables
		stringtable = stringtable.init;
	}

	/* Memoized function for parsing a nonterminal, handles direct
	 * left-recursion */
	Derivation opIndex(NonterminalIndex index) {
		debug(1) writeln("Retrieving ", index);
		if (index in memotable) {
			debug(2) writeln(index, " found in table: ", memotable[index]);
			return memotable[index]; // Return memoized result
		}

		debug(2) writeln(index, " not found, calling parsing function");
		/* First introduce a guard element to fail the first round of
		 * left-recursive calls */
		memotable[index] = Derivation.init;
		/* Call the associated parsing function for the nonterminal, stored
		 * in type, with the arguments, for the first parse */
		Derivation temp = index.type(index.offset, this, new CallStack(index.precedence));

		/* No recursion, memoize result and return */
		if (!temp.recurse) {
			return memotable[index] = temp;
		}

		/* Left recursion handling algorithm */
		do {
			/* Memoize current parse result */
			memotable[index] = temp;

			debug(2) writeln(index, " left recursion detected, reevaluating parsing function");
			/* Reevaluate parsing function for the nonterminal, which
			 * will have access to the current parse result to grow the
			 * left-recursive parse */
			temp = index.type(index.offset, this, new CallStack(index.precedence));

		/* Termination condition is if the parse fails to grow further
		 */
		} while (temp.offset > memotable[index].offset);

		debug(2) writeln(index, " left recursion ended: ", memotable[index].markRecursive(false));
		/* Unmark recursion on the final parse result, discarding failed
		 * extending parse, and return it */
		return memotable[index].markRecursive(false);
	}

	/* Thin wrapper for array access indexing for a nonterminal */
	Derivation opIndex(size_t offset, Nonterminal type, byte precedence) {
		return opIndex(NonterminalIndex(offset, type, precedence));
	}

	/* Memoized function for matching an unadorned raw string */
	bool opIndex(StringIndex index) {
		debug(1) writeln("Retrieving ", index);
		if (index !in stringtable) {
			debug(4) writeln(index, " not found, string matching");
			// Create table entry
			try {
				stringtable[index] = (input[index.offset .. index.offset +
				  index.characters.length] == index.characters);
			} catch (OutOfInputException e) {
				debug(4) writeln(index, " out of input");
				stringtable[index] = false;
			}
		}

		debug(2) writeln(index, stringtable[index] ? " success" : " failure");
		return stringtable[index]; // Return memoized result
	}

	/* Thin wrapper for array access indexing for an unadorned raw string */
	bool opIndex(size_t offset, dstring characters) {
		return opIndex(StringIndex(offset, characters));
	}

	/* Thin wrapper for array access indexing for an unadorned raw character */
	bool opIndex(size_t offset, dchar character) {
		debug(5) writefln("Matching char(%c):%d", character, offset);
		try {
			if (input[offset] == character) {
				return true;
			}
		} catch (OutOfInputException e) { // Fall through
			debug(5) writefln("char(%c):%d out of input", character, offset);
		}

		return false;
	}

	/* Thin wrapper for attempting to match a nonterminal and testing its
	 * success */
	bool matchNonterminal(out Derivation deriv, size_t offset, Nonterminal type, byte precedence) {
		deriv = this[offset, type, precedence];
		return deriv.success;
	}

	/* Thin wrapper for attempting to match an unadorned raw string and testing
     * its success */
	bool matchString(out Derivation deriv, size_t offset, dstring characters) {
		if (this[offset, characters]) {
			deriv = Derivation(offset + characters.length, characters);
			return true;
		} else {
			deriv = Derivation.init;
			return false;
		}
	}

	/* Thin wrapper for attempting to match a single unadorned raw character */
	bool matchCharacter(out Derivation deriv, size_t offset, dchar character) {
		if (this[offset, character]) {
			deriv = Derivation(offset + 1, character);
			return true;
		} else {
			deriv = Derivation.init;
			return false;
		}
	}

	/* Pretty printer of entire table contents for debugging */
	void debugPrint() {
		writeln("Table contents:");
		foreach (key, val; memotable) {
			writefln("%s -> %d:%f", key, val.offset, val._real);
		}
	}
}

/* Mixin template for automatically instantiating debug pretty-printer, compile-
 * time option to print precedence levels or not (for single-level nonterminals)
 */
mixin template DebugPrint(bool precedence = true) {
	// Take last part of fully qualified name at point of instantiation
	enum lastName = __FUNCTION__[(lastIndexOf(__FUNCTION__, '.') == -1 ? 0 : lastIndexOf(__FUNCTION__, '.') + 1) .. $];

	/* Pretty printer for debugging */
	@property string debugPrint() {
		static if (precedence) {
			return format("%s(%d):%d", lastName, stack.precedence, offset);
		} else {
			return format("%s:%d", lastName, offset);
		}
	}
}

/* Parsing function for the nonterminal Expression */
Derivation expression(size_t offset, DerivsTable table, CallStack stack) in {
	assert(stack !is null);
} body {
	mixin DebugPrint;

	Derivation part1, part2, part3;
	/* Whether a left-recursive rule has been tried, to mark the result for
	 * left-recursion handling */
	bool recurse = false;
	debug(2) writefln("Parsing %s", debugPrint);

	switch (stack.precedence) {
	case 0:
		// Expression = Expression '+' Expression %l
		debug(3) writefln("%s trying Expression(0) '+' Expression(1)", debugPrint);
		recurse = true;
		if (table.matchNonterminal(part1, offset, Nonterminal.expression, 0) &&
		  table.matchCharacter(part2, part1.offset, '+') &&
		  table.matchNonterminal(part3, part2.offset, Nonterminal.expression, 1)) {
			debug(2) writefln("%s matched Expression{%s} '+' Expression{%s} : %g", debugPrint, part1, part3, part1._real + part3._real);
			return Derivation(part3.offset, part1._real + part3._real, recurse);
		}

		// Expression = Expression '-' Expression %l
		debug(3) writefln("%s trying Expression(0) '-' Expression(1)", debugPrint);
		recurse = true;
		if (table.matchNonterminal(part1, offset, Nonterminal.expression, 0) &&
		  table.matchCharacter(part2, part1.offset, '-') &&
		  table.matchNonterminal(part3, part2.offset, Nonterminal.expression, 1)) {
			debug(2) writefln("%s matched Expression{%s} '-' Expression{%s} : %g", debugPrint, part1, part3, part1._real - part3._real);
			return Derivation(part3.offset, part1._real - part3._real, recurse);
		}

		debug(3) writefln("%s falling through precedence level", debugPrint);
		return table[offset, Nonterminal.expression, 1].markRecursive(recurse);

	case 1:
		// Expression = Expression '*' Expression %l
		debug(3) writefln("%s trying Expression(1) '*' Expression(2)", debugPrint);
		recurse = true;
		if (table.matchNonterminal(part1, offset, Nonterminal.expression, 1) &&
		  table.matchCharacter(part2, part1.offset, '*') &&
		  table.matchNonterminal(part3, part2.offset, Nonterminal.expression, 2)) {
			debug(2) writefln("%s matched Expression{%s} '*' Expression{%s} : %g", debugPrint, part1, part3, part1._real * part3._real);
			return Derivation(part3.offset, part1._real * part3._real, recurse);
		}

		// Expression = Expression '/' Expression %l
		debug(3) writefln("%s trying Expression(1) '/' Expression(2)", debugPrint);
		recurse = true;
		if (table.matchNonterminal(part1, offset, Nonterminal.expression, 1) &&
		  table.matchCharacter(part2, part1.offset, '/') &&
		  table.matchNonterminal(part3, part2.offset, Nonterminal.expression, 2)) {
			debug(2) writefln("%s matched Expression{%s} '*' Expression{%s} : %g", debugPrint, part1, part3, part1._real / part3._real);
			return Derivation(part3.offset, part1._real / part3._real, recurse);
		}

		debug(3) writefln("%s falling through precedence level", debugPrint);
		return table[offset, Nonterminal.expression, 2].markRecursive(recurse);

	case 2:
		// Expression = Expression '^' Expression %r
		debug(3) writefln("%s trying Expression(3) '^' Expression(2)", debugPrint);
		if (table.matchNonterminal(part1, offset, Nonterminal.expression, 3) &&
		  table.matchCharacter(part2, part1.offset, '^') &&
		  table.matchNonterminal(part3, part2.offset, Nonterminal.expression, 2)) {
			debug(2) writefln("%s matched Expression{%s} '^' Expression{%s} : %g", debugPrint, part1, part3, part1._real ^^ part3._real);
			return Derivation(part3.offset, part1._real ^^ part3._real, recurse);
		}

		debug(3) writefln("%s falling through precedence level", debugPrint);
		return table[offset, Nonterminal.expression, 3].markRecursive(recurse);

	case 3:
		// Expression = '(' Expression %p 0 ')'
		debug(3) writefln("%s trying '(' Expression(0) ')'", debugPrint);
		if (table.matchCharacter(part1, offset, '(') &&
		  table.matchNonterminal(part2, part1.offset, Nonterminal.expression, 0) &&
		  table.matchCharacter(part3, part2.offset, ')')) {
			debug(2) writefln("%s matched '(' Expression{%s} ')'", debugPrint, part2);
			return Derivation(part3.offset, part2._real, recurse);
		}

		// Expression = Digit
		debug(3) writefln("%s trying Digit", debugPrint);
		if (table.matchNonterminal(part1, offset, Nonterminal.digit, 0)) {
			debug(2) writefln("%s matched Digit{%d:%g}", debugPrint, part1.offset, part1._real);
			return part1.markRecursive(recurse);
		}

		debug(2) writefln("%s failed", debugPrint);
		return Derivation.init; // Failure

	default: assert(0);
	}
}

/* Parsing function for the nonterminal Digit */
Derivation digit(size_t offset, DerivsTable table, CallStack stack = null) {
	mixin DebugPrint!false;

	Derivation part1;
	debug(2) writefln("Parsing %s", debugPrint);

	foreach (dchar i; '0' .. '9') {
		if (table.matchCharacter(part1, offset, i)) {
			debug(2) writefln("%s matched %c", debugPrint, i);
			return Derivation(part1.offset, cast(real)(i - '0'));
		}
	}

	debug(2) writefln("%s failed", debugPrint);
	return Derivation.init; // Failure
}

