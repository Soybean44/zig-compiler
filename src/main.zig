const std = @import("std");
const lexer = @import("lexer.zig");

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
    std.debug.print("Program: {s}\n", .{txt});

    var l: lexer.Lexer = .{ .code = txt, .idx = 0 };
    std.debug.print("Tok: {s}\n", .{l.consume().?});
    var expct: []const u8 = "(";
    std.debug.print("Expecting {s}\n", .{expct});
    std.debug.print("Tok: {s}\n", .{try l.expect(expct)});
    expct = "\"";
    std.debug.print("Expecting {s}\n", .{expct});
    std.debug.print("Tok: {s}\n", .{try l.expect(expct)});
    std.debug.print("Tok: {s}\n", .{l.consume().?});
    std.debug.print("Tok: {s}\n", .{l.consume().?});
    std.debug.print("Tok: {s}\n", .{l.consume().?});
    expct = "\"";
    std.debug.print("Expecting {s}\n", .{expct});
    std.debug.print("Tok: {s}\n", .{try l.expect(expct)});
    expct = ")";
    std.debug.print("Expecting {s}\n", .{expct});
    std.debug.print("Tok: {s}\n", .{try l.expect(expct)});
    expct = "\n";
    std.debug.print("Expecting \\n\n", .{});
    _ = try l.expect(expct);
    std.debug.print("Tok: \\n\n", .{});
}
