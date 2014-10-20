/* Copyright (C) 2014 Jeffrey Tsang. All rights reserved. See /LICENCE.md */

import interfaces;
import std.ascii;

enum Nonterminal : Derivation function(size_t, byte, DerivsTable) {
	declaration = &.declaration,
	rule = &.rule,
	_function = &._function,
	identifier = &.identifier,
	literal = &.literal,
	symbol = &.symbol,
	whitespace = &.whitespace,
	linecomment = &.linecomment,
	blockcomment = &.blockcomment,
	nestingcomment = &.nestingcomment,
	lineterminator = &.lineterminator
}

class DerivsTable {
	struct Index {
		size_t offset;
		Nonterminal type;
		byte precedence;
	}

	InputBuffer input;

	Derivation opIndex(Index index) {
		if (index in memotable) {
			return memotable[index];
		} else {
			return memotable[index] = index.type(index.offset, index.precedence, this);
		}
	}

	Derivation opIndex(size_t offset, Nonterminal type, byte precedence) {
		return opIndex(Index(offset, type, precedence));
	}

private:
	Derivation[Index] memotable;
}

Derivation declaration(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	Derivation part1, part2, part3;
	// Declaration = Identifier '=' Rule
	if ((part1 = identifier(offset, 0, table)).success &&
	  (part2 = symbol(part1.offset, 0, table)).success &&
	  //part2.value == '=' &&
	  (part3 = rule(part2.offset, 0, table)).success) {
		return Derivation(part3.offset, true);
	}
	return Derivation.init;
}

Derivation rule(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence >= 0 && precedence < 999);
} body {
	Derivation part1, part2, part3;
	switch (precedence) {
	case 0:
		// Rule = Rule "/<" Rule %l
		if ((part1 = rule(offset, -1, table)).success &&
		  (part2 = symbol(part1.offset, 0, table)).success &&
		  //part2.value == "/<" &&
		  (part3 = rule(part2.offset, -1, table)).success) {
			return Derivation(part3.offset, true);
		}
		goto case;
	case 1:
		// Rule = Rule '/' Rule %l
		if ((part1 = rule(offset, -1, table)).success &&
		  (part2 = symbol(part1.offset, 0, table)).success &&
		  //part2.value == '/' &&
		  (part3 = rule(part2.offset, -1, table)).success) {
			return Derivation(part3.offset, true);
		}
		goto case;
	case 2:
		// Rule = Rule '|' Rule %l
		if ((part1 = rule(offset, -1, table)).success &&
		  (part2 = symbol(part1.offset, 0, table)).success &&
		  //part2.value == '|' &&
		  (part3 = rule(part2.offset, -1, table)).success) {
			return Derivation(part3.offset, true);
		}
		goto case;
	case 3:
		// Rule = Rule Function %n
		if ((part1 = rule(offset, 4, table)).success &&
		  (part2 = _function(part1.offset, 0, table)).success) {
			return Derivation(part2.offset, true);
		}
		goto case;
	case 4:
		// Rule = '&' Rule %n
		if ((part1 = symbol(offset, 0, table)).success &&
		  //part1.value == '&' &&
		  (part2 = rule(part1.offset, 5, table)).success) {
			return Derivation(part2.offset, true);
		}
		// Rule = '!' Rule %n
		else if ((part1 = symbol(offset, 0, table)).success &&
		  //part1.value == '!' &&
		  (part2 = rule(part1.offset, 5, table)).success) {
			return Derivation(part2.offset, true);
		}
		// Rule = '&' Function %n
		else if ((part1 = symbol(offset, 0, table)).success &&
		  //part1.value == '&' &&
		  (part2 = _function(part1.offset, 0, table)).success) {
			return Derivation(part2.offset, true);
		}
		goto case;
	case 5:
		// Rule = Rule '*' %n
		if ((part1 = rule(offset, 6, table)).success &&
		  (part2 = symbol(part1.offset, 0, table)).success) { //&&
		  //part2.value == '*'
			return Derivation(part2.offset, true);
		}
		// Rule = Rule '+' %n
		else if ((part1 = rule(offset, 6, table)).success &&
		  (part2 = symbol(part1.offset, 0, table)).success) { //&&
		  //part2.value == '+'
			return Derivation(part2.offset, true);
		}
		// Rule = Rule '?' %n
		else if ((part1 = rule(offset, 6, table)).success &&
		  (part2 = symbol(part1.offset, 0, table)).success) { //&&
		  //part2.value == '?'
			return Derivation(part2.offset, true);
		}
		goto case;
	case 6:
		// Rule = Rule Rule %l
		if ((part1 = rule(offset, -1, table)).success &&
		  (part2 = rule(part1.offset, -1, table)).success) {
			return Derivation(part2.offset, true);
		}
		goto case;
	case 7:
		// Rule = '(' Rule ')' %p
		if ((part1 = symbol(offset, 0, table)).success &&
		  //part1.value == '(' &&
		  (part2 = rule(part1.offset, 0, table)).success &&
		  (part3 = symbol(part2.offset, 0, table)).success) { //&&
		  //part3.value == ')'
			return Derivation(part3.offset, true);
		}
		// Rule = Identifier
		else if ((part1 = identifier(offset, 0, table)).success) {
			return Derivation(part1.offset, true);
		}
		// Rule = Literal
		else if ((part1 = literal(offset, 0, table)).success) {
			return Derivation(part1.offset, true);
		}
		// Rule = '(' ')'
		else if ((part1 = symbol(offset, 0, table)).success &&
		  //part1.value == '(' &&
		  (part2 = symbol(offset, 0, table)).success) { //&&
		  //part2.value == ')'
			return Derivation(part2.offset, true);
		}
		return Derivation.init;
	default: assert(0);
	}
}

