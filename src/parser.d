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
	_function = &._function,
	identifier = &.identifier,
	rawcode = &.rawcode,
	literal = &.literal,
	characterlit = &.characterlit,
	stringlit = &.stringlit,
	symbol = &.symbol,
	whitespace = &.whitespace,
	linecomment = &.linecomment,
	blockcomment = &.blockcomment,
	nestingcomment = &.nestingcomment,
	lineterminator = &.lineterminator
}

/* Which nonterminals may be (possibly indirectly) left recursive, precomputed
 */
enum Ntlrecursive : bool {
	declaration = false,
	rule = true,
	_function = false,
	identifier = false,
	rawcode = false,
	literal = false,
	characterlit = false,
	stringlit = false,
	symbol = false,
	whitespace = false,
	linecomment = false,
	blockcomment = false,
	nestingcomment = false,
	lineterminator = false
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
		stack.precedence++;
		goto case;
	case 2:
		// Rule = Rule '|' Rule %l
		if ((part1 = table[offset, Nonterminal.rule, 2]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "|" &&
		  (part3 = table[part2.offset, Nonterminal.rule, 3]).success) {
			return new Derivation(part3.offset);
		}
		stack.precedence++;
		goto case;
	case 3:
		// Rule = Rule Function %n
		if ((part1 = table[offset, Nonterminal.rule, 4]).success &&
		  (part2 = table[part1.offset, Nonterminal._function, 0]).success) {
			return new Derivation(part2.offset);
		}
		stack.precedence++;
		goto case;
	case 4:
		// Rule = Rule Rule %l
		if ((part1 = table[offset, Nonterminal.rule, 4]).success &&
		  (part2 = table[part1.offset, Nonterminal.rule, 5]).success) {
			return new Derivation(part2.offset);
		}
		stack.precedence++;
		goto case;
	case 5:
		// Rule = '&' Rule %n
		if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "&" &&
		  (part2 = table[part1.offset, Nonterminal.rule, 6]).success) {
			return new Derivation(part2.offset);
		}
		// Rule = '!' Rule %n
		else if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "!" &&
		  (part2 = table[part1.offset, Nonterminal.rule, 6]).success) {
			return new Derivation(part2.offset);
		}
		// Rule = '&' Function %n
		else if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "&" &&
		  (part2 = table[part1.offset, Nonterminal._function, 0]).success) {
			return new Derivation(part2.offset);
		}
		stack.precedence++;
		goto case;
	case 6:
		// Rule = Rule '*' %n
		if ((part1 = table[offset, Nonterminal.rule, 7]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "*") {
			return new Derivation(part2.offset);
		}
		// Rule = Rule '+' %n
		else if ((part1 = table[offset, Nonterminal.rule, 7]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "+") {
			return new Derivation(part2.offset);
		}
		// Rule = Rule '?' %n
		else if ((part1 = table[offset, Nonterminal.rule, 7]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "?") {
			return new Derivation(part2.offset);
		}
		stack.precedence++;
		goto case;
	case 7:
		// Rule = '(' Rule ')' %p
		if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "(" &&
		  (part2 = table[part1.offset, Nonterminal.rule, 0]).success &&
		  (part3 = table[part2.offset, Nonterminal.symbol, 0]).success &&
		  part3._dstring == ")") {
			return new Derivation(part3.offset);
		}
		// Rule = Identifier
		else if ((part1 = table[offset, Nonterminal.identifier, 0]).success) {
			return part1;
		}
		// Rule = Literal
		else if ((part1 = table[offset, Nonterminal.literal, 0]).success) {
			return part1;
		}
		// Rule = '(' ')'
		else if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "(" &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == ")") {
			return new Derivation(part2.offset);
		}
		return Derivation.init;
	default: assert(0);
	}
}

Derivation _function(size_t offset, DerivsTable table, CallStack stack = null) {
	Derivation part1, part2;
	// Function = '@' Identifier
	if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
	  part1._dstring == "@" &&
	  (part2 = table[part1.offset, Nonterminal.identifier, 0]).success) {
		return new Derivation(part2.offset);
	}
	// Function = Rawcode
	else if ((part1 = table[offset, Nonterminal.rawcode, 0]).success) {
		return part1;
	}
	return Derivation.init;
}

