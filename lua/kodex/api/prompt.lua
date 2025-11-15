local Promise = require("kodex.promise")
local client = require("kodex.cli.client")

local M = {}

---@class kodex.prompt.Opts
---@field submit? boolean
---@field context? kodex.Context
---@field summary? string
---@field cwd? string
---@field model? string
---@field reasoning_effort? string
---@field approval_policy? string

local function render_prompt(text, opts)
  local context = opts.context or require("kodex.context").new()
  local rendered = context:render(text)
  local plaintext = context.plaintext(rendered.output)
  return plaintext
end

local function send_prompt(plaintext, opts)
  local metadata = {
    summary = opts.summary,
    cwd = opts.cwd,
    model = opts.model,
    reasoning_effort = opts.reasoning_effort,
    approval_policy = opts.approval_policy,
  }
  if opts.submit == false then
    return client.send_message(plaintext, metadata)
  end
  return client.send_turn(plaintext, metadata)
end

---Prompt Codex CLI.
---@param prompt string
---@param opts? kodex.prompt.Opts
function M.prompt(prompt, opts)
  opts = opts or {}
  local referenced = require("kodex.config").opts.prompts[prompt]
  if referenced then
    prompt = referenced.prompt
    opts = vim.tbl_deep_extend("force", referenced, opts)
  end

  local ok, plaintext = pcall(render_prompt, prompt, opts)
  if not ok then
    vim.notify("Failed to prepare prompt: " .. tostring(plaintext), vim.log.levels.ERROR, { title = "kodex" })
    return Promise.new(function(_, reject)
      reject(plaintext)
    end)
  end

  return send_prompt(plaintext, opts):catch(function(err)
    vim.notify("Error sending prompt: " .. tostring(err), vim.log.levels.ERROR, { title = "kodex" })
  end)
end

return M
