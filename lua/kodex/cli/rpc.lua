local Promise = require("kodex.promise")

local unpack = table.unpack or unpack

local M = {}

local job_id
local next_id = 1
local pending = {}
local notification_handlers = {}
local request_handlers = {}
local initialized = false
local stderr_buffer = {}

local function encode(value)
  if vim.json and type(vim.json.encode) == "function" then
    return vim.json.encode(value)
  end
  return vim.fn.json_encode(value)
end

local function decode(value)
  if vim.json and type(vim.json.decode) == "function" then
    return vim.json.decode(value)
  end
  return vim.fn.json_decode(value)
end

local function is_promise(value)
  return type(value) == "table" and value.is_promise == true
end

local function resolved(value)
  local promise = Promise.new()
  promise:resolve(value)
  return promise
end

local function log_error(message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.ERROR, { title = "kodex" })
  end)
end

local function log_info(message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.INFO, { title = "kodex" })
  end)
end

local function reset_state()
  for id, waiter in pairs(pending) do
    if waiter.reject then
      waiter.reject("codex app-server stopped")
    end
  end
  pending = {}
  job_id = nil
  initialized = false
end

local function send_message(payload)
  if not job_id then
    return false
  end
  local ok, encoded = pcall(encode, payload)
  if not ok then
    log_error("Failed to encode Codex request: " .. tostring(encoded))
    return false
  end
  local line = encoded .. "\n"
  local sent = vim.fn.chansend(job_id, line)
  if sent < 0 then
    log_error("Failed to write to codex app-server: " .. tostring(sent))
    return false
  end
  return true
end

local function handle_response(message)
  local waiter = pending[message.id]
  if not waiter then
    return
  end
  pending[message.id] = nil
  if message.error then
    if waiter.reject then
      waiter.reject(message.error)
    end
  else
    if waiter.resolve then
      waiter.resolve(message.result)
    end
  end
end

local function invoke_handlers(handlers, message)
  if not handlers then
    return
  end
  for _, handler in ipairs(handlers) do
    local ok, err = pcall(handler, message)
    if not ok then
      log_error("Notification handler failed for " .. (message.method or "<unknown>") .. ": " .. tostring(err))
    end
  end
end

local function handle_notification(message)
  invoke_handlers(notification_handlers["*"], message)
  invoke_handlers(notification_handlers[message.method], message)
end

local function respond(id, payload)
  send_message({ id = id, result = payload })
end

local function respond_error(id, err)
  send_message({ id = id, error = err or { code = -32603, message = "Internal error" } })
end

local function handle_server_request(message)
  local handler = request_handlers[message.method]
  if not handler then
    respond_error(message.id, { code = -32601, message = "Method not found: " .. message.method })
    return
  end

  local ok, result = pcall(handler, message.params)
  if not ok then
    respond_error(message.id, { code = -32603, message = tostring(result) })
    return
  end

  if is_promise(result) then
    result:next(function(value)
      respond(message.id, value)
    end):catch(function(err)
      respond_error(message.id, { code = -32000, message = tostring(err) })
    end)
  else
    respond(message.id, result)
  end
end

local function handle_message(line)
  if line == nil or line == "" then
    return
  end

  local ok, message = pcall(decode, line)
  if not ok then
    log_error("Failed to decode Codex message: " .. tostring(message) .. "\n" .. line)
    return
  end

  if message.id and (message.result ~= nil or message.error ~= nil) then
    handle_response(message)
  elseif message.id and message.method then
    handle_server_request(message)
  elseif message.method then
    handle_notification(message)
  end
end

local function start_process()
  if job_id then
    return
  end

  local config = require("kodex.config").opts
  local cmd = config.rpc and config.rpc.cmd or { "codex", "app-server" }
  if type(cmd) == "string" then
    cmd = vim.split(cmd, " ", { plain = true, trimempty = true })
  end

  job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = vim.schedule_wrap(function(_, data)
      for _, line in ipairs(data) do
        handle_message(line)
      end
    end),
    on_stderr = vim.schedule_wrap(function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(stderr_buffer, line)
        end
      end
      if #stderr_buffer > 100 then
        local start_index = math.max(1, #stderr_buffer - 99)
        stderr_buffer = { unpack(stderr_buffer, start_index, #stderr_buffer) }
      end
    end),
    on_exit = vim.schedule_wrap(function(_, code)
      if code ~= 0 then
        local details = table.concat(stderr_buffer, "\n")
        if details ~= "" then
          log_error("codex app-server exited with code " .. code .. "\n" .. details)
        else
          log_error("codex app-server exited with code " .. code)
        end
      else
        log_info("codex app-server exited")
      end
      reset_state()
    end),
  })

  if job_id <= 0 then
    job_id = nil
    error("Failed to start codex app-server")
  end

  stderr_buffer = {}
end

function M.ensure_started()
  if job_id then
    return resolved(true)
  end

  return Promise.new(function(resolve, reject)
    local ok, err = pcall(start_process)
    if not ok then
      reject(err)
    else
      resolve(true)
    end
  end)
end

function M.request(method, params)
  return Promise.new(function(resolve, reject)
    M.ensure_started():next(function()
      local id = next_id
      next_id = next_id + 1
      pending[id] = { resolve = resolve, reject = reject }
      if not send_message({ id = id, method = method, params = params }) then
        pending[id] = nil
        reject("Failed to send request")
      end
    end):catch(reject)
  end)
end

function M.notify(method, params)
  M.ensure_started():next(function()
    send_message({ method = method, params = params })
  end)
end

function M.on_notification(method, handler)
  method = method or "*"
  notification_handlers[method] = notification_handlers[method] or {}
  table.insert(notification_handlers[method], handler)
end

function M.on_request(method, handler)
  request_handlers[method] = handler
end

function M.is_initialized()
  return initialized
end

function M.mark_initialized()
  initialized = true
end

function M.shutdown()
  if job_id then
    vim.fn.jobstop(job_id)
    reset_state()
  end
end

return M
