const std = @import("std");
const tokens = " ()\"\n";
pub const TokenType = enum { invalid, identifier, string_literal, lparen, rparen, semicolon, newline, eof };
pub fn TokenType_to_str(token_type: TokenType) []const u8 {
    return switch (token_type) {
        .invalid => "Invalid",
        .identifier => "Indentifier",
        .string_literal => "String Literal",
        .lparen => "Left Parenthesis",
        .rparen => "Right Parenthesis",
        .semicolon => "Semicolon",
        .newline => "New Line",
    };
}
pub const Token = struct {
    type: TokenType,
    content: []const u8,
};

pub fn is_special(c: u8) bool {
    for (tokens) |d| {
        if (d == c) return true;
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
                switch (c) {
                    '(' => {
                        return .{ .type = .lparen, .content = "(" };
                    },
                    ')' => {
                        return .{ .type = .rparen, .content = ")" };
                    },
                    ';' => {
                        return .{ .type = .semicolon, .content = ";" };
                    },
                    '"' => {
                        if (tok_type == .string_literal) {
                            return .{ .type = .string_literal, .content = self.code[self.idx + 1 .. i] };
                        } else {
                            tok_type = .string_literal;
                        }
                    },
                    ' ' => {},
                    '\n' => {
                        return .{ .type = .newline, .content = "\\n" };
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
    pub fn peak(self: *Lexer) !?Token {
        const idx = self.idx;
        defer self.idx = idx;
        return self.consume();
    }
    pub fn expect(self: *Lexer, expected: TokenType) !?Token {
        const tok = try self.consume();
        return if (tok.type == expected) tok else null;
    }
    pub fn expect_peak(self: *Lexer, expected: ?TokenType) !?Token {
        const tok = try self.peak();
        return if (tok.type == expected) tok else null;
    }

    pub fn next(self: *Lexer) !?Token {
        const tok = try self.consume();
        if (tok.type == .eof) return null else return tok;
    }
    pub fn consume_until(self: *Lexer, expected: TokenType) !?Token {
        while (try self.next()) |tok|{
            if (tok.type == expected) return tok;
        }
        if (expected == .eof) return .{ .type = .eof, .content = "EOF" };
        return null;
    }
};

pub fn printLexer(l: *Lexer) !void {
    while (try l.next()) |tok| {
        std.debug.print("Type: {s}, Content: {s}\n", .{TokenType_to_str(tok.type), tok.content});
    }
}
