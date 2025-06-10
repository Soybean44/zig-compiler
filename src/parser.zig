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
        errdefer self.irCode.deinit();
        self.irPreamble = std.ArrayList(u8).init(self.alloc);
        defer self.irPreamble.deinit();
        while (try self.l.next()) |tok| {
            switch (tok.type) {
                .eof => break,
                .comment => continue,
                .wspace => continue,
                .identifier => {
                    if (std.mem.eql(u8, tok.content, "fn")) {
                        const irFunc = try self.register_fn();
                        try self.irCode.appendSlice(irFunc.items);
                        irFunc.deinit();
                    }
                },
                else => return error.InvalidProgram,
            }
        }
        try self.irCode.appendSlice(self.irPreamble.items);
        return self.irCode;
    }

    fn register_fn(self: *Parser) !std.ArrayList(u8) {
        var irFunc = std.ArrayList(u8).init(self.alloc); // TODO: abstract irMain to a generic define function
        errdefer irFunc.deinit();
        _ = try self.l.expect(.wspace);
        const tok = (try self.l.expect(.identifier)) orelse return error.ExpectedIdentifier;
        var line: []u8 = try std.fmt.allocPrint(self.alloc, "export function w ${s}() {{\n", .{tok.content});
        try irFunc.appendSlice(line);
        self.alloc.free(line);
        // TODO: add arguments
        _ = (try self.l.expect(.lparen)).?;
        _ = (try self.l.expect(.rparen)).?;
        _ = (try self.l.expect(.wspace)).?;
        _ = (try self.l.expect(.lbracket)).?;
        try irFunc.appendSlice("@start\n");
        var t: ?lexer.Token = undefined;
        while (true) {
            t = try self.l.consume();
            switch (t.?.type) {
                .wspace => continue,
                .comment => {
                    while (true) {
                        t = try self.l.consume_until_many(&[_]lexer.TokenType{ .wspace, .eof });
                        if (t.?.type == .eof) return error.UnexpectedEOF;
                        if (std.mem.eql(u8, t.?.content, "Newline")) break;
                    }
                    continue;
                },
                .rbracket => break,
                .eof => return error.UnexpectedEOF,
                else => {},
            }
            line = try self.register_expr(t.?);
            defer self.alloc.free(line);
            try irFunc.appendSlice(line);
        }
        try irFunc.appendSlice("  ret 0\n");
        try irFunc.appendSlice("}\n");
        return irFunc;
    }

    fn register_expr(self: *Parser, initial_tok: lexer.Token) ![]u8 {
        var line: ?[]u8 = null;
        switch (initial_tok.type) {
            .identifier => {
                // Manage Function calls, but currently only supports println
                _ = (try self.l.expect(.lparen)).?;
                if (std.mem.eql(u8, initial_tok.content, "println")) {
                    const id = try self.register_str(); // this expects a string so we dont need to
                    line = try std.fmt.allocPrint(self.alloc, "  call $printf(l $str{d})\n", .{id});
                    errdefer self.alloc.free(line);
                }
                _ = (try self.l.expect(.rparen)).?;
            },
            else => return error.InvalidExpr,
        }
        _ = (try self.l.expect(.semicolon)) orelse return error.InvalidExpr;
        return line orelse error.InvalidExpr;
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
