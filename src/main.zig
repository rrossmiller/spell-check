const std = @import("std");
const c = @cImport({
    @cInclude("aspell.h");
});
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

    _ = c.new_aspell_config();
    const config = c.new_aspell_config();
    _ = c.aspell_config_replace(config, "lang", "en");
    const possible_err = c.new_aspell_speller(config);

    if (c.aspell_error_number(possible_err) != 0) {
        std.debug.print("Aspell init error: {s}\n\n", .{c.aspell_error_message(possible_err)});
        return;
    }
    const speller: *c.AspellSpeller = c.to_aspell_speller(possible_err).?;

    const MAX_WORD_LEN = 100;
    const buf = try allocator.alloc(u8, MAX_WORD_LEN);
    defer allocator.free(buf);

    std.debug.print("Enter words:\n\n", .{});
    const in = std.io.getStdIn().reader();
    var word = try in.readUntilDelimiter(buf, '\n');
    std.debug.print("\n", .{});
    std.debug.print("**{s}**\n", .{word});
    while (word.len > 0) {
        if (c.aspell_speller_check(speller, word.ptr, @intCast(word.len)) == 1) {
            std.debug.print("✓ \"{s}\" is correct\n", .{word});
        } else {
            std.debug.print("✗ \"{s}\" is incorrect. Suggestions:\n", .{word});
            const suggestions = c.aspell_speller_suggest(speller, word.ptr, @intCast(word.len));
            const elements: *c.AspellStringEnumeration =
                c.aspell_word_list_elements(suggestions).?;
            while (c.aspell_string_enumeration_next(elements)) |suggestion| {
                std.debug.print(" - {s}\n", .{suggestion});
            }

            c.delete_aspell_string_enumeration(elements);
        }
        word = try in.readUntilDelimiter(buf, '\n');
    }

    c.delete_aspell_speller(speller);
    c.delete_aspell_config(config);
}
