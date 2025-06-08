const std = @import("std");
const tokens = " ()\"\n";
pub const Token = struct {
    delim: u8,
    item: []const u8,
};

pub fn is_token(c: u8) bool {
    for (tokens) |d| {
        if (d == c) return true;
    }
    return false;
}

pub const Lexer = struct {
    code: []const u8,
    idx: usize,
    pub fn consume(self: *Lexer) ?[]const u8 {
        var i = self.idx;
        if (i == self.code.len) return null;
        while (i < self.code.len) {
            if (is_token(self.code[i])) {
                break;
            }
            i += 1;
        }
        var res = self.code[self.idx .. i + 1];
        if (res.len > 1) {
            res = res[0 .. res.len - 1];
        }
        if (self.idx == i) {
            self.idx += 1;
        } else {
            self.idx = i;
        }
        return res;
    }
    pub fn expect(self: *Lexer, expected: []const u8) ![]const u8 {
        const tok = self.consume() orelse return error.UnexpectedEOF;
        if (!std.mem.eql(u8, tok, expected)) {
            return error.UnexpectedToken;
        } else {
            return tok;
        }
    }
};