Derivation identifier(size_t offset, DerivsTable table, CallStack stack = null) {
	size_t end;
	dchar cur;
	try {
		offset = skipwhitespace(offset, table);
		cur = table.input[offset];
		if (isAlpha(cur) || cur == '_') {
			try {
				end = offset + 1;
				cur = table.input[end];
				while (isAlphaNum(cur) || cur == '_') {
					end++;
					cur = table.input[end];
				}
				return new Derivation(end, table.input[offset .. end]);
			} catch (OutOfInputException e) {
				return new Derivation(end, table.input[offset .. end]);
			}
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation rawcode(size_t offset, DerivsTable table, CallStack stack = null) {
	static size_t nestedblock(size_t offset, DerivsTable table) {
		dchar cur;
		try {
			cur = table.input[offset];
			while (cur != '}') {
				if (cur == '{') {
					offset = nestedblock(offset + 1, table);
				} else {
					offset++;
				}
				cur = table.input[offset];
			}
			return offset + 1;
		} catch (OutOfInputException e) {
			// syntax error: unterminated block
			return -1;
		}
		assert(0);
	}

	size_t end;
	try {
		offset = skipwhitespace(offset, table);
		if (table.input[offset] == '{') {
			end = nestedblock(offset + 1, table);
			return new Derivation(end, table.input[offset .. end]);
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation literal(size_t offset, DerivsTable table, CallStack stack = null) {
	Derivation part1;
	// Literal = Characterlit
	if ((part1 = table[offset, Nonterminal.characterlit, 0]).success) {
		return part1;
	}
	// Literal = Stringlit
	else if ((part1 = table[offset, Nonterminal.stringlit, 0]).success) {
		return part1;
	}
	return Derivation.init;
}

Derivation characterlit(size_t offset, DerivsTable table, CallStack stack = null) {
	size_t end;
	try {
		offset = skipwhitespace(offset, table);
		if (table.input[offset] == '\'') {
			if (table.input[offset + 1] == '\\') {
				// any valid escape sequence
				if ((end = escapechar(offset + 1, table)) != offset + 1 && table.input[end] == '\'') {
					return new Derivation(end + 1, table.input[offset .. end + 1]);
				} else {
					return Derivation.init;
				}
			} else if (table.input[offset + 1] == '\'') {
				// syntax error, empty character literal
				return Derivation.init;
			} else if (table.input[offset + 2] == '\'') {
				// any unicode character
				return new Derivation(offset + 3, table.input[offset .. offset + 3]);
			}
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation stringlit(size_t offset, DerivsTable table, CallStack stack = null) {
	try {
	} catch (OutOfInputException e) {
	}
	return Derivation.init;
}

size_t escapechar(size_t offset, DerivsTable table) {
	try {
		switch (table.input[offset + 1]) {
		case '\'':
		case '\"':
		case '?':
		case '\\':
		case 'a':
		case 'b':
		case 'f':
		case 'n':
		case 'r':
		case 't':
		case 'v':
			return offset + 2;
		case '0': .. case '7': // \Octal, \OctalOctal, \OctalOctalOctal
			try {
				if (isOctalDigit(table.input[offset + 2])) {
					try {
						if (isOctalDigit(table.input[offset + 3])) {
							return offset + 4;
						}
						return offset + 3;
					} catch (OutOfInputException e) {
						return offset + 3;
					}
				}
				return offset + 2;
			} catch (OutOfInputException e) {
				return offset + 2;
			}
		case 'x': // \xHexHex
			if (isHexDigit(table.input[offset + 2]) && isHexDigit(table.input[offset + 3])) {
				return offset + 4;
			}
			return offset;
		case 'u': // \uHexHexHexHex
			foreach (i; offset + 2 .. offset + 6) {
				if (!isHexDigit(table.input[i])) {
					return offset;
				}
			}
			return offset + 6;
		case 'U': // \UHexHexHexHexHexHexHexHex
			foreach (i; offset + 2 .. offset + 10) {
				if (!isHexDigit(table.input[i])) {
					return offset;
				}
			}
			return offset + 10;
		default: return offset;
		}
	} catch (OutOfInputException e) {
		return offset;
	}
}

Derivation symbol(size_t offset, DerivsTable table, CallStack stack = null) {
	try {
		offset = skipwhitespace(offset, table);
		switch (table.input[offset]) {
		case '!':
		case '#':
		case '$':
		case '%':
		case '&':
		case '(':
		case ')':
		case '*':
		case '+':
		case '.':
			return new Derivation(offset + 1, table.input[offset .. offset + 1]);
		case '/':
			try {
				if (table.input[offset + 1] == '<') {
					return new Derivation(offset + 2, table.input[offset .. offset + 2]);
				} else {
					return new Derivation(offset + 1, table.input[offset .. offset + 1]);
				}
			} catch (OutOfInputException e) {
				return new Derivation(offset + 1, table.input[offset .. offset + 1]);
			}
		case '<':
		case '=':
		case '?':
		case '@':
		case '[':
		case ']':
		case '{':
		case '|':
		case '}':
			return new Derivation(offset + 1, table.input[offset .. offset + 1]);
		default: return Derivation.init;
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
}

Derivation whitespace(size_t offset, DerivsTable table, CallStack stack = null) {
	size_t end = offset;
	Derivation part1;
	try {
		while ((isWhite(table.input[offset]) && (end++, 1)) ||
		  ((part1 = linecomment(end, table)).success && (end = part1.offset, 1)) ||
		  ((part1 = blockcomment(end, table)).success && (end = part1.offset, 1)) ||
		  ((part1 = nestingcomment(end, table)).success && (end = part1.offset, 1))) {};
	} catch (OutOfInputException e) {
		if (offset == end) {
			return Derivation.init;
		} else {
			return new Derivation(end, table.input[offset .. end]);
		}
	}
	if (offset == end) {
		return Derivation.init;
	} else {
		return new Derivation(end, table.input[offset .. end]);
	}
}

size_t skipwhitespace(size_t offset, DerivsTable table) {
	Derivation output = table[offset, Nonterminal.whitespace, 0];
	if (output.success) {
		return output.offset;
	} else {
		return offset;
	}
}

Derivation linecomment(size_t offset, DerivsTable table, CallStack stack = null) {
	size_t end;
	dchar cur;
	try {
		if (table.input[offset] == '/' && table.input[offset + 1] == '/') {
			try {
				end = offset + 2;
				cur = table.input[end];
				while (cur != '\0' && cur != '\r' && cur != '\n' && cur != '\u2028' && cur != '\u2029') {
					end++;
					cur = table.input[end];
				}
			} catch (OutOfInputException e) {
				return new Derivation(end, table.input[offset .. end]);
			}
			try {
				if (cur == '\r' && table.input[end + 1] == '\n') {
					return new Derivation(end + 2, table.input[offset .. end + 2]);
				} else {
					return new Derivation(end + 1, table.input[offset .. end + 1]);
				}
			} catch (OutOfInputException e) {
				return new Derivation(end + 1, table.input[offset .. end + 1]);
			}
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation blockcomment(size_t offset, DerivsTable table, CallStack stack = null) {
	size_t end;
	dchar cur;
	try {
		if (table.input[offset] == '/' && table.input[offset + 1] == '*') {
			try {
				end = offset + 2;
				cur = table.input[end];
				while (cur != '*' || table.input[end + 1] != '/') {
					offset++;
					cur = table.input[end];
				}
				return new Derivation(end + 2, table.input[offset .. end + 2]);
			} catch (OutOfInputException e) {
				// syntax error: unterminated block comment
				return new Derivation(table.input.available, table.input[offset .. table.input.available]);
			}
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation nestingcomment(size_t offset, DerivsTable table, CallStack stack = null) {
	static size_t nestedcomment(size_t offset, DerivsTable table) {
		dchar cur;
		try {
			cur = table.input[offset];
			while (cur != '+' || table.input[offset + 1] != '/') {
				if (cur == '/' && table.input[offset + 1] == '+') {
					offset = nestedcomment(offset + 2, table);
				} else {
					offset++;
				}
				cur = table.input[offset];
			}
			return offset + 2;
		} catch (OutOfInputException e) {
			// syntax error: unterminated nesting comment
			return offset;
		}
		assert(0);
	}

	size_t end;
	try {
		if (table.input[offset] == '/' && table.input[offset + 1] == '+') {
			end = nestedcomment(offset + 2, table);
			return new Derivation(end, table.input[offset .. end]);
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation lineterminator(size_t offset, DerivsTable table, CallStack stack = null) {
	try {
		if (table.input[offset] == '\r') {
			try {
				if (table.input[offset + 1] == '\n') {
					return new Derivation(offset + 2, table.input[offset .. offset + 2]);
				} else {
					return new Derivation(offset + 1, table.input[offset .. offset + 1]);
				}
			} catch (OutOfInputException e) {
				return new Derivation(offset + 1, table.input[offset .. offset + 1]);
			}
		} else if (table.input[offset] == '\n' || table.input[offset] == '\u2028' || table.input[offset] == '\u2029') {
			return new Derivation(offset + 1, table.input[offset .. offset + 1]);
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

