const std = @import("std");
const lexer = @import("lexer.zig");
const Parser = @import("parser.zig").Parser;

fn read_file(alloc: std.mem.Allocator, filename: []const u8) ![]const u8 {
    var txtFile = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer txtFile.close();
    return try txtFile.readToEndAlloc(alloc, std.math.maxInt(usize) - 1);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("MEMORY LEAK");
    }

    // Argument Parsing
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.next(); // Program name

    // File reading
    const filename = args.next() orelse return error.NoFile;
    const txt = try read_file(alloc, filename);
    defer alloc.free(txt);
    std.debug.print("Program:\n{s}\n", .{txt});

    var l: lexer.Lexer = .{ .code = txt, .idx = 0 };
    // try lexer.printLexer(&l);
    var parser = Parser.new(alloc, &l);
    const irCode = try parser.parse();
    defer irCode.deinit();
    var irFile = try std.fs.cwd().createFile("out.ssa", .{});
    defer irFile.close();
    try irFile.writeAll(irCode.items);

}
