/** Copyright (C) 2014-2015 Jeffrey Tsang.
 *  All rights reserved. See /LICENCE.md */

import interfaces;
import std.array, std.ascii, std.conv, std.regex, std.stdio, std.string, std.typetuple;

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
		Derivation deriv = memotable[0, Nonterminal.whitespace, 0];

		if (!deriv.success) {
			throw new Exception("Parse failure");
		}
		// If further characters found after the end of entire parse
		else if (!memotable.input.eof || memotable.input.available > deriv.offset) {
			throw new Exception("Input not exhausted");
		}

		debug(3) memotable.debugPrint();
		return 0;//deriv._real;
	}
}

private:
/* Enum of all nonterminals, as function pointers to their eponymous parsing
 * functions, with a common interface */
enum Nonterminal : Derivation function(size_t, DerivsTable, CallStack = null) {
	expression = &.expression,
	number = &.number,
	whitespace = &.whitespace
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
	pure string toString() const {
		return format("%s(%d)", type, precedence);
	}
}

/* Struct for a single regex component of a parsing rule */
struct RuleRegex {
	dstring regex;

	/* Pretty printer for debugging */
	pure string toString() const {
		return format(`"%s"`, regex);
	}
}

/* Struct for a single character component of a parsing rule */
struct RuleCharacter {
	dchar character;

	/* Pretty printer for debugging */
	pure string toString() const {
		return format("'%c'", character);
	}
}

/* Struct for a single character class component of a parsing rule */
struct RuleCharacterClass {
	dstring characters;

	/* Pretty printer for debugging */
	pure string toString() const {
		return format("[%s]", characters);
	}
}

/* Template tests for valid components of parsing rules */
enum bool isRuleRegex(T) = is(T : RuleRegex) || isSomeString!T;
enum bool isARuleRegex(alias x) = isRuleRegex!(typeof(x));
enum bool isRuleCharacter(T) = is(T : RuleCharacter) || is(T : dchar) || is(T : RuleCharacterClass);
enum bool isARuleCharacter(alias x) = isRuleCharacter!(typeof(x));
enum bool isRuleComponent(T) = is(T : RuleNonterminal) || isRuleRegex!T || isRuleCharacter!T;
enum bool isARuleComponent(alias x) = isRuleComponent!(typeof(x));

/* Template function to take the string out of a RuleRegex, or bare regex string
 * as needed */
pure dstring ruleRegexOf(alias x)() if (isARuleRegex!x) {
	static if (is(typeof(x) : RuleRegex)) {
		return x.regex;
	} else static if (isSomeString!(typeof(x))) {
		return array(x);
	} else static assert(0);
}

/* Template function to take the character out of a RuleCharacter, or bare
 * character; or the character class string out of a RuleCharacterClass as
 * needed */
pure auto ruleCharacterOf(alias x)() if (isARuleCharacter!x) {
	static if (is(typeof(x) : RuleCharacter)) {
		return x.character;
	} else static if (is(typeof(x) : dchar)) {
		return x;
	} else static if (is(typeof(x) : RuleCharacterClass)) {
		return x.characters;
	} else static assert(0);
}

/* Template function to pretty print any rule component as needed for debugging
 */
pure string ruleComponentToString(T)(T x) if (isRuleComponent!T) {
	static if (is(T : RuleNonterminal) || is(T : RuleRegex) ||
			   is(T : RuleCharacter) || is(T : RuleCharacterClass)) {
		return x.toString();
	} else static if (isSomeString!T) {
		return format(`"%s"`, x);
	} else static if (is(T : dchar)) {
		return format("'%c'", x);
	} else static assert(0);
}

