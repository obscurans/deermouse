/* Copyright (C) 2014 Jeffrey Tsang. All rights reserved. See /LICENCE.md */

import interfaces;
import std.ascii;

private:
enum Nonterminal : Derivation function(size_t, byte, DerivsTable) {
	declaration = &.declaration,
	rule = &.rule,
	_function = &._function,
	identifier = &.identifier,
	rawcode = &.rawcode,
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
	Derivation[Index] memotable;

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
}

Derivation declaration(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	Derivation part1, part2, part3;
	// Declaration = Identifier '=' Rule
	if ((part1 = table[offset, Nonterminal.identifier, 0]).success &&
	  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
	  part2._dstring == "=" &&
	  (part3 = table[part2.offset, Nonterminal.rule, 0]).success) {
		return Derivation(part3.offset);
	}
	return Derivation();
}

Derivation rule(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence >= 0 && precedence < 8);
} body {
	Derivation part1, part2, part3;
	offset = skipwhitespace(offset, table);
	switch (precedence) {
	case 0:
		// Rule = Rule "/<" Rule %l
		if ((part1 = table[offset, Nonterminal.rule, -1]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "/<" &&
		  (part3 = table[part2.offset, Nonterminal.rule, -1]).success) {
			return Derivation(part3.offset);
		}
		goto case;
	case 1:
		// Rule = Rule '/' Rule %l
		if ((part1 = table[offset, Nonterminal.rule, -1]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "/" &&
		  (part3 = table[part2.offset, Nonterminal.rule, -1]).success) {
			return Derivation(part3.offset);
		}
		goto case;
	case 2:
		// Rule = Rule '|' Rule %l
		if ((part1 = table[offset, Nonterminal.rule, -1]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "|" &&
		  (part3 = table[part2.offset, Nonterminal.rule, -1]).success) {
			return Derivation(part3.offset);
		}
		goto case;
	case 3:
		// Rule = Rule Function %n
		if ((part1 = table[offset, Nonterminal.rule, 4]).success &&
		  (part2 = table[part1.offset, Nonterminal._function, 0]).success) {
			return Derivation(part2.offset);
		}
		goto case;
	case 4:
		// Rule = '&' Rule %n
		if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "&" &&
		  (part2 = table[part1.offset, Nonterminal.rule, 5]).success) {
			return Derivation(part2.offset);
		}
		// Rule = '!' Rule %n
		else if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "!" &&
		  (part2 = table[part1.offset, Nonterminal.rule, 5]).success) {
			return Derivation(part2.offset);
		}
		// Rule = '&' Function %n
		else if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "&" &&
		  (part2 = table[part1.offset, Nonterminal._function, 0]).success) {
			return Derivation(part2.offset);
		}
		goto case;
	case 5:
		// Rule = Rule '*' %n
		if ((part1 = table[offset, Nonterminal.rule, 6]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "*") {
			return Derivation(part2.offset);
		}
		// Rule = Rule '+' %n
		else if ((part1 = table[offset, Nonterminal.rule, 6]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "+") {
			return Derivation(part2.offset);
		}
		// Rule = Rule '?' %n
		else if ((part1 = table[offset, Nonterminal.rule, 6]).success &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == "?") {
			return Derivation(part2.offset);
		}
		goto case;
	case 6:
		// Rule = Rule Rule %l
		if ((part1 = table[offset, Nonterminal.rule, -1]).success &&
		  (part2 = table[part1.offset, Nonterminal.rule, -1]).success) {
			return Derivation(part2.offset);
		}
		goto case;
	case 7:
		// Rule = '(' Rule ')' %p
		if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "(" &&
		  (part2 = table[part1.offset, Nonterminal.rule, 0]).success &&
		  (part3 = table[part2.offset, Nonterminal.symbol, 0]).success &&
		  part3._dstring == ")") {
			return Derivation(part3.offset);
		}
		// Rule = Identifier
		else if ((part1 = table[offset, Nonterminal.identifier, 0]).success) {
			return Derivation(part1.offset);
		}
		// Rule = Literal
		else if ((part1 = table[offset, Nonterminal.literal, 0]).success) {
			return Derivation(part1.offset);
		}
		// Rule = '(' ')'
		else if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
		  part1._dstring == "(" &&
		  (part2 = table[part1.offset, Nonterminal.symbol, 0]).success &&
		  part2._dstring == ")") {
			return Derivation(part2.offset);
		}
		return Derivation();
	default: assert(0);
	}
}

