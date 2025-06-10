const std = @import("std");
const tokens = " #;(){}\"\n\t";
pub const TokenType = enum { invalid, identifier, string_literal, lparen, rparen, semicolon, eof, wspace, lbracket, rbracket, comment};
pub fn TokenType_to_str(token_type: TokenType) []const u8 {
    return switch (token_type) {
        .invalid => "Invalid",
        .identifier => "Identifier",
        .string_literal => "String Literal",
        .lparen => "Left Parenthesis",
        .rparen => "Right Parenthesis",
        .semicolon => "Semicolon",
        .wspace => "White Space",
        .eof => "EOF",
        .lbracket => "{",
        .rbracket => "}",
        .comment => "Comment",
    };
}

pub fn print_whitespace(c: u8) ![]const u8 {
    return switch (c) {
        ' ' => "Space",
        '\n' => "Newline",
        '\t' => "Tab",
        else => error.InvalidWhitespaceChar
    };
}

pub const Token = struct {
    type: TokenType,
    content: []const u8,
    pub fn pretty_print(self: *const Token) void {
        std.debug.print("Type: {s}, Content: {s}\n", .{ TokenType_to_str(self.type), self.content });
    }
};

pub fn is_special(c: u8) bool {
    for (tokens) |d| {
        if (d == c) {
            return true;
        }
    }
    return false;
}

pub const Lexer = struct {
    code: []const u8,
    idx: usize,
    pub fn consume(self: *Lexer) !Token {
        var i = self.idx;
        if (i == self.code.len) return .{ .type = .eof, .content = "EOF" };
        var tok_type = TokenType.invalid;
        defer if (i < self.code.len) {
            if (tok_type != .identifier) {
                self.idx = i + 1;
            } else {
                self.idx = i;
            }
        };
        var c: u8 = 0;
        while (i < self.code.len) {
            c = self.code[i];
            if (is_special(c)) {
                if (tok_type == .identifier) {
                    return .{ .type = .identifier, .content = self.code[self.idx..i] };
                }
                else if (tok_type == .string_literal) {
                    if (c == '"') {
                        return .{ .type = .string_literal, .content = self.code[self.idx + 1 .. i] };
                    } 
                    i += 1;
                    continue;
                }
                switch (c) {
                    '(' => {
                        return .{ .type = .lparen, .content = "(" };
                    },
                    ')' => {
                        return .{ .type = .rparen, .content = ")" };
                    },
                    '{' => {
                        return .{ .type = .lbracket, .content = "{" };
                    },
                    '}' => {
                        return .{ .type = .rbracket, .content = "}" };
                    },
                    ';' => {
                        return .{ .type = .semicolon, .content = ";" };
                    },
                    '"' => {
                        tok_type = .string_literal;
                    },
                    '#' => {
                        return .{ .type = .comment, .content = "#" };
                    },
                    ' ', '\n', '\t' => {
                        return .{ .type = .wspace, .content = try print_whitespace(c) };
                    },
                    else => {
                        std.debug.print("c: {c}\n", .{c});
                        return error.UnexpectedToken;
                    },
                }
            } else if (i == self.idx and tok_type == .invalid) {
                tok_type = .identifier;
            } else {}
            i += 1;
        }
        if (tok_type == .identifier) {
            return .{ .type = .identifier, .content = self.code[self.idx..i] };
        } else return error.UnexpectedEOF;
    }

    pub fn peak(self: *Lexer) !Token {
        const idx = self.idx;
        defer self.idx = idx;
        return self.consume();
    }

    pub fn expect(self: *Lexer, expected: TokenType) !?Token {
        const tok = try self.consume();
        if (tok.type == expected) return tok else {
            std.debug.print("Error: expected {s} but got {s}\n" , .{TokenType_to_str(expected), TokenType_to_str(tok.type)});
            return null;
        }
    }

    pub fn expect_many(self: *Lexer, expected: []const TokenType) !?Token {
        for (expected) |t| {
            if (try self.expect_peak(t) != null) return try self.consume();
        }
        return null;
    }

    pub fn expect_peak(self: *Lexer, expected: TokenType) !?Token {
        const tok = try self.peak();
        return if (tok.type == expected) tok else null;
    }

    pub fn expect_peak_many(self: *Lexer, expected: []const TokenType) !?Token {
        var tok: Token = undefined;
        for (expected) |t| {
            tok = try self.expect_peak(t);
            if (tok != null) return tok;
        }
        return null;
    }

    pub fn next(self: *Lexer) !?Token {
        const tok = try self.consume();
        if (tok.type == .eof) return null else return tok;
    }

    pub fn peak_next(self: *Lexer) !?Token {
        const tok = try self.peak();
        if (tok.type == .eof) return null else return tok;
    }

    pub fn consume_until(self: *Lexer, expected: TokenType) !?Token {
        var tok: ?Token = null;
        while (true) {
            tok = try self.peak();
            if (tok.?.type == .eof) break;
            tok = try self.expect(expected);
            if (tok != null) return tok;
        }
        if (expected == .eof) return .{ .type = .eof, .content = "EOF" };
        return tok;
    }

    pub fn consume_until_many(self: *Lexer, expected: []const TokenType) !?Token {
        var tok: ?Token = null;
        while (true) {
            tok = try self.peak();
            if (tok.?.type == .eof) break;
            tok = try self.expect_many(expected);
            tok.?.pretty_print();
            if (tok != null) return tok;
        }
        for (expected) |t| {
            if (t == .eof) return .{ .type = .eof, .content = "EOF" };
        }
        return tok;
    }

};

pub fn printLexer(l: *Lexer) !void {
    while (try l.next()) |tok| {
        tok.pretty_print();
    }
}
