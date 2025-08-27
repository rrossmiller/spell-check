const std = @import("std");
// const parser = @import("parser.zig");

/// The global state of the server
pub const State = struct {
    allocator: std.mem.Allocator,
    documents: std.StringHashMap([]const u8),
    entries: std.StringHashMap([]const u8),
    pub fn init(allocator: std.mem.Allocator) State {
        return .{
            .allocator = allocator,
            .documents = std.StringHashMap([]const u8).init(allocator),
            .entries = std.StringHashMap([]const u8).init(allocator),
        };
    }
    pub fn deinit(self: *State) void {
        var it = self.documents.iterator();
        while (it.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.documents.deinit();
        // Free all keys and values in the hash map
        var entry_it = self.entries.iterator();
        while (entry_it.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.entries.deinit();
    }

    pub fn open_document(self: *State, uri: []const u8, text: []const u8) !void {
        // need to reallocate key and text because it will be freed when the params obj is freed
        const my_txt = try self.documents.allocator.dupe(u8, text);
        const my_uri = try self.allocator.dupe(u8, uri);

        // parse the text --> the parsed k:v goes into entries
        // try parser.parse(self.allocator, text, &self.entries);

        try self.documents.put(my_uri, my_txt);
    }
    pub fn update_document(self: *State, uri: []const u8, text: []const u8) !void {
        const my_txt = try self.allocator.dupe(u8, text);
        if (try self.documents.fetchPut(uri, my_txt)) |kv| {
            self.allocator.free(kv.value);
        }
    }
    pub fn remove_doc(self: *State, uri: []const u8) void {
        if (self.documents.fetchRemove(uri)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
        }
    }
};
