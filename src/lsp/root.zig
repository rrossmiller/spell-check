const std = @import("std");
pub const c = @cImport({
    @cInclude("string.h");
    @cInclude("hunspell.h");
    @cInclude("wn.h");
});

const SpellcheckError = error{InitError};
pub fn init() !*c.Hunhandle {
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
    return h.?;
}

pub fn deinit(h: ?*c.Hunhandle) void {
    defer c.Hunspell_destroy(h);
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
pub fn def(allocator: std.mem.Allocator, word: [*c]u8) !std.ArrayList(u8) {
    var definitions = try std.ArrayList(u8).initCapacity(allocator, 4);

    for (POS) |pos| {
        var x = c.findtheinfo_ds(word, pos, c.SYNS, c.ALLSENSES);
        while (x != null) {
            var def_span: []u8 = std.mem.span(x.*.defn);
            def_span = def_span[1 .. def_span.len - 1]; // remove the parens that surround each definition
            def_span[0] = capitalize(def_span[0]);
            try definitions.appendSlice(allocator, "- ");

            // split ; for example usages
            var example_split = std.mem.splitScalar(u8, def_span, ';');

            try definitions.appendSlice(allocator, example_split.first());
            while (example_split.next()) |ex| {
                try definitions.appendSlice(allocator, "\n\t");
                try definitions.appendSlice(allocator, ex);
            }
            try definitions.appendNTimes(allocator, '\n', 2);

            // std.debug.print("{s}\n", .{x.*.pos});
            // std.debug.print("{s}\n", .{x.*.defn});
            // std.debug.print("Synonyms:\n", .{});
            // for (0..@intCast(x.*.wcount)) |i| {
            //     const syn = x.*.words[i];
            //     std.debug.print("\t{s}\n", .{syn});
            // }
            x = x.*.nextss;
        }
    }
    // std.debug.print("____________________________________\n", .{});
    _ = definitions.pop(); // remove last new lines
    _ = definitions.pop();
    return definitions;
}

fn capitalize(char: u8) u8 {
    if ((char > 'a' or char < 'z') and (char > 'A' or char < 'Z')) {
        return char - 32;
    }
    return char;
}
