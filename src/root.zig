const std = @import("std");
const c = @cImport({
    @cInclude("string.h");
    @cInclude("hunspell.h");
    @cInclude("wn.h");
});

const SpellcheckError = error{InitError};
pub fn init() !?*c.Hunhandle {
    // hunspell
    const h = c.Hunspell_create("/Users/robrossmiller/Projects/spell-check/en_US.aff", "/Users/robrossmiller/Projects/spell-check/en_US.dic");
    if (h == null) {
        std.debug.print("Hunspell_create failed\n", .{});
        return error.InitError;
    } else {
        std.debug.print("Hunspell initialized\n", .{});
    }

    // wordnet
    const wn_ok = c.wninit();
    if (wn_ok != 0) {
        std.debug.print("wordnet init failed\n", .{});
        return error.InitError;
    } else {
        std.debug.print("WordNet initialized\n", .{});
    }
    return h;
}

pub const DualString = struct {
    str: []u8,
    c_str: [*c]u8,
};

/// Read the line from the reader and return a c string
pub fn read_c_str(reader: std.fs.File.Reader, buf: []u8) !DualString {
    // read from stdin
    const word = try reader.readUntilDelimiter(buf, '\n');

    // Null-terminate for C
    buf[word.len] = 0;
    const c_str: [*c]u8 = buf.ptr;

    return DualString{ .str = word, .c_str = c_str };
}

/// Spellcheck the word and return any suggestions
pub fn get_suggestions(allocator: std.mem.Allocator, h: ?*c.Hunhandle, word: [*c]const u8) !?[][]u8 {
    const ok = c.Hunspell_spell(h, word);
    std.debug.print("> {s}\n", .{word});

    if (0 == ok) {
        var c_suggestions: [*c][*c]u8 = null;
        const n: usize = @intCast(c.Hunspell_suggest(h, &c_suggestions, word));
        const suggestions = try allocator.alloc([]u8, n);
        for (0..n) |i| {
            // convert to zig string
            const s = c_suggestions[i];
            const len = c.strlen(s);
            suggestions[i] = try allocator.dupe(u8, s[0..len]);
        }
        defer c.Hunspell_free_list(h, &c_suggestions, @intCast(n));
        return suggestions;
    }
    return null;
}

const POS = [_]c_int{ c.NOUN, c.VERB, c.ADJ, c.ADV };
/// get the definitions of a word
pub fn def(word: [*c]u8) void {
    for (POS) |pos| {
        var x = c.findtheinfo_ds(word, pos, c.SYNS, c.ALLSENSES);

        while (x != null) {
            std.debug.print("{s}\n", .{x.*.pos});
            std.debug.print("{s}\n", .{x.*.defn});
            std.debug.print("Synonyms:\n", .{});
            for (0..@intCast(x.*.wcount)) |i| {
                const syn = x.*.words[i];
                std.debug.print("\t{s}\n", .{syn});
            }
            x = x.*.nextss;
        }
    }
    std.debug.print("____________________________________\n", .{});
}
