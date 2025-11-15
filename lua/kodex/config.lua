pcall(require, "kodex.types.snacks")

local M = {}

---@class kodex.Prompt : kodex.prompt.Opts
---@field prompt string
---@field ask? boolean

---@class kodex.ConversationOpts
---@field model? string
---@field reasoning_effort? string
---@field base_instructions? string
---@field developer_instructions? string
---@field approval_policy? string
---@field sandbox_policy? string
---@field profile? string
---@field include_apply_patch_tool? boolean

---@class kodex.RpcOpts
---@field cmd? string|string[]
---@field env? table<string,string>

---@class kodex.Opts
---@field auto_reload boolean
---@field auto_register_cmp_sources string[]
---@field contexts table<string, fun(context: kodex.Context): string|nil>
---@field prompts table<string, kodex.Prompt>
---@field commands table<string, string>
---@field input? snacks.input.Opts
---@field select? snacks.picker.ui_select.Opts
---@field permissions? kodex.permissions.Opts
---@field conversation? kodex.ConversationOpts
---@field rpc? kodex.RpcOpts
---@field on_conversation_started? fun(conversation_id: string)
---@field provider? kodex.Provider|kodex.provider.Opts|false

vim.g.kodex_opts = vim.g.kodex_opts

local defaults = {
  auto_reload = true,
  auto_register_cmp_sources = { "kodex", "buffer" },
  rpc = {
    cmd = { "codex", "app-server" },
    env = {},
  },
  conversation = {
    model = "gpt-4o-mini",
    include_apply_patch_tool = true,
  },
  contexts = {
    ["@buffer"] = function(context)
      return context:buffer()
    end,
    ["@buffers"] = function(context)
      return context:buffers()
    end,
    ["@cursor"] = function(context)
      return context:cursor_position()
    end,
    ["@selection"] = function(context)
      return context:visual_selection()
    end,
    ["@this"] = function(context)
      return context:this()
    end,
    ["@visible"] = function(context)
      return context:visible_text()
    end,
    ["@diagnostics"] = function(context)
      return context:diagnostics()
    end,
    ["@quickfix"] = function(context)
      return context:quickfix()
    end,
    ["@diff"] = function(context)
      return context:git_diff()
    end,
    ["@grapple"] = function(context)
      return context:grapple_tags()
    end,
  },
  prompts = {
    ask = { prompt = "", ask = true, submit = true },
    explain = { prompt = "Explain @this and its context", submit = true },
    optimize = { prompt = "Optimize @this for performance and readability", submit = true },
    document = { prompt = "Add comments documenting @this", submit = true },
    test = { prompt = "Add tests for @this", submit = true },
    review = { prompt = "Review @this for correctness and readability", submit = true },
    diagnostics = { prompt = "Explain @diagnostics", submit = true },
    fix = { prompt = "Fix @diagnostics", submit = true },
    diff = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
    buffer = { prompt = "@buffer" },
    this = { prompt = "@this" },
  },
  commands = {
    interrupt = "Interrupt the current conversation",
    reset = "Reset the Codex conversation",
  },
  input = {
    prompt = "Ask kodex: ",
    icon = "󰚩 ",
    win = {
      title_pos = "left",
      relative = "cursor",
      row = -3,
      col = 0,
    },
  },
  select = {
    prompt = "kodex: ",
    snacks = {
      preview = "preview",
      layout = {
        preset = "vscode",
        hidden = {},
      },
    },
  },
  permissions = {
    enabled = true,
    idle_delay_ms = 1000,
  },
  provider = false,
}

M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.g.kodex_opts or {})

local function merge_disables()
  local user_opts = vim.g.kodex_opts or {}
  for _, field in ipairs({ "contexts", "prompts", "commands" }) do
    if user_opts[field] and M.opts[field] then
      for key, value in pairs(user_opts[field]) do
        if value == false then
          M.opts[field][key] = nil
        end
      end
    end
  end
end

merge_disables()

if M.opts.provider and M.opts.provider ~= false and M.opts.provider.enabled then
  local provider = M.opts.provider[M.opts.provider.enabled]
  if provider and type(provider.cmd) ~= "string" then
    provider.cmd = "codex chat"
  end
end

return M
