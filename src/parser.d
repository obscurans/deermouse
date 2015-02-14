/** Copyright (C) 2014-2015 Jeffrey Tsang.
 *  All rights reserved. See /LICENCE.md */

import interfaces;
import std.ascii, std.conv, std.stdio, std.string, std.typetuple;

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

		debug(3) memotable.debugName();
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

/* Struct for a single nonterminal component of a parsing rule */
struct RuleNonterminal {
	string type;
	byte precedence;

	/* Pretty printer for debugging */
	string toString() const {
		return format("%s(%d)", type, precedence);
	}
}

/* Struct for a single literal character component of a parsing rule */
struct RuleCharacter {
	dchar character;

	/* Pretty printer for debugging */
	string toString() const {
		return format("'%c'", character);
	}
}

/* Template test for a RuleCharacter or bare character */
enum bool isRuleCharacter(T) = is(T : RuleCharacter) || is(T : dchar);

/* Template function to take the character out of a RuleCharacter or bare
 * character as needed */
pure dchar ruleCharacterOf(alias x)() if (isRuleCharacter!(typeof(x))) {
	static if (is(typeof(x) : RuleCharacter)) {
		return x.character;
	} else static if (is(typeof(x) : dchar)) {
		return cast(dchar) x;
	} else static assert(0);
}

/* Template function to pretty print a RuleCharacter or bare character as needed
 * for debugging */
pure string ruleCharacterToString(T)(T x) if (isRuleCharacter!T) {
	static if (is(T : RuleCharacter)) {
		return x.toString();
	} else static if (is(T : dchar)) {
		return format("'%c'", x);
	} else static assert(0);
}

/* Struct for a single literal string component of a parsing rule */
struct RuleString {
	dstring characters;

	/* Pretty printer for debugging */
	string toString() const {
		return format("\"%s\"", characters);
	}
}

/* Template test for a RuleSring or bare string */
enum bool isRuleString(T) = is(T : RuleString) || is(T : dstring);

/* Template function to take the string out of a RuleString or bare string as
 * needed */
pure dstring ruleStringOf(alias x)() if (isRuleString!(typeof(x))) {
	static if (is(typeof(x) : RuleString)) {
		return x.characters;
	} else static if (is(typeof(x) : dstring)) {
		return cast(dstring) x;
	} else static assert(0);
}

/* Template function to pretty print a RuleString or bare string as needed for
 * debugging */
pure string ruleStringToString(T)(T x) if (isRuleString!T) {
	static if (is(T : RuleString)) {
		return x.toString();
	} else static if (is(T : dstring)) {
		return format("\"%s\"", x);
	} else static assert(0);
}

/* Template tests for valid components of parsing rules */
enum bool isRuleComponent(T) = is(T : RuleNonterminal) || isRuleCharacter!T || isRuleString!T;
enum bool isARuleComponent(alias x) = isRuleComponent!(typeof(x));

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
	void debugName() {
		writeln("Table contents:");
		foreach (key, val; memotable) {
			writefln("%s -> %d:%f", key, val.offset, val._real);
		}
	}
}

/* Mixin template for common top-level declarations for nonterminal parsing
 * functions.
 *
 * hasPrecedence: whether this nonterminal has precedence levels
 * hasRecursion: whether this nonterminal has left-recursive rules
 */
mixin template ParsingDeclarations(bool hasPrecedence = true, bool hasRecursion = false) {
	// Take last part of fully qualified name at point of instantiation
	enum nonterminalName = __FUNCTION__[(lastIndexOf(__FUNCTION__, '.') == -1 ? 0 : lastIndexOf(__FUNCTION__, '.') + 1) .. $];
	// Cast to eponymous Nonterminal enum to retrieve parsing function
	enum nonterminalFunction = to!Nonterminal(nonterminalName);
	// Marker for whether this nonterminal has left-recursive rules
	enum recursion = hasRecursion;

	/* Pretty printer for debugging */
	@property string debugName() {
		static if (hasPrecedence) {
			return format("%s(%d):%d", nonterminalName, stack.precedence, offset);
		} else {
			return format("%s:%d", nonterminalName, offset);
		}
	}

	/* Debug print statement at top-level on function entry */
	void topLevelPrint() {
		debug(2) writefln("Parsing %s", debugName);
	}

	/* Return value on parsing failure, plus debug printing */
	@property Derivation failure() {
		debug(2) writefln("%s failed", debugName);
		return Derivation.init;
	}

	static if (recursion) {
		// Whether a left-recursive rule has been tried, to mark the result for
		// left-recursion handling
		bool tryRecurse = false;
	}

	/* Return value on falling through a precedence level, plus debug printing
	 */
	Derivation precedenceFallthrough(byte precedence) {
		debug(3) writefln("%s falling through precedence level", debugName);
		static if (recursion) {
			return table[offset, nonterminalFunction, precedence].markRecursive(tryRecurse);
		} else {
			return table[offset, nonterminalFunction, precedence];
		}
	}
}

/* Main mixin template for compile-time automatically generating a nonterminal
 * parse rule
 *
 * semanticAction: Function to generate the semantic value of the combined parse
 *				   from the Derivations of the components. Will be called with
 *				   the array of component Derivations
 * recursive: Whether this specific parse rule is left-recursive
 * Components: Nonempty ordered list of parse rule components. These can be
 *			   either RuleNonterminal, RuleCharacter, bare dchar, RuleString, or
 *			   bare dstring
 */