/* Main packrat parsing memotable, includes separate nonterminal and regex
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

	/* Index type for the regex matching memotable */
	struct RegexIndex {
		size_t offset;
		dstring regex;

		/* Pretty printer for debugging */
		string toString() const {
			return format(`"%s":%d`, regex, offset);
		}
	}

	InputBuffer input;
	// Main memotable for nonterminal derivations
	Derivation[NonterminalIndex] memotable;
	Capture[RegexIndex] regextable; // Regex match memotable

	/* One-field constructor */
	this(InputBuffer input) {
		this.input = input;
	}

	/* Bind a different InputBuffer, clears entire memotable */
	void bindInputBuffer(InputBuffer newbuf) {
		input = newbuf;
		memotable = memotable.init; // Clear memotables
		regextable = regextable.init;
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

		// Left recursion handling algorithm
		do {
			// Memoize current parse result
			memotable[index] = temp;

			debug(2) writeln(index, " left recursion detected, reevaluating parsing function");
			/* Reevaluate parsing function for the nonterminal, which
			 * will have access to the current parse result to grow the
			 * left-recursive parse */
			temp = index.type(index.offset, this, new CallStack(index.precedence));

		// Termination condition: if the parse fails to grow further
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

	/* Memoized function for matching a regex string */
	Capture retrieveMatch(dstring regex)(size_t offset) {
		RegexIndex index = RegexIndex(offset, regex);
		// Force all regexes to be applied at start of offset
		enum matcher = ctRegex!("^" ~ regex);

		debug(1) writeln("Retrieving ", index);
		if (index !in regextable) {
			debug(4) writeln(index, " not found, regex matching");
			// Create table entry
			try {
				/* TODO: currently forced to use dstring instead of passing
				 * input range by std.regex, BREAKS lazy input buffers */
				regextable[index] = matchFirst(input[offset .. input.available], matcher);
			} catch (OutOfInputException e) {
				debug(4) writeln(index, " out of input");
				regextable[index] = Capture.init;
			}
		}

		debug(2) writeln(index, cast(bool) regextable[index] ? " matched " ~ regextable[index][0] : " failure");
		return regextable[index]; // Return memoized result
	}

	/* Thin wrapper for attempting to match a nonterminal and testing its
	 * success */
	bool matchNonterminal(out Derivation deriv, size_t offset, Nonterminal type, byte precedence) {
		deriv = this[offset, type, precedence];
		return deriv.success;
	}

	/* Thin wrapper for attempting to match a regex and testing its success */
	bool matchRegex(dstring regex)(out Derivation deriv, size_t offset) {
		Capture match = retrieveMatch!regex(offset);
		if (cast(bool) match) {
			deriv = Derivation(offset + match[0].length, match);
			return true;
		} else {
			deriv = Derivation.init;
			return false;
		}
	}

	/* Attempt to match a single bare character */
	bool matchCharacter(dchar character)(out Derivation deriv, size_t offset) {
		debug(5) writefln("Matching '%c':%d", character, offset);
		try {
			if (this.input[offset] == character) {
				deriv = Derivation(offset + 1, character);
				return true;
			}
		} catch (OutOfInputException e) { // Fall through to failure
			debug(5) writefln("'%c':%d out of input", character, offset);
		}

		deriv = Derivation.init;
		return false;
	}

	/* Attempt to match a character class */
	bool matchCharacter(dstring characters)(out Derivation deriv, size_t offset) {
		debug(5) writefln("Matching [%s]:%d", characters, offset);
		try {
			if (inPattern(this.input[offset], characters)) {
				deriv = Derivation(offset + 1, this.input[offset]);
				return true;
			}
		} catch (OutOfInputException e) { // Fall through to failure
			debug(5) writefln("[%s]:%d out of input", characters, offset);
		}

		deriv = Derivation.init;
		return false;
	}

	/* Pretty printer of entire table contents for debugging */
	void debugPrint() {
		writeln("Table contents:");
		foreach (key, val; memotable) {
			writefln("%s -> %s", key, val);
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

	@property Derivation emptyMatch() {
		debug(2) writefln("%s matched empty string", debugName);
		return Derivation(offset, null);
	}

	static if (recursion) {
		/* Whether a left-recursive rule has been tried, to mark the result for
		 * left-recursion handling */
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
				writef(" %s", ruleComponentToString(C));
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

			/* Compile-time switch for handling nonterminals, regexes, and
			 * character (classes)? properly. If any component fails, entire
			 * match fails */
			static if (is(typeof(C) : RuleNonterminal)) {
				if (!table.matchNonterminal(parts[i], nextOffset, to!Nonterminal(C.type), C.precedence)) {
					return false;
				}
			} else static if (isARuleRegex!C) {
				enum regex = ruleRegexOf!C;
				if (!table.matchRegex!regex(parts[i], nextOffset)) {
					return false;
				}
			} else static if (isARuleCharacter!C) {
				enum character = ruleCharacterOf!C;
				if (!table.matchCharacter!character(parts[i], nextOffset)) {
					return false;
				}
			} else static assert(0);
		}

		/* Match succeeds, obtain semantic value of combined parse and set
		 * result, including possible use of tryRecurse flag */
		static if (recursive) {
			result = Derivation(parts[$ - 1].offset, semanticAction(parts), tryRecurse);
		} else {
			result = Derivation(parts[$ - 1].offset, semanticAction(parts));
		}

		// Debug printer for successful matching of rule
		debug(2) {
			writef("%s matched", debugName);
			foreach (i, C; Components) {
				static if (is(typeof(C) : RuleNonterminal) || isARuleRegex!C) {
					writef(" %s{%s}", ruleComponentToString(C), parts[i]);
				} else static if (isARuleCharacter!C) {
					writef(" %s", ruleComponentToString(C));
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
						RuleNonterminal("number", 0)) PR3_2;
		if (PR3_2.match()) {
			return PR3_2.result;
		}

		return failure;

	default: assert(0);
	}
}

/* Parsing function for the nonterminal Number */
Derivation number(size_t offset, DerivsTable table, CallStack stack = null) {
	mixin ParsingDeclarations!false;

	topLevelPrint();

	mixin ParseRule!((x) { return to!real(x[0].capture[0]); }, false, `[0-9]*\.?[0-9]*`) PR;
	if (PR.match()) {
		return PR.result;
	}

	return failure;
}

/* Parsing function for the nonterminal Whitespace */
Derivation whitespace(size_t offset, DerivsTable table, CallStack stack = null) {
	mixin ParsingDeclarations!false;

	topLevelPrint();

	mixin ParseRule!((x) { return null; }, false, `\s+`, RuleNonterminal("whitespace", 0)) PR1;
	if (PR1.match()) {
		return PR1.result;
	}

	mixin ParseRule!((x) { return null; }, false, `//.*?(?:\r\n?|[\n\u2028\u2029]|$)`, RuleNonterminal("whitespace", 0)) PR2;
	if (PR2.match()) {
		return PR2.result;
	}

	mixin ParseRule!((x) { return null; }, false, `/\*(?:\*(?!/)|[^*])*\*/`, RuleNonterminal("whitespace", 0)) PR3;
	if (PR3.match()) {
		return PR3.result;
	}

	return emptyMatch;
}

