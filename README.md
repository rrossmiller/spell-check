# Spellcheck lsp

## Hunspell

`brew install hunspell`

### dict and aff files:

https://github.com/LibreOffice/dictionaries/tree/master/en

Once you have installed the `dict` and `aff` files, update root.zig to point to those paths.

## WordNet

`brew install wordnet`

## pkgconf

I also needed to install pkg-config so hunspell would link correctly
`brew install pkgconf`

## Intallation

### Neovim

There is a justfile recipe called build-nvim that will build and move the binary to the right location.

In your neovim config (e.g. `~/.config/nvim`) add the following to `lsp/spellcheck.lua`

```lua
local bin_path = vim.fn.stdpath "state"
return {
    cmd = { bin_path .. "/spellcheck-lsp/lsp" },
    filetypes = { "text", "markdown" },
    settings = {},
}
```

In `init.lua`, add the following

```lua
vim.lsp.enable("spellcheck")
```

## TODO

- spellcheck
- autocomplete words
- subsitute with synonyms
