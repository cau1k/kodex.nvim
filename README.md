# kodex.nvim

Integrate the [Codex](https://github.com/sst/codex) AI assistant with Neovim—streamline editor-aware research, reviews, and automation without leaving your buffers.

https://github.com/user-attachments/assets/01e4e2fc-bbfa-427e-b9dc-c1c1badaa90e

## ✨ Features

- Talk to `codex app-server` directly over JSON-RPC.
- Prompt with completions, highlights, and normal-mode support.
- Pick prompts from a library or define your own.
- Inject relevant editor context (buffer, cursor, selection, diagnostics, ...).
- Control Codex with commands or map your own shortcuts.
- Auto-reload buffers edited by Codex in real time.
- Approve or reject Codex permission requests from inside Neovim.
- Watch Codex activity via a statusline component and `KodexEvent` autocmds.

## 📦 Setup

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "cau1k/kodex.nvim",
  dependencies = {
    -- Recommended for `ask()` and `select()`.
    -- Required for the default `toggle()` implementation.
    { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
  },
  config = function()
    ---@type kodex.Opts
    vim.g.kodex_opts = {
      -- Your configuration, if any — see `lua/kodex/config.lua`, or "goto definition".
    }

    -- Required for `opts.auto_reload`.
    vim.o.autoread = true

    -- Recommended/example keymaps.
    vim.keymap.set({ "n", "x" }, "<C-a>", function() require("kodex").ask("@this: ", { submit = true }) end, { desc = "Ask Kodex" })
    vim.keymap.set({ "n", "x" }, "<C-x>", function() require("kodex").select() end,                          { desc = "Execute Kodex action…" })
    vim.keymap.set({ "n", "x" },    "ga", function() require("kodex").prompt("@this") end,                   { desc = "Add to Codex" })
    vim.keymap.set({ "n", "t" }, "<C-.>", function() require("kodex").toggle() end,                          { desc = "Toggle Codex" })
    vim.keymap.set("n",        "<S-C-u>", function() require("kodex").command("session.half.page.up") end,   { desc = "Codex half page up" })
    vim.keymap.set("n",        "<S-C-d>", function() require("kodex").command("session.half.page.down") end, { desc = "Codex half page down" })
    -- You may want these if you stick with the opinionated "<C-a>" and "<C-x>" above — otherwise consider "<leader>k".
    vim.keymap.set('n', '+', '<C-a>', { desc = 'Increment', noremap = true })
    vim.keymap.set('n', '-', '<C-x>', { desc = 'Decrement', noremap = true })
  end,
}
```

<details>
<summary><a href="https://github.com/nix-community/nixvim">nixvim</a></summary>

```nix
programs.nixvim = {
  extraPlugins = [
    pkgs.vimPlugins.kodex-nvim
  ];
};
```
</details>

> [!TIP]
> Run `:checkhealth kodex` after installation.

## ⚙️ Configuration

`kodex.nvim` provides a rich, reliable default experience — see all available options and their defaults in [`lua/kodex/config.lua`](./lua/kodex/config.lua).

### Provider

By default, `kodex.nvim` will launch `codex app-server` via [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) when it is available:

```lua
vim.g.kodex_opts = {
  provider = {
    enabled = "snacks",
    ---@type kodex.provider.Snacks
    snacks = {
      -- Customize `snacks.terminal` to your liking.
    }
  }
}
```

Already running Codex yourself? Configure your own provider or disable the built-in one entirely:

```lua
vim.g.kodex_opts = {
  ---@type kodex.Provider
  provider = {
    toggle = function(self)
      -- Called by `require("kodex").toggle()`.
    end,
    start = function(self)
      -- Called when sending a prompt or command to Codex but no process was found.
    end,
    show = function(self)
      -- Called when a prompt or command is sent to Codex,
      -- *and* this provider's `toggle` or `start` has previously been called
      -- (so as to not interfere when Codex was started externally).
    end
  }
}
```

> [!TIP]
> Pull requests adding additional built-in providers are welcome!

## 🚀 Usage

### ✍️ Ask — `require("kodex").ask()`

Input a prompt to send to Codex.

<img width="800" alt="image" src="https://github.com/user-attachments/assets/8591c610-4824-4480-9e6d-0c94e9c18f3a" />

- Press `<Up>` to browse recent asks.
- Fetches available subagents from Codex.
- Highlights placeholders.
- Completes placeholders and subagents.
  - Press `<Tab>` to trigger built-in completion.
  - When using `blink.cmp` and `snacks.input`, registers `opts.auto_register_cmp_sources`.

### 📝 Select — `require("kodex").select()`

Select from all `kodex.nvim` functionality.

<img width="800" alt="image" src="https://github.com/user-attachments/assets/afd85acd-e4b3-47d2-b92f-f58d25972edb" />

### 🗣️ Prompt — `require("kodex").prompt()` | `:[range]KodexPrompt`

Send a prompt to Codex.

#### Contexts

Replaces placeholders in the prompt with the corresponding context:

| Placeholder | Context |
| - | - |
| `@buffer` | Current buffer |
| `@buffers` | Open buffers |
| `@cursor` | Cursor position |
| `@selection` | Visual selection |
| `@this` | Visual selection if any, else cursor position |
| `@visible` | Visible text |
| `@diagnostics` | Current buffer diagnostics |
| `@quickfix` | Quickfix list |
| `@diff` | Git diff |
| `@grapple` | [grapple.nvim](https://github.com/cbochs/grapple.nvim) tags |

#### Prompts

Reference a prompt by name to review, explain, and improve your code:

| Name | Prompt |
|------------------------------------|-----------------------------------------------------------|
| `ask`         | *...*                                                             |
| `explain`     | Explain `@this` and its context                                   |
| `optimize`    | Optimize `@this` for performance and readability                  |
| `document`    | Add comments documenting `@this`                                  |
| `test`        | Add tests for `@this`                                             |
| `review`      | Review `@this` for correctness and readability                    |
| `diagnostics` | Explain `@diagnostics`                                            |
| `fix`         | Fix `@diagnostics`                                                |
| `diff`        | Review the following git diff for correctness and readability: `@diff`         |
| `buffer`  | `@buffer`                                                             |
| `this`    | `@this`                                                               |

### 🧑‍🏫 Command — `require("kodex").command()`

Send a command to Codex:

| Command | Description |
|-------------------------|----------------------------------------------------------|
| `session.list`          | List sessions                                            |
| `session.new`             | Start a new session                                      |
| `session.share`           | Share the current session                                |
| `session.interrupt`       | Interrupt the current session                            |
| `session.compact`         | Compact the current session (reduce context size)        |
| `session.page.up`        | Scroll messages up by one page                           |
| `session.page.down`      | Scroll messages down by one page                         |
| `session.half.page.up`   | Scroll messages up by half a page                        |
| `session.half.page.down` | Scroll messages down by half a page                      |
| `session.first`          | Jump to the first message in the session                 |
| `session.last`           | Jump to the last message in the session                  |
| `session.undo` | Undo the last action in the current session |
| `session.redo` | Redo the last undone action in the current session |
| `prompt.submit`             | Submit the TUI input                                      |
| `prompt.clear`             | Clear the TUI input                                      |
| `agent.cycle`             | Cycle the selected agent                                 |

## 👀 Events

`kodex.nvim` forwards Codex JSON-RPC notifications as a `KodexEvent` autocmd:

```lua
-- Listen for Codex events
vim.api.nvim_create_autocmd("User", {
  pattern = "KodexEvent",
  callback = function(args)
    -- See the available event payload
    vim.notify(vim.inspect(args.data.event))
    -- Do something useful
    if args.data.event and args.data.event.type == "session.idle" then
      vim.notify("Codex finished responding")
    end
  end,
})
```

### Edits

When Codex edits a file, `kodex.nvim` automatically reloads the corresponding buffer.

### Permissions

When Codex requests a permission, `kodex.nvim` waits for idle before prompting you to approve, reject, or abort it.

<img width="800" alt="image" src="https://github.com/user-attachments/assets/643681ca-75db-4621-8a4a-e744c03c4b4f" />

### Statusline

[lualine](https://github.com/nvim-lualine/lualine.nvim):

```lua
require("lualine").setup({
  sections = {
    lualine_z = {
      {
        require("kodex").statusline,
      },
    }
  }
})
```

## 🙏 Acknowledgments

- Inspired by [nvim-aider](https://github.com/GeorgesAlkhouri/nvim-aider), [neopencode.nvim](https://github.com/loukotal/neopencode.nvim), and [sidekick.nvim](https://github.com/folke/sidekick.nvim).
- Uses Codex's app-server for simplicity — see [sudo-tee/opencode.nvim](https://github.com/sudo-tee/opencode.nvim) for a Neovim frontend.
- [mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server) may better suit you, but it lacks customization and tool calls are slow and unreliable.
