local M = {}

---@class kodex.select.Opts
---@field prompts? boolean
---@field commands? boolean
---@field provider? boolean

---@param opts? kodex.select.Opts
function M.select(opts)
  local context = require("kodex.context").new()
  opts = vim.tbl_deep_extend("force", {
    prompts = true,
    commands = true,
    provider = false,
  }, opts or {})

  local configuration = require("kodex.config")
  local prompts = configuration.opts.prompts or {}
  local commands = configuration.opts.commands or {}

  ---@type table[]
  local items = {}

  if opts.prompts then
    table.insert(items, { __group = true, name = "PROMPT", preview = { text = "" } })
    local prompt_items = {}
    for name, prompt in pairs(prompts) do
      local rendered = context:render(prompt.prompt)
      table.insert(prompt_items, {
        __type = "prompt",
        name = name,
        text = prompt.prompt .. (prompt.ask and "…" or ""),
        highlights = rendered.input,
        preview = {
          text = context.plaintext(rendered.output),
          extmarks = context.extmarks(rendered.output),
        },
        ask = prompt.ask,
      })
    end
    table.sort(prompt_items, function(a, b)
      if a.ask and not b.ask then
        return true
      elseif not a.ask and b.ask then
        return false
      end
      return a.name < b.name
    end)
    vim.list_extend(items, prompt_items)
  end

  if opts.commands then
    table.insert(items, { __group = true, name = "COMMAND", preview = { text = "" } })
    local command_items = {}
    for name, description in pairs(commands) do
      table.insert(command_items, {
        __type = "command",
        name = name,
        text = description,
        highlights = { { description, "Comment" } },
        preview = { text = "" },
      })
    end
    table.sort(command_items, function(a, b)
      return a.name < b.name
    end)
    vim.list_extend(items, command_items)
  end

  if opts.provider and configuration.provider then
    table.insert(items, { __group = true, name = "PROVIDER", preview = { text = "" } })
    table.insert(items, {
      __type = "provider",
      name = "toggle",
      text = "Toggle kodex",
      highlights = { { "Toggle kodex", "Comment" } },
      preview = { text = "" },
    })
    table.insert(items, {
      __type = "provider",
      name = "start",
      text = "Start kodex",
      highlights = { { "Start kodex", "Comment" } },
      preview = { text = "" },
    })
    table.insert(items, {
      __type = "provider",
      name = "show",
      text = "Show kodex",
      highlights = { { "Show kodex", "Comment" } },
      preview = { text = "" },
    })
  end

  for index, item in ipairs(items) do
    item.idx = index
  end

  local select_opts = {
    format_item = function(item, is_snacks)
      if is_snacks then
        if item.__group then
          return { { item.name, "Title" } }
        end
        local formatted = vim.deepcopy(item.highlights or {})
        if item.ask then
          table.insert(formatted, { "…", "Keyword" })
        end
        table.insert(formatted, 1, { item.name, "Keyword" })
        table.insert(formatted, 2, { string.rep(" ", math.max(0, 18 - #item.name)) })
        return formatted
      end
      local indent = #tostring(#items) - #tostring(item.idx)
      if item.__group then
        local divider = string.rep("—", math.max(2, (80 - #item.name) / 2))
        return string.rep(" ", indent) .. divider .. item.name .. divider
      end
      return string.format(
        "%s[%s]%s%s",
        string.rep(" ", indent),
        item.name,
        string.rep(" ", math.max(0, 18 - #item.name)),
        item.text or ""
      )
    end,
  }

  vim.ui.select(
    items,
    vim.tbl_deep_extend("force", select_opts, configuration.opts.select or {}),
    function(choice)
      if not choice then
        return
      end
      if choice.__type == "prompt" then
        local prompt = configuration.opts.prompts[choice.name]
        prompt.context = context
        if prompt.ask then
          require("kodex").ask(prompt.prompt, prompt)
        else
          require("kodex").prompt(prompt.prompt, prompt)
        end
      elseif choice.__type == "command" then
        require("kodex").command(choice.name)
      elseif choice.__type == "provider" and configuration.provider then
        if choice.name == "toggle" then
          require("kodex").toggle()
        elseif choice.name == "start" then
          require("kodex").start()
        elseif choice.name == "show" then
          require("kodex").show()
        end
      end
    end
  )
end

return M