Derivation _function(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	Derivation part1, part2;
	// Function = '@' Identifier
	if ((part1 = table[offset, Nonterminal.symbol, 0]).success &&
	  part1._dstring == "@" &&
	  (part2 = table[part1.offset, Nonterminal.identifier, 0]).success) {
		return Derivation(part2.offset);
	}
	// Function = Rawcode
	else if ((part1 = table[offset, Nonterminal.rawcode, 0]).success) {
		return Derivation(part1.offset);
	}
	return Derivation();
}

Derivation identifier(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	offset = skipwhitespace(offset, table);
	return Derivation();
}

Derivation rawcode(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
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
			return Derivation(end, table.input[offset .. end]);
		}
	} catch (OutOfInputException e) {
		return Derivation();
	}
	return Derivation();
}

Derivation literal(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	return Derivation();
}

Derivation symbol(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
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
			return Derivation(offset + 1, table.input[offset .. offset + 1]);
		case '/':
			if (table.input[offset + 1] == '<') {
				return Derivation(offset + 2, table.input[offset .. offset + 2]);
			} else {
				return Derivation(offset + 1, table.input[offset .. offset + 1]);
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
			return Derivation(offset + 1, table.input[offset .. offset + 1]);
		default: return Derivation();
		}
	} catch (OutOfInputException e) {
		return Derivation();
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
			return Derivation();
		} else {
			return Derivation(end, table.input[offset .. end]);
		}
	}
	if (offset == end) {
		return Derivation();
	} else {
		return Derivation(end, table.input[offset .. end]);
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

Derivation linecomment(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
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
				return Derivation(end, table.input[offset .. end]);
			}
			try {
				if (cur == '\r' && table.input[end + 1] == '\n') {
					return Derivation(end + 2, table.input[offset .. end + 2]);
				} else {
					return Derivation(end + 1, table.input[offset .. end + 1]);
				}
			} catch (OutOfInputException e) {
				return Derivation(end + 1, table.input[offset .. end + 1]);
			}
		}
	} catch (OutOfInputException e) {
		return Derivation();
	}
	return Derivation();
}

Derivation blockcomment(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
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
				return Derivation(end + 2, table.input[offset .. end + 2]);
			} catch (OutOfInputException e) {
				// syntax error: unterminated block comment
				return Derivation(table.input.available, table.input[offset .. table.input.available]);
			}
		}
	} catch (OutOfInputException e) {
		return Derivation();
	}
	return Derivation();
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
			return offset;
		}
		assert(0);
	}

	size_t end;
	try {
		if (table.input[offset] == '/' && table.input[offset + 1] == '+') {
			end = nestedcomment(offset + 2, table);
			return Derivation(end, table.input[offset .. end]);
		}
	} catch (OutOfInputException e) {
		return Derivation();
	}
	return Derivation();
}

Derivation lineterminator(size_t offset, byte precedence, DerivsTable table) in {
	assert(precedence == 0);
} body {
	try {
		if (table.input[offset] == '\r') {
			try {
				if (table.input[offset + 1] == '\n') {
					return Derivation(offset + 2, table.input[offset .. offset + 2]);
				} else {
					return Derivation(offset + 1, table.input[offset .. offset + 1]);
				}
			} catch (OutOfInputException e) {
				return Derivation(offset + 1, table.input[offset .. offset + 1]);
			}
		} else if (table.input[offset] == '\n' || table.input[offset] == '\u2028' || table.input[offset] == '\u2029') {
			return Derivation(offset + 1, table.input[offset .. offset + 1]);
		}
	} catch (OutOfInputException e) {
		return Derivation();
	}
	return Derivation();
}

