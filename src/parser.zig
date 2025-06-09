const lexer = @import("lexer.zig");
const std = @import("std");
pub const Parser = struct {
    alloc: std.mem.Allocator,
    l: *lexer.Lexer,
    irCode: std.ArrayList(u8) = undefined,
    irMain: std.ArrayList(u8) = undefined,
    irPreamble: std.ArrayList(u8) = undefined,
    stringID: u32 = 0,
    curr_line: []u8 = undefined,

    pub fn new(alloc: std.mem.Allocator, l: *lexer.Lexer) Parser {
        return .{ .alloc = alloc, .l = l};
    }
    pub fn parse(self: *Parser) !std.ArrayList(u8) {
        self.irCode = std.ArrayList(u8).init(self.alloc);
        self.irMain = std.ArrayList(u8).init(self.alloc); // TODO: abstract irMain to a generic define function
        self.irPreamble = std.ArrayList(u8).init(self.alloc);
        defer self.irMain.deinit();
        defer self.irPreamble.deinit();
        var tok: lexer.Token = undefined;
        while (true) {
            tok = (try self.l.consume_until(.identifier)) orelse break;
            if (std.mem.eql(u8, tok.content, "println")) {
              _ = try self.l.expect(.lparen);  
              const id = try self.register_str(); // this expects a string so we dont need to
              _ = try self.l.expect(.rparen);  
              _ = try self.l.expect(.semicolon);  
              self.curr_line = try std.fmt.allocPrint(self.alloc, "  call $printf(l $str{d})\n",.{id});
              try self.irMain.appendSlice(self.curr_line);
              self.alloc.free(self.curr_line);
              self.stringID += 1;
            }
        }
        try self.irCode.appendSlice(self.irPreamble.items);
        try self.irCode.appendSlice("export function w $main() {\n");
        try self.irCode.appendSlice("@start\n");
        try self.irCode.appendSlice(self.irMain.items);
        try self.irCode.appendSlice("  ret 0\n");
        try self.irCode.appendSlice("}\n");
        return self.irCode;
    }

    fn register_str(self: *Parser) !u32 {
        defer self.stringID += 1; 
        const tok = try self.l.expect(.string_literal) orelse return error.ExpectedString;
        self.curr_line = try std.fmt.allocPrint(self.alloc, "data $str{d} = {{ b \"{s}\\n\", b 0 }}\n",.{self.stringID, tok.content});
        try self.irPreamble.appendSlice(self.curr_line);
        self.alloc.free(self.curr_line);
        return self.stringID;
    }
};