Derivation _function(size_t offset, byte precedence, DerivsTable table) {
	return Derivation.init;
}

Derivation identifier(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	return Derivation.init;
}

Derivation literal(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	return Derivation.init;
}

Derivation symbol(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	try {
		switch (table.input[offset]) {
		case '!': return Derivation(offset + 1, true);
		case '#': return Derivation(offset + 1, true);
		case '$': return Derivation(offset + 1, true);
		case '%': return Derivation(offset + 1, true);
		case '&': return Derivation(offset + 1, true);
		default: return Derivation.init;
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
}

Derivation whitespace(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	size_t end = offset;
	Derivation part1;
	try {
		while ((isWhite(table.input[offset]) && (end++, 1)) ||
		  ((part1 = linecomment(end, 0, table)).success && (end = part1.offset, 1)) ||
		  ((part1 = blockcomment(end, 0, table)).success && (end = part1.offset, 1)) ||
		  ((part1 = nestingcomment(end, 0, table)).success && (end = part1.offset, 1))) {};
	} catch (OutOfInputException e) {
		if (offset == end) {
			return Derivation.init;
		} else {
			return Derivation(end, true);
		}
	}
	if (offset == end) {
		return Derivation.init;
	} else {
		return Derivation(end, true);
	}
}

size_t skipwhitespace(size_t offset, DerivsTable table) {
	Derivation output = whitespace(offset, 0, table);
	if (output.success) {
		return output.offset;
	} else {
		return offset;
	}
}

Derivation linecomment(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	dchar cur;
	try {
		if (table.input[offset] == '/' && table.input[offset + 1] == '/') {
			try {
				offset += 2;
				cur = table.input[offset];
				while (cur != '\0' && cur != '\r' && cur != '\n' && cur != '\u2028' && cur != '\u2029') {
					offset++;
					cur = table.input[offset];
				}
			} catch (OutOfInputException e) {
				return Derivation(offset, true);
			}
			try {
				if (cur == '\r' && table.input[offset + 1] == '\n') {
					return Derivation(offset + 2, true);
				} else {
					return Derivation(offset + 1, true);
				}
			} catch (OutOfInputException e) {
				return Derivation(offset + 1, true);
			}
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation blockcomment(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	dchar cur;
	try {
		if (table.input[offset] == '/' && table.input[offset + 1] == '*') {
			try {
				offset += 2;
				cur = table.input[offset];
				while (cur != '*' || table.input[offset + 1] != '/') {
					offset++;
					cur = table.input[offset];
				}
				return Derivation(offset + 1, true);
			} catch (OutOfInputException e) {
				// syntax error: unterminated block comment
			}
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation nestingcomment(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
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
			return -1;
		}
		assert(0);
	}

	try {
		if (table.input[offset] == '/' && table.input[offset + 1] == '+') {
			return Derivation(nestedcomment(offset + 2, table), true);
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

Derivation lineterminator(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	try {
		if (table.input[offset] == '\r') {
			try {
				if (table.input[offset + 1] == '\n') {
					return Derivation(offset + 2, true);
				} else {
					return Derivation(offset + 1, true);
				}
			} catch (OutOfInputException e) {
				return Derivation(offset + 1, true);
			}
		} else if (table.input[offset] == '\n' || table.input[offset] == '\u2028' || table.input[offset] == '\u2029') {
			return Derivation (offset + 1, true);
		}
	} catch (OutOfInputException e) {
		return Derivation.init;
	}
	return Derivation.init;
}

