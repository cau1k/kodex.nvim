local Promise = require("kodex.promise")

---@class kodex.permissions.Opts
---@field enabled? boolean
---@field idle_delay_ms? integer
local M = {}

local function resolved(value)
  local promise = Promise.new()
  promise:resolve(value)
  return promise
end

local function wait_for_idle(timeout)
  return Promise.new(function(resolve)
    local idle_timer = vim.uv.new_timer()
    local key_listener

    local function cleanup()
      if idle_timer then
        idle_timer:stop()
        idle_timer:close()
      end
      if key_listener then
        vim.on_key(nil, key_listener)
      end
    end

    local function on_idle()
      cleanup()
      resolve(true)
    end

    local function restart_timer()
      idle_timer:stop()
      idle_timer:start(timeout, 0, vim.schedule_wrap(on_idle))
    end

    key_listener = vim.on_key(function()
      restart_timer()
    end)

    restart_timer()
  end)
end

local function select_decision(prompt)
  return Promise.new(function(resolve)
    vim.ui.select({ "Approve", "Reject", "Abort" }, {
      prompt = prompt,
    }, function(choice)
      if choice == "Approve" then
        resolve("approve")
      elseif choice == "Reject" then
        resolve("reject")
      else
        resolve("abort")
      end
    end)
  end)
end

local function handle_request(kind, params)
  local permissions_opts = require("kodex.config").opts.permissions or { enabled = true, idle_delay_ms = 1000 }
  if permissions_opts.enabled == false then
    return resolved({ decision = "reject" })
  end

  local idle_delay = permissions_opts.idle_delay_ms or 1000
  local notification = string.format("Codex requested %s permission — awaiting idle…", kind)
  vim.notify(notification, vim.log.levels.INFO, { title = "kodex", timeout = idle_delay })

  return wait_for_idle(idle_delay):next(function()
    local title = params.title or params.command or kind
    return select_decision(string.format("codex requesting %s: %s", kind, title))
  end):next(function(decision)
    return { decision = decision }
  end)
end

function M.apply_patch(params)
  return handle_request("apply patch", params)
end

function M.exec_command(params)
  return handle_request("command execution", params)
end

return M
