/** Copyright (C) 2014-2015 Jeffrey Tsang. All rights reserved.
 *  See /LICENCE.md */

import interfaces;
import std.ascii;

private:
/* Enum of all nonterminals, as eponymous function pointers to their parsing
 * functions, with a common interface */
enum Nonterminal : Derivation function(size_t, DerivsTable, CallStack = null) {
	declaration = &.declaration,
	rule = &.rule,
}

/* Which nonterminals may be (possibly indirectly) left recursive, precomputed
 */
enum Ntlrecursive : bool {
	declaration = false,
	rule = true,
}

/* TODO: left-recursion handling callstack, annotated with precedence levels */
class CallStack {
	byte precedence;
}

/* Main packrat parsing memotable, includes separate nonterminal and string
 * match memotables */
class DerivsTable {
	struct NonterminalIndex {
		size_t offset;
		Nonterminal type;
		byte precedence;
	}

	struct StringIndex {
		size_t offset;
		dstring characters;
	}

	InputBuffer input;
	// Main memotable for nonterminal derivations
	Derivation[NonterminalIndex] memotable;
	bool[StringIndex] stringtable; // String match memotable

	/* Memoized function for parsing a nonterminal */
	Derivation opIndex(NonterminalIndex index) {
		if (index in memotable) {
			return memotable[index]; // Return memoized result
		} else {
			/* Call the associated parsing function for the nonterminal, stored
			 * in type, with the arguments, and memoize result */
			return memotable[index] = index.type(index.offset, this);
		}
	}

	/* Thin wrapper for array access indexing for nonterminals */
	Derivation opIndex(size_t offset, Nonterminal type, byte precedence) {
		return opIndex(NonterminalIndex(offset, type, precedence));
	}

	/* Memoized function for matching an unadorned raw string */
	bool opIndex(StringIndex index) {
		if (index !in stringtable) {
			// Create table entry
			try {
				stringtable[index] = (input[index.offset .. index.offset +
				  index.characters.length] == index.characters);
			} catch (OutOfInputException e) {
				stringtable[index] = false;
			}
		}

		return stringtable[index]; // Return memoized result
	}

	/* Thin wrapper for array access indexing for unadorned raw strings */
	bool opIndex(size_t offset, dstring characters) {
		return opIndex(StringIndex(offset, characters));
	}

	/* Thin wrapper for array access indexing for unadorned raw characters */
	bool opIndex(size_t offset, dchar character) {
		try {
			if (input[offset] == character) {
				return true;
			}
		} catch (OutOfInputException e) {} // Fall through

		return false;
	}

	/* Thin wrapper for attempting to match a nonterminal and testing its
	 * success */
	bool matchNonterminal(out Derivation deriv, size_t offset, Nonterminal type, byte precedence) {
		deriv = this[offset, type, 0];
		return deriv.success;
	}

	bool matchCharacter(out Derivation deriv, size_t offset, dchar character) {
		try {
			if (input[offset] == character) {
				deriv = new Derivation(offset + 1, character);
			}
		} catch (OutOfInputException e) {} // Fall through

		deriv = Derivation.init; // Failure
		return false;
	}
}

/* Primitive function for matching a single unadorned character */
bool matchCharacter(out Derivation deriv, DerivsTable table, size_t offset, dchar character) {
	try {
		if (table.input[offset] == character) {
			deriv = new Derivation(offset + 1, table.input[offset]);
			return true;
		}
	} catch (OutOfInputException e) { // Fall through
	}

	deriv = Derivation.init; // Failure
	return false;
}

Derivation declaration(size_t offset, DerivsTable table, CallStack stack = null) {
	Derivation part1, part2, part3;

	// Declaration = Identifier '=' Rule
	if (table.matchNonterminal(part1, offset, Nonterminal.identifier, 0) &&
	  matchCharacter(part2, table, part1.offset, '=') &&
	  table.matchNonterminal(part3, part2.offset, Nonterminal.rule, 0)) {
		return new Derivation(part3.offset);
	}

	return Derivation.init; // Failure
}

Derivation rule(size_t offset, DerivsTable table, CallStack stack) in {
	assert(stack !is null);
} body {
	Derivation part1, part2, part3;
	offset = skipwhitespace(offset, table);
	switch (stack.precedence) {
	case 0:
		// Rule = Rule "/<" Rule %l
		if ((part1 = table[offset, Nonterminal.rule, 0]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "/<" &&
		  (part3 = table[part2.offset, Nonterminal.rule, 1]).success) {
			return new Derivation(part3.offset);
		}
		stack.precedence++;
		goto case;
	case 1:
		// Rule = Rule '/' Rule %l
		if ((part1 = table[offset, Nonterminal.rule, 1]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "/" &&
		  (part3 = table[part2.offset, Nonterminal.rule, 2]).success) {
			return new Derivation(part3.offset);
		}

		return Derivation.init;

	default: assert(0);
	}
}

