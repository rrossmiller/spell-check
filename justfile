build: 
    @clear
    zig build

build-nvim: build
    @mkdir -p ~/.local/state/nvim/spellcheck-lsp/
    cp zig-out/bin/spell_check ~/.local/state/nvim/spellcheck-lsp/lsp

test:
    @clear
    @# zig test src/docs/docs.zig
    @# zig test src/lsp/lsp.zig
    @# zig test src/analysis/parser.zig
    @# zig test src/analysis/state.zig
    @# zig test src/rpc/rpc.zig
    @# zig test src/main.zig