mixin template ParseRule(alias semanticAction, bool recursive, Components...)
if (Components.length && allSatisfy!(isARuleComponent, Components)) {
	Derivation result; // Parse rule derivation result

	/* Attempt to match the parse rule, returns success/failure and sets value
	 */
	bool match() {
		Derivation[Components.length] parts; // Component parse Derivations

		// Debug printer for the parse rule name on start of attempt
		debug(3) {
			writef("%s trying", debugName);
			foreach (C; Components) {
				writef(" %s", C);
			}
			writeln();
		}

		static if (recursive) {
			// Mark the tried left-recursion flag for future handling
			tryRecurse = true;
		}

		// Attempt to match each of the components in order
		foreach (i, C; Components) {
			// Compute the offset to start from for next component
			static if (i == 0) {
				size_t nextOffset = offset;
			} else {
				size_t nextOffset = parts[i - 1].offset;
			}

			// Compile-time switch for handling nonterminals, characters, and
			// strings properly. If any component fails, entire match fails
			static if (is(typeof(C) : RuleNonterminal)) {
				if (!table.matchNonterminal(parts[i], nextOffset, to!Nonterminal(C.type), C.precedence)) {
					return false;
				}
			} else static if (isRuleCharacter!(typeof(C))) {
				enum character = ruleCharacterOf!C;
				if (!table.matchCharacter(parts[i], nextOffset, character)) {
					return false;
				}
			} else static if (isRuleString!(typeof(C))) {
				enum characters = ruleStringOf!C;
				if (!table.matchString(parts[i], nextOffset, characters)) {
					return false;
				}
			} else static assert(0);
		}

		// Match succeeds, obtain semantic value of combined parse and set
		// result, including possible use of tryRecurse flag
		static if (recursive) {
			result = Derivation(parts[$ - 1].offset, semanticAction(parts), tryRecurse);
		} else {
			result = Derivation(parts[$ - 1].offset, semanticAction(parts));
		}

		// Debug printer for successful matching of rule
		debug(2) {
			writef("%s matched", debugName);
			foreach (i, C; Components) {
				static if (is(typeof(C) : RuleNonterminal)) {
					writef(" %s{%s}", C, parts[i]);
				} else static if (isRuleCharacter!(typeof(C))) {
					writef(" %s", ruleCharacterToString(C));
				} else static if (isRuleString!(typeof(C))) {
					writef(" %s", ruleStringToString(C));
				} else static assert(0);
			}
			writefln(" => %s", result);
		}

		return true;
	}
}

/* Parsing function for the nonterminal Expression */
Derivation expression(size_t offset, DerivsTable table, CallStack stack) in {
	assert(stack !is null);
} body {
	mixin ParsingDeclarations!(true, true);

	topLevelPrint();

	switch (stack.precedence) {
	case 0:
		mixin ParseRule!((x) { return x[0]._real + x[2]._real; }, true,
						RuleNonterminal("expression", 0), '+', RuleNonterminal("expression", 1)) PR0_1;
		if (PR0_1.match()) {
			return PR0_1.result;
		}

		mixin ParseRule!((x) { return x[0]._real - x[2]._real; }, true,
						RuleNonterminal("expression", 0), '-', RuleNonterminal("expression", 1)) PR0_2;
		if (PR0_2.match()) {
			return PR0_2.result;
		}

		return precedenceFallthrough(1);

	case 1:
		mixin ParseRule!((x) { return x[0]._real * x[2]._real; }, true,
						RuleNonterminal("expression", 1), '*', RuleNonterminal("expression", 2)) PR1_1;
		if (PR1_1.match()) {
			return PR1_1.result;
		}

		mixin ParseRule!((x) { return x[0]._real / x[2]._real; }, true,
						RuleNonterminal("expression", 1), '/', RuleNonterminal("expression", 2)) PR1_2;
		if (PR1_2.match()) {
			return PR1_2.result;
		}

		return precedenceFallthrough(2);

	case 2:
		mixin ParseRule!((x) { return x[0]._real ^^ x[2]._real; }, false,
						RuleNonterminal("expression", 3), '^', RuleNonterminal("expression", 2)) PR2_1;
		if (PR2_1.match()) {
			return PR2_1.result;
		}

		return precedenceFallthrough(3);

	case 3:
		mixin ParseRule!((x) { return x[1]._real; }, false,
						'(', RuleNonterminal("expression", 0), ')') PR3_1;
		if (PR3_1.match()) {
			return PR3_1.result;
		}

		mixin ParseRule!((x) { return x[0]._real; }, false,
						RuleNonterminal("digit", 0)) PR3_2;
		if (PR3_2.match()) {
			return PR3_2.result;
		}

		return failure;

	default: assert(0);
	}
}

/* Parsing function for the nonterminal Digit */
Derivation digit(size_t offset, DerivsTable table, CallStack stack = null) {
	mixin ParsingDeclarations!false;

	topLevelPrint();

	Derivation part1;

	foreach (dchar i; '0' .. '9') {
		if (table.matchCharacter(part1, offset, i)) {
			debug(2) writefln("%s matched %c", debugName, i);
			return Derivation(part1.offset, cast(real)(i - '0'));
		}
	}

	return failure;
}

