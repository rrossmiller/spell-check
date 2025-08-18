const std = @import("std");
const root = @import("root.zig");
const c = @cImport({
    @cInclude("string.h");
    @cInclude("hunspell.h");
    @cInclude("wn.h");
});

const MAX_WORD_LEN = 100;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const check = gpa.deinit();
        switch (check) {
            .ok => {},
            .leak => std.debug.print("leaked\n", .{}),
        }
    }
    const h = try root.init();
    defer c.Hunspell_destroy(h);

    std.debug.print("Enter words:\n\n", .{});
    const in = std.io.getStdIn().reader();
    const buf = try allocator.alloc(u8, MAX_WORD_LEN);
    defer allocator.free(buf);

    var dual_str = try root.read_c_str(in, buf);
    while (dual_str.c_str.* != 0) {
        if (try root.get_suggestions(allocator, h, dual_str.c_str)) |suggestions| {
            defer allocator.free(suggestions);
            for (suggestions) |s| {
                defer allocator.free(s);
                std.debug.print("{s}\n", .{s});
            }
        }

        // definition
        root.def(dual_str.c_str);
        std.debug.print("\n", .{});
        dual_str = try root.read_c_str(in, buf);
    }
}
