local Promise = require("kodex.promise")
local client = require("kodex.cli.client")

local M = {}

local function resolved(value)
  local promise = Promise.new()
  promise:resolve(value)
  return promise
end

local function rejected(message)
  local promise = Promise.new()
  promise:reject(message)
  return promise
end

local function is_promise(value)
  return type(value) == "table" and value.is_promise == true
end

local builtin = {
  interrupt = function()
    return client.interrupt()
  end,
  reset = function()
    client.reset_conversation()
    return resolved(true)
  end,
}

local function execute_handler(handler)
  if type(handler) == "function" then
    local ok, result = pcall(handler)
    if not ok then
      return rejected(result)
    end
    if is_promise(result) then
      return result
    end
    return resolved(result)
  elseif type(handler) == "string" then
    return require("kodex.api.prompt").prompt(handler, { submit = true })
  end
  return rejected("Unsupported command handler type")
end

function M.command(name)
  if builtin[name] then
    return builtin[name]()
  end

  local commands = require("kodex.config").opts.commands or {}
  local handler = commands[name]
  if not handler then
    return rejected("Unknown codex command: " .. name)
  end
  return execute_handler(handler)
end

return M
