const std = @import("std");
const root = @import("lsp/root.zig");
const c = @import("lsp/root.zig").c;
const lsp = @import("lsp/lsp.zig");
const lsp_structs = @import("lsp/structs.zig");
const rpc = @import("lsp/rpc.zig");
const State = @import("lsp/state.zig").State;

const MAX_WORD_LEN = 100;
const version = "0.0.1";

pub fn main() !void {
    var stdout_b: [512]u8 = undefined;
    var stdout = std.fs.File.stdout();
    var stdout_writer = stdout.writer(&stdout_b);

    var stdin_b: [512]u8 = undefined;
    var stdin = std.fs.File.stdin();
    var stdin_reader = stdin.reader(&stdin_b);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const check = gpa.deinit();
        switch (check) {
            .ok => {},
            .leak => {
                std.debug.print("leaked\n", .{});
            },
        }
    }
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const aren_allocator = arena.allocator();

    // check if the --version command was called
    var args = std.process.args();
    _ = args.skip(); // skip name
    if (args.next()) |cmd| {
        if (std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "-v")) {
            try stdout.writeAll(version);
            return;
        } else if (std.mem.eql(u8, cmd, "-ex")) {
            // try ex(allocator);
            std.debug.print("not implemented\n", .{});
            return;
        }
    }

    // start
    const h = try root.init();
    defer root.deinit(h);

    std.log.info("spellcheck-lsp started", .{});
    var state = State.init(allocator);
    defer state.deinit();
    var run = true;
    while (run) {
        const parsed = try rpc.BaseMessage.readMessage(aren_allocator, &stdin_reader.interface);
        defer parsed.deinit();
        const base_message = parsed.value;
        defer base_message.deinit(aren_allocator);

        run = try handle_message(aren_allocator, base_message, h, &state, &stdout_writer.interface);
        try stdout_writer.interface.flush();
    }
}

