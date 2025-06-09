const lexer = @import("lexer.zig");
const std = @import("std");
pub const Parser = struct {
    alloc: std.mem.Allocator,
    l: *lexer.Lexer,
    irCode: std.ArrayList(u8) = undefined,
    irPreamble: std.ArrayList(u8) = undefined,
    stringID: u32 = 0,

    pub fn new(alloc: std.mem.Allocator, l: *lexer.Lexer) Parser {
        return .{ .alloc = alloc, .l = l };
    }
    pub fn parse(self: *Parser) !std.ArrayList(u8) {
        self.irCode = std.ArrayList(u8).init(self.alloc);
        self.irPreamble = std.ArrayList(u8).init(self.alloc);
        defer self.irPreamble.deinit();
        while (try self.l.consume_until(.identifier)) |tok| {
            if (std.mem.eql(u8, tok.content, "fn")) {
                const irFunc = try self.register_fn();
                try self.irCode.appendSlice(irFunc.items);
                irFunc.deinit();
            }
        }
        try self.irCode.appendSlice(self.irPreamble.items);

        return self.irCode;
    }

    fn register_fn(self: *Parser) !std.ArrayList(u8) {
        var irFunc = std.ArrayList(u8).init(self.alloc); // TODO: abstract irMain to a generic define function
        _ = try self.l.expect(.space);
        const tok = (try self.l.expect(.identifier)) orelse return error.ExpectedIdentifier;
        var line: []u8 = try std.fmt.allocPrint(self.alloc, "export function w ${s}() {{\n", .{tok.content});
        try irFunc.appendSlice(line);
        self.alloc.free(line);
        // TODO: add arguments
        _ = try self.l.expect(.lparen);
        _ = try self.l.expect(.rparen);
        _ = try self.l.expect(.space);
        _ = try self.l.expect(.lbracket);
        try irFunc.appendSlice("@start\n");
        while (try self.l.peak_next()) |t| {
            _ = t;
            line = self.register_expr() catch |e| {
                if (e == error.EndOfFunction) {
                    break;
                }
                irFunc.deinit();
                return e;
            };
            defer self.alloc.free(line);
            try irFunc.appendSlice(line);
            if ((try self.l.peak()).type == .rbracket) break;
        }
        try irFunc.appendSlice("  ret 0\n");
        try irFunc.appendSlice("}\n");
        return irFunc;
    }

    fn register_expr(self: *Parser) ![]u8 {
        while (try self.l.next()) |tok| {
            if (tok.type == .space or tok.type == .newline) continue;
            if (tok.type == .rbracket) return error.EndOfFunction;
            if (std.mem.eql(u8, tok.content, "println")) {
                _ = try self.l.expect(.lparen);
                const id = try self.register_str(); // this expects a string so we dont need to
                _ = try self.l.expect(.rparen);
                _ = try self.l.expect(.semicolon);
                return try std.fmt.allocPrint(self.alloc, "  call $printf(l $str{d})\n", .{id});
            }
        }
        return error.InvalidExpr;
    }

    fn register_str(self: *Parser) !u32 {
        defer self.stringID += 1;
        const tok = (try self.l.expect(.string_literal)) orelse return error.ExpectedString;
        const line = try std.fmt.allocPrint(self.alloc, "data $str{d} = {{ b \"{s}\\n\", b 0 }}\n", .{ self.stringID, tok.content });
        try self.irPreamble.appendSlice(line);
        self.alloc.free(line);
        return self.stringID;
    }
};
