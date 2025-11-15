local source = {}

---@type kodex.Context
source.context = nil

local is_setup = false

function source.setup(sources)
  if is_setup then
    return
  end
  is_setup = true

  require("blink.cmp").add_source_provider("kodex", {
    module = "kodex.cmp.blink",
  })
  for _, src in ipairs(sources) do
    require("blink.cmp").add_filetype_source("kodex_ask", src)
  end
end

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts
  return self
end

function source:enabled()
  return vim.bo.filetype == "kodex_ask"
end

function source:get_trigger_characters()
  local trigger_chars = {}
  for placeholder, _ in pairs(require("kodex.config").opts.contexts) do
    local first_char = placeholder:sub(1, 1)
    if not first_char:match("%w") and not vim.tbl_contains(trigger_chars, first_char) then
      table.insert(trigger_chars, first_char)
    end
  end
  return trigger_chars
end

function source:get_completions(_, callback)
  local CompletionItemKind = require("blink.cmp.types").CompletionItemKind
  local items = {}
  for placeholder in pairs(require("kodex.config").opts.contexts) do
    table.insert(items, {
      label = placeholder,
      kind = CompletionItemKind.Variable,
      filterText = placeholder,
      insertText = placeholder,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    })
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })

  return function() end
end

function source:resolve(item, callback)
  item = vim.deepcopy(item)
  local rendered = source.context:render(item.label)

  if not item.documentation then
    item.documentation = {
      kind = "plaintext",
      value = source.context.plaintext(rendered.output),
      draw = function(opts)
        local buf = opts.window.buf
        if not buf then
          return
        end
        opts.default_implementation({
          kind = "plaintext",
          value = opts.item.documentation.value,
        })
        local extmarks = source.context.extmarks(rendered.output)
        local ns_id = vim.api.nvim_create_namespace("kodex_context_highlight")
        for _, extmark in ipairs(extmarks) do
          vim.api.nvim_buf_set_extmark(buf, ns_id, (extmark.row or 1) - 1, extmark.col, {
            end_col = extmark.end_col,
            hl_group = extmark.hl_group,
          })
        end
      end,
    }
  end

  callback(item)
end

return source
