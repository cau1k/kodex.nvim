local M = {}

function M.check()
  vim.health.start("kodex.nvim")

  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
  local git_hash = vim.fn.system("cd " .. vim.fn.shellescape(plugin_dir) .. " && git rev-parse HEAD")
  if vim.v.shell_error == 0 then
    git_hash = vim.trim(git_hash)
    vim.health.ok("`kodex.nvim` git commit hash: " .. git_hash)
  else
    vim.health.warn("Could not determine `kodex.nvim` git commit hash")
  end

  if vim.fn.executable("codex") == 1 then
    local found_version = vim.fn.system("codex --version")
    found_version = vim.trim(vim.split(found_version, "\n")[1])
    vim.health.ok("`codex` executable found in `$PATH` with version `" .. found_version .. "`.")

  else
    vim.health.error("`codex` executable not found in `$PATH`.", {
      "Install `codex` and ensure it's in your `$PATH`.",
    })
  end

  if require("kodex.config").opts.auto_reload and not vim.o.autoread then
    vim.health.warn(
      "`vim.g.kodex_opts.auto_reload = true` but `vim.o.autoread = false`: files edited by Codex won't be automatically reloaded in buffers.",
      {
        "Set `vim.o.autoread = true`",
        "Or set `vim.g.kodex_opts.auto_reload = false`",
      }
    )
  end

  if vim.g.kodex_opts then
    vim.health.ok("`vim.g.kodex_opts` is " .. vim.inspect(vim.g.kodex_opts))
  else
    vim.health.warn("`vim.g.kodex_opts` is `nil`")
  end

  vim.health.start("kodex.nvim [snacks]")

  local snacks_ok, snacks = pcall(require, "snacks")
  if snacks_ok then
    if snacks.input and snacks.config.get("input", {}).enabled then
      vim.health.ok("`snacks.input` is enabled: `ask()` will be enhanced.")
      local blink_ok = pcall(require, "blink.cmp")
      if blink_ok then
        vim.health.ok(
          "`blink.cmp` is available: `vim.g.kodex_opts.auto_register_cmp_sources` will be registered in `ask()`."
        )
      end
    else
      vim.health.warn("`snacks.input` is disabled: `ask()` will not be enhanced.")
    end
    if snacks.picker and snacks.config.get("picker", {}).enabled then
      vim.health.ok("`snacks.picker` is enabled: `select()` will be enhanced.")
    else
      vim.health.warn("`snacks.picker` is disabled: `select()` will not be enhanced.")
    end
    if snacks.picker and snacks.config.get("terminal", {}).enabled then
      vim.health.ok("`snacks.terminal` is enabled: will default to `snacks` provider.")
    else
      vim.health.warn("`snacks.terminal` is disabled: the default `snacks` provider will not be available.", {
        "Enable `snacks.terminal`",
        "Or launch and manage Codex yourself",
        "Or configure `vim.g.kodex_opts.provider`",
      })
    end
  else
    vim.health.warn("`snacks.nvim` is not available: `ask()` and `select()` will not be enhanced.")
    vim.health.warn("`snacks.nvim` is not available: the default `snacks` provider will not be available.", {
      "Install `snacks.nvim`",
      "Or launch and manage Codex yourself",
      "Or configure `vim.g.kodex_opts.provider`",
    })
  end
end

return M