fn handle_message(allocator: std.mem.Allocator, base_message: rpc.BaseMessage, h: *c.Hunhandle, state: *State, stdout: *std.Io.Writer) !bool {
    //TODO
    //impl json parse
    //https://www.reddit.com/r/Zig/comments/1bignpf/json_serialization_and_taggeddiscrimated_unions/
    //https://zigbin.io/651078

    switch (try lsp.MessageType.get(base_message.method)) {
        // Requests
        .Initialize => {
            const parsed = try rpc.readMessage(allocator, &base_message, lsp_structs.RequestMessage(lsp_structs.InitializeParams));
            defer parsed.deinit();
            std.log.info("Connected to: {s}", .{parsed.value.params.?.clientInfo.name});
            const res = lsp_structs.newInitializeResponse(parsed.value.id);
            try write_response(allocator, stdout, res);
        },
        .Hover => {
            const parsed = try rpc.readMessage(allocator, &base_message, lsp_structs.RequestMessage(lsp_structs.HoverParams));
            defer parsed.deinit();

            const params = parsed.value.params.?;
            // const len = try std.fmt.allocPrint(allocator, "{d}", .{state.documents.get(params.textDocument.uri).?.len});
            if (state.documents.get(params.textDocument.uri)) |contents| {
                if (try lsp.hover(allocator, &params, contents, h)) |doc| {
                    // defer doc.deinit(allocator);
                    const msg = doc.items;

                    const res = lsp_structs.newHoverResponse(parsed.value.id, msg);
                    try write_response(allocator, stdout, res);
                }
            }
        },
        .Completion => {
            // const parsed = try rpc.readMessage(allocator, &base_message, lsp_structs.RequestMessage(lsp_structs.CompletionParams));
            // defer parsed.deinit();
            // std.log.info("completion on line: {d}", .{parsed.value.params.?.position.line});
            //
            // //TODO completion impl
            // const maybe_items = try lsp.completion(allocator, parsed.value.params.?);
            // const items = maybe_items.?;
            // defer allocator.free(items);
            // const res = lsp_structs.newCompletionResponse(parsed.value.id, items);
            // try write_response(allocator, stdout.writer(), res);
        },

        // Notifications
        .DidOpen => {
            const parsed = try rpc.readMessage(allocator, &base_message, lsp_structs.RequestMessage(lsp_structs.DidOpenParams));
            defer parsed.deinit();
            // store the text in the state map
            const params = parsed.value.params.?;
            try state.open_document(params.textDocument.uri, params.textDocument.text);
            std.log.info("Opened: {s}", .{params.textDocument.uri});

            // // diagnostic notification not quite working
            // // however, uri dosnt look right either
            //
            // // init diagnostics
            // // TODO
            // const d = [_]lsp_structs.Diagnostic{
            //     lsp_structs.Diagnostic{},
            // };
            //
            // // send diagnostics
            // const res =
            //     lsp_structs.newPublishDiagnosticsParams("textDocument/publishDiagnostics",
            // params.textDocument.uri, &d);
            // try write_response(allocator, stdout.writer(), res);
        },
        .DidChange => {
            const parsed = try rpc.readMessage(allocator, &base_message, lsp_structs.RequestMessage(lsp_structs.DidChangeParams));
            defer parsed.deinit();
            const params = parsed.value.params.?;
            for (params.contentChanges) |change| {
                try state.update_document(params.textDocument.uri, change.text);
            }
        },
        .DidClose => {
            const parsed = try rpc.readMessage(allocator, &base_message, lsp_structs.RequestMessage(lsp_structs.DidCloseParams));
            defer parsed.deinit();
            const params = parsed.value.params.?;

            state.remove_doc(params.textDocument.uri);
            std.log.info("Close: {s}", .{params.textDocument.uri});
        },
        // .DidSave => {
        //     std.debug.print("did save", .{});
        // },
        .Shutdown => {
            std.log.info("Shutting down Spellcheck LSP", .{});
            return false;
        },
        else => {
            std.log.info("Message Recieved: {s}", .{base_message.method});
        },
    }
    return true;
}

fn write_response(allocator: std.mem.Allocator, stdout: *std.Io.Writer, res: anytype) !void {
    const fmt = std.json.fmt(res, .{ .whitespace = .indent_2 });
    var arraylist = try std.ArrayList(u8).initCapacity(allocator, 128);
    defer arraylist.deinit(allocator);

    var b: [128]u8 = undefined;
    var w = arraylist.writer(allocator).adaptToNewApi(&b);
    try fmt.format(&w.new_interface);
    try w.new_interface.flush();

    const r = arraylist.items;
    // std.debug.print("sending message: {s}\n", .{r});

    const msg = try std.fmt.allocPrint(allocator, "Content-Length: {d}\r\n\r\n{s}", .{ r.len, r });
    defer allocator.free(msg);
    try stdout.writeAll(msg);
}

// fn ex(allocator: std.mem.Allocator) !void {
//     const h = try root.init();
//     defer root.deinit(h);
//
//     var b: [128]u8 = undefined;
//     var stdin_reader = std.fs.File.stdin().reader(&b).interface;
//     std.debug.print("Enter words:\n\n", .{});
//     const buf = try allocator.alloc(u8, MAX_WORD_LEN);
//     defer allocator.free(buf);
//
//     var dual_str = try root.read_c_str(stdin_reader, buf);
//     while (dual_str.c_str.* != 0) {
//         if (try root.get_suggestions(allocator, h, dual_str.c_str)) |suggestions| {
//             defer allocator.free(suggestions);
//             for (suggestions) |s| {
//                 defer allocator.free(s);
//                 std.debug.print("{s}\n", .{s});
//             }
//         }
//
//         // definition
//         const x = try root.def(allocator, dual_str.c_str);
//         x.deinit();
//         std.debug.print("\n", .{});
//         dual_str = try root.read_c_str(stdin_reader, buf);
//     }
// }
