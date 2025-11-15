---Provide methods for `kodex.nvim` to toggle, start, and show Codex CLI.
---@class kodex.Provider
---
---The command to start Codex CLI.
---`kodex.nvim` will append `--port <port>` if not already present and `opts.port` is set.
---@field cmd? string
---
---Called by `require("kodex").toggle()`.
---@field toggle? fun(self: kodex.Provider)
---
---Called when sending a prompt or command to Codex CLI but no process was found.
---`kodex.nvim` will poll for a couple seconds waiting for one to appear.
---@field start? fun(self: kodex.Provider)
---
---Called when a prompt or command is sent to Codex CLI,
---*and* this provider's `toggle` or `start` has previously been called
---(so as to not interfere when Codex CLI was started externally).
---@field show? fun(self: kodex.Provider)

---Configure and enable built-in providers.
---@class kodex.provider.Opts
---
---The built-in provider to use, or `false` for none.
---Defaults to [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) if available.
---@field enabled? "snacks"|false
---
---@field snacks? kodex.provider.Snacks

---Provide an embedded Codex CLI via [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@class kodex.provider.Snacks : kodex.Provider, snacks.terminal.Opts

local M = {}

local started = false

---Toggle `kodex` via `opts.provider`.
function M.toggle()
  local provider = require("kodex.config").provider
  if provider and provider.toggle then
    provider:toggle()
    started = true
  else
    error("No `provider.toggle` available — run `:checkhealth kodex` for details", 0)
  end
end

---Start `kodex` via `opts.provider`.
function M.start()
  local provider = require("kodex.config").provider
  if provider and provider.start then
    provider:start()
    started = true
  else
    error("No `provider.start` available — run `:checkhealth kodex` for details", 0)
  end
end

---Show `kodex` via `opts.provider`,
---if `provider.toggle` or `provider.start` was previously called.
function M.show()
  local provider = require("kodex.config").provider
  if started then
    if provider and provider.show then
      provider:show()
    else
      error("No `provider.show` available — run `:checkhealth kodex` for details", 0)
    end
  end
end

return M
