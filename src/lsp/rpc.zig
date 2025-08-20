const std = @import("std");
const structs = @import("../lsp/structs.zig");

pub const BaseMessage = struct {
    jsonrpc: ?[]const u8 = null,
    //  The request id.
    id: ?u32 = null,
    // The method to be invoked.
    method: []u8,

    // state not from json
    contents: ?[]u8 = null,
    message_len: ?u32 = null,

    // BaseMessage has its own readMessage method so it can store the contents, too
    pub fn readMessage(allocator: std.mem.Allocator, stdin: std.fs.File.Reader) !std.json.Parsed(BaseMessage) {
        try stdin.skipBytes(16, .{}); // skip "Content-Length: "
        // get the length of the message in the header
        const buf = try stdin.readUntilDelimiterAlloc(allocator, '\r', 10);
        defer allocator.free(buf);
        const msg_size = try std.fmt.parseInt(u32, buf, 10);

        // skip newlines "\r\n\r\n"
        try stdin.skipBytes(3, .{});

        const contents = try allocator.alloc(u8, msg_size);
        _ = try stdin.readAll(contents);

        var parsed = try std.json.parseFromSlice(BaseMessage, allocator, contents, .{ .ignore_unknown_fields = true });
        parsed.value.contents = contents;
        parsed.value.message_len = msg_size;
        return parsed;
    }
    pub fn deinit(self: *const BaseMessage, allocator: std.mem.Allocator) void {
        const s = self.*;
        if (s.contents) |c| {
            allocator.free(c);
        }
    }
};

pub fn readMessage(allocator: std.mem.Allocator, base_message: *const BaseMessage, T: type) !std.json.Parsed(T) {
    var content_stream = std.io.StreamSource{ .buffer = std.io.fixedBufferStream(base_message.contents.?) };
    const stdin = content_stream.reader();

    const contents = try stdin.readAllAlloc(allocator, base_message.message_len.?);
    defer allocator.free(contents);

    const parsed = try std.json.parseFromSlice(T, allocator, contents, .{ .ignore_unknown_fields = true });

    return parsed;
}

test "test readMessage" {
    const allocator = std.testing.allocator;
    // make a file to be a standin for stdin
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const f = try tmp_dir.dir.createFile("tmp.txt", .{ .read = true });
    defer f.close();
    const json =
        \\{"id":1,"params":{"workspaceFolders":null,"processId":12274,"clientInfo":{"name":"Neovim","version":"0.10.2"},"rootPath":null,"rootUri":null,"workDoneToken":"1","trace":"off","capabilities":{"workspace":{"configuration":true,"didChangeConfiguration":{"dynamicRegistration":false},"workspaceFolders":true,"applyEdit":true,"workspaceEdit":{"resourceOperations":["rename","create","delete"]},"didChangeWatchedFiles":{"relativePatternSupport":true,"dynamicRegistration":true},"semanticTokens":{"refreshSupport":true},"inlayHint":{"refreshSupport":true},"symbol":{"symbolKind":{"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]},"dynamicRegistration":false}},"window":{"workDoneProgress":true,"showMessage":{"messageActionItem":{"additionalPropertiesSupport":false}},"showDocument":{"support":true}},"textDocument":{"formatting":{"dynamicRegistration":true},"rangeFormatting":{"dynamicRegistration":true},"completion":{"completionItemKind":{"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25]},"completionList":{"itemDefaults":["editRange","insertTextFormat","insertTextMode","data"]},"completionItem":{"documentationFormat":["markdown","plaintext"],"snippetSupport":false,"commitCharactersSupport":false,"preselectSupport":false,"deprecatedSupport":false},"dynamicRegistration":false,"contextSupport":false},"references":{"dynamicRegistration":false},"documentHighlight":{"dynamicRegistration":false},"documentSymbol":{"symbolKind":{"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]},"hierarchicalDocumentSymbolSupport":true,"dynamicRegistration":false},"publishDiagnostics":{"relatedInformation":true,"tagSupport":{"valueSet":[1,2]},"dataSupport":true},"inlayHint":{"resolveSupport":{"properties":["textEdits","tooltip","location","command"]},"dynamicRegistration":true},"callHierarchy":{"dynamicRegistration":false},"implementation":{"linkSupport":true},"typeDefinition":{"linkSupport":true},"semanticTokens":{"requests":{"full":{"delta":true},"range":false},"overlappingTokenSupport":true,"tokenModifiers":["declaration","definition","readonly","static","deprecated","abstract","async","modification","documentation","defaultLibrary"],"serverCancelSupport":false,"augmentsSyntaxTokens":true,"multilineTokenSupport":false,"dynamicRegistration":false,"tokenTypes":["namespace","type","class","enum","interface","struct","typeParameter","parameter","variable","property","enumMember","event","function","method","macro","keyword","modifier","comment","string","number","regexp","operator","decorator"],"formats":["relative"]},"rename":{"prepareSupport":true,"dynamicRegistration":true},"synchronization":{"didSave":true,"dynamicRegistration":false,"willSaveWaitUntil":true,"willSave":true},"diagnostic":{"dynamicRegistration":false},"codeAction":{"codeActionLiteralSupport":{"codeActionKind":{"valueSet":["","quickfix","refactor","refactor.extract","refactor.inline","refactor.rewrite","source","source.organizeImports"]}},"resolveSupport":{"properties":["edit"]},"dynamicRegistration":true,"isPreferredSupport":true,"dataSupport":true},"hover":{"contentFormat":["markdown","plaintext"],"dynamicRegistration":true},"signatureHelp":{"signatureInformation":{"documentationFormat":["markdown","plaintext"],"parameterInformation":{"labelOffsetSupport":true},"activeParameterSupport":true},"dynamicRegistration":false},"definition":{"linkSupport":true,"dynamicRegistration":true},"declaration":{"linkSupport":true}},"general":{"positionEncodings":["utf-16"]}}},"jsonrpc":"2.0","method":"initialize"}
    ;
    const msg = try std.fmt.allocPrint(allocator, "Content-Length: {d}\r\n\r\n{s}", .{ json.len, json });
    defer allocator.free(msg);
    try f.writeAll(msg);
    try f.seekTo(0);

    // const msg_reader = MessageReader(structs.RequestMessage(structs.InitializeParams));
    const parsed = try BaseMessage.readMessage(allocator, f.reader());
    defer parsed.deinit();
    const message = parsed.value;
    defer message.deinit(allocator);
    try std.testing.expectEqualStrings("initialize", message.method);
    try std.testing.expectEqual(1, message.id);
    try std.testing.expectEqualStrings(json, message.contents.?);
}
