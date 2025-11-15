local M = {}

---@param default? string
---@param opts? kodex.prompt.Opts
function M.ask(default, opts)
  opts = opts or {}
  opts.context = opts.context or require("kodex.context").new()

  local input_opts = {
    default = default,
    highlight = function(text)
      local rendered = opts.context:render(text)
      return vim.tbl_map(function(extmark)
        return { extmark.col, extmark.end_col, extmark.hl_group }
      end, opts.context.extmarks(rendered.input))
    end,
    completion = "customlist,v:lua.kodex_completion",
    win = {
      b = {
        completion = true,
      },
      bo = {
        filetype = "kodex_ask",
      },
      on_buf = function(win)
        vim.api.nvim_create_autocmd("InsertEnter", {
          once = true,
          buffer = win.buf,
          callback = function()
            if package.loaded["blink.cmp"] then
              require("kodex.cmp.blink").setup(require("kodex.config").opts.auto_register_cmp_sources)
            end
          end,
        })
      end,
    },
  }

  input_opts = vim.tbl_deep_extend("force", input_opts, require("kodex.config").opts.input)

  vim.ui.input(input_opts, function(value)
    if value and value ~= "" then
      require("kodex").prompt(value, opts)
    end
  end)
end

_G.kodex_completion = function(_, CmdLine, _)
  local start_idx, end_idx = CmdLine:find("([^%s]+)$")
  local latest_word = start_idx and CmdLine:sub(start_idx, end_idx) or nil

  local completions = {}
  for placeholder, _ in pairs(require("kodex.config").opts.contexts) do
    table.insert(completions, placeholder)
  end

  local items = {}
  for _, completion in ipairs(completions) do
    if not latest_word then
      table.insert(items, CmdLine .. completion)
    elseif completion:find(latest_word, 1, true) == 1 then
      local new_cmd = CmdLine:sub(1, start_idx - 1) .. completion .. CmdLine:sub(end_idx + 1)
      table.insert(items, new_cmd)
    end
  end
  return items
end

return M
