const std = @import("std");

pub fn RequestMessage(comptime T: type) type {
    return struct {
        jsonrpc: []const u8 = "2.0",
        id: ?u32 = null,
        method: []u8,

        // The method's params.
        params: ?T = null,
    };
}

pub fn ResponseMessage(comptime T: type) type {
    return struct {
        rpc: []const u8 = "2.0",
        id: ?u32 = 1,
        result: T,
    };
}

pub fn NotificationMessage(comptime T: type) type {
    return struct {
        method: []const u8,
        params: T,
    };
}

// COMMON
const TextDocumentIdentifier = struct {
    uri: []const u8,
};
const Position = struct {
    line: u32,
    character: u32,
};
//
// INITIALIZE >
pub const InitializeParams = struct {
    clientInfo: ClientInfo,
};
const ClientInfo = struct {
    name: []u8,
    version: []u8,
};

pub const InitializeResult = struct {
    // capabilities: ServerCapabilities,
    capabilities: ServerCapabilities = .{},
    serverInfo: ServerInfo = .{},
};
pub const ServerCapabilities = struct {
    textDocumentSync: u16 = 1,
    hoverProvider: bool = true,
    // diagnosticProvider: DiagnosticOptions = .{},
    // https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_completion
    // completionProvider: CompletionOptions = .{},
    // completionProvider: std.AutoHashMap(u8, u8),
    // pub fn init(allocator: std.mem.Allocator) !ServerCapabilities {
    //     const map = try std.AutoHashMap(u8, u8).init(allocator);
    //     return .{
    //         .completionProvider = map,
    //     };
    // }
};

// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#diagnosticOptions
const DiagnosticOptions = struct {
    interFileDependencies: bool = false,
    workspaceDiagnostics: bool = false,
};
const CompletionOptions = struct {
    // triggerCharacters: ?[]u8 = null,
    // allCommitCharacters: ?[]u8 = null,
    // resolveProvider: ?bool = null,
};
pub const ServerInfo = struct {
    name: []const u8 = "spellcheck-lsp",
    version: []const u8 = "0.0.1",
};
pub fn newInitializeResponse(id: ?u32) ResponseMessage(InitializeResult) {
    const r = ResponseMessage(InitializeResult){
        .id = id,
        .result = .{},
    };
    return r;
}
// < INITIALIZE

//  TEXTDOCUMENT/HOVER >
pub const HoverParams = struct {
    textDocument: TextDocumentIdentifier,
    position: Position,
};
pub const TextDocumentPositionParams = struct {
    // The text document.
    textDocument: TextDocumentIdentifier,

    //  The position inside the text document.
    position: Position,
};

pub const HoverResult = struct {
    contents: []const u8,
};
pub fn newHoverResponse(id: ?u32, contents: []const u8) ResponseMessage(HoverResult) {
    return .{
        .id = id,
        .result = .{ .contents = contents },
    };
}

// < TEXTDOCUMENT/HOVER
// TEXTDOCUMENT/COMPLETION >
pub const CompletionParams = struct {
    textDocument: TextDocumentIdentifier,
    position: Position,
};

pub const CompletionResult = struct {
    items: ?[]CompletionItem, //TODO remove null
};
pub const CompletionItem = struct {
    // The label of this completion item.
    //
    // The label property is also by default the text that
    // is inserted when selecting this completion.
    //
    // If label details are provided the label itself should
    // be an unqualified name of the completion item.
    label: []const u8,
    // kind: u8 = 1, // https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemKind
    detail: []const u8,
    documentation: []const u8,
};
//TODO remove null
pub fn newCompletionResponse(id: ?u32, items: ?[]CompletionItem) ResponseMessage(CompletionResult) {
    return .{
        .id = id,
        .result = .{ .items = items },
    };
}
// < TEXTDOCUMENT/COMPLETION

// document/didOpen >
pub const DidOpenParams = struct {
    textDocument: TextDocumentItem,
};
const TextDocumentItem = struct {
    //  The text document's URI.
    uri: []const u8,

    // The text document's language identifier.
    languageId: []const u8,

    // The version number of this document (it will increase after each
    // change, including undo/redo).
    version: u8,

    // The content of the opened text document.
    text: []const u8,
};
// < document/didOpen
// document/didChange >
pub const DidChangeParams = struct {
    textDocument: VersionedTextDocumentIdentifier,
    contentChanges: []TextDocumentContentChangeEvent,
};
const VersionedTextDocumentIdentifier = struct {
    uri: []const u8,
    version: u8,
};
pub const TextDocumentContentChangeEvent = struct {
    text: []const u8,
};
// < document/didChange
// document/didClose >
pub const DidCloseParams = struct {
    textDocument: TextDocumentIdentifier,
};
// < document/didClose

// textDocument/publishDiagnostics >
pub const PublishDiagnosticsParams = struct {
    uri: []const u8,
    diagnostics: []const Diagnostic,
};

pub const Diagnostic = struct {
    range: Range = .{
        .start = .{ .line = 0, .character = 0 },
        .end = .{ .line = 0, .character = 5 },
    },
    message: []const u8 = "test diagnostic",
};

const Range = struct {
    start: Position,
    end: Position,
};

pub fn newPublishDiagnosticsParams(method: []const u8, uri: []const u8, diagnostics: []const Diagnostic) NotificationMessage(PublishDiagnosticsParams) {
    return .{
        .method = method,
        .params = .{
            .uri = uri,
            .diagnostics = diagnostics,
        },
    };
}

// < textDocument/publishDiagnostics
