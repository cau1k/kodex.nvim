local M = {}

---@alias kodex.Status
---| "idle"
---| "error"
---| "responding"
---| "requesting_permission"

---@type nil|kodex.Status
local status = nil

-- TODO: Still seem to not get `session.idle` events reliably... So fallback to a timer.
-- I wonder if it's because of the SSE `on_stdout` edge case? We silently miss events, and it errors completely for some?
local idle_timer = vim.uv.new_timer()

local function normalize_event_type(payload)
  if not payload then
    return nil
  end

  local event = payload.event
  if type(event) == "table" then
    if type(event.type) == "string" then
      return event.type
    end
    if type(event.event) == "string" then
      return event.event
    end
    if type(event.status) == "string" then
      return event.status
    end
  elseif type(event) == "string" then
    return event
  end

  local params = payload.params
  if type(params) == "table" then
    if type(params.type) == "string" then
      return params.type
    end
    if type(params.event) == "string" then
      return params.event
    end
    if type(params.status) == "string" then
      return params.status
    end
  elseif type(params) == "string" then
    return params
  end

  if type(payload.method) == "string" then
    return payload.method
  end

  return nil
end

local function matches_any(text, patterns)
  for _, pattern in ipairs(patterns) do
    if text:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

function M.update(payload)
  local event_type = normalize_event_type(payload)
  if not event_type then
    return
  end

  local event_type_lower = event_type:lower()

  if matches_any(event_type_lower, { "session.idle", "server.connected", "response.completed", "response.finished", "conversation.completed" }) then
    status = "idle"
  elseif matches_any(event_type_lower, { "permission", "approval" }) then
    status = "requesting_permission"
  elseif matches_any(event_type_lower, { "error", "failed", "failure" }) then
    status = "error"
  elseif matches_any(event_type_lower, { "response", "message", "delta", "in_progress" }) then
    status = "responding"
  end

  idle_timer:stop()
  idle_timer:start(
    1000,
    0,
    vim.schedule_wrap(function()
      if status == "responding" then
        status = "idle"
      end
    end)
  )
end

function M.statusline()
  -- Kinda hard to distinguish these icons, but they're fun... :D
  -- And a nice one-char solution.
  if status == "idle" then
    return "󰚩"
  elseif status == "responding" then
    return "󱜙"
  elseif status == "requesting_permission" then
    return "󱚟"
  elseif status == "error" then
    return "󱚡"
  else
    return "󱚧"
  end
end

return M
