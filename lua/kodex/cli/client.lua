local Promise = require("kodex.promise")
local rpc = require("kodex.cli.rpc")
---@type { opts: kodex.Opts }
local config = require("kodex.config")
local permissions = require("kodex.permissions")

rpc.on_request("applyPatchApproval", permissions.apply_patch)
rpc.on_request("execCommandApproval", permissions.exec_command)

local M = {}

local state = {
  initializing = nil,
  conversation_id = nil,
  subscription_id = nil,
  conversation_promise = nil,
  notifications_registered = false,
}

local function resolved(value)
  local promise = Promise.new()
  promise:resolve(value)
  return promise
end

local function attach_notification_forwarder()
  if state.notifications_registered then
    return
  end
  rpc.on_notification(nil, function(message)
    vim.schedule(function()
      local event = message.params
      if type(event) == "table" and event.event ~= nil and event.type == nil then
        event = event.event
      end
      vim.api.nvim_exec_autocmds("User", {
        pattern = "KodexEvent",
        data = {
          method = message.method,
          params = message.params,
          event = event,
          conversation_id = state.conversation_id,
        },
      })
    end)
  end)
  state.notifications_registered = true
end

local function client_info()
  local version = vim.version()
  return {
    name = "kodex.nvim",
    title = "Neovim",
    version = string.format("%d.%d.%d", version.major, version.minor, version.patch),
  }
end

local function ensure_initialized()
  if rpc.is_initialized() then
    return resolved(true)
  end
  if state.initializing then
    return state.initializing
  end

  attach_notification_forwarder()

  state.initializing = rpc.ensure_started():next(function()
    return rpc.request("initialize", {
      clientInfo = client_info(),
    })
  end):next(function(result)
    rpc.notify("initialized", { capabilities = {} })
    rpc.mark_initialized()
    state.initializing = nil
    return result
  end):catch(function(err)
    state.initializing = nil
    error(err)
  end)

  return state.initializing
end

local function conversation_params()
  local opts = config.opts
  local conversation = opts.conversation or {}
  local cwd = vim.fn.getcwd()
  local params = {
    cwd = cwd,
  }
  if conversation.model then
    params.model = conversation.model
  end
  if conversation.reasoning_effort then
    params.reasoning_effort = conversation.reasoning_effort
  end
  if conversation.base_instructions then
    params.base_instructions = conversation.base_instructions
  end
  if conversation.developer_instructions then
    params.developer_instructions = conversation.developer_instructions
  end
  if conversation.approval_policy then
    params.approval_policy = conversation.approval_policy
  end
  if conversation.sandbox_policy then
    params.sandbox = conversation.sandbox_policy
  end
  if conversation.profile then
    params.profile = conversation.profile
  end
  if conversation.include_apply_patch_tool ~= nil then
    params.include_apply_patch_tool = conversation.include_apply_patch_tool
  end
  return params
end

local function subscribe_to_conversation()
  if state.subscription_id then
    return resolved(state.subscription_id)
  end
  if not state.conversation_id then
    return Promise.new(function(_, reject)
      reject("No active Codex conversation")
    end)
  end
  return rpc.request("addConversationListener", {
    conversation_id = state.conversation_id,
    experimental_raw_events = true,
  }):next(function(result)
    state.subscription_id = result.subscription_id or result.id
    return state.subscription_id
  end)
end

local function ensure_conversation()
  if state.conversation_id then
    return subscribe_to_conversation():next(function()
      return state.conversation_id
    end)
  end
  if state.conversation_promise then
    return state.conversation_promise
  end

  state.conversation_promise = ensure_initialized():next(function()
    return rpc.request("newConversation", conversation_params())
  end):next(function(result)
    state.conversation_id = result.conversation_id or result.id or result.conversation
    if not state.conversation_id then
      error("Codex did not return a conversation id")
    end
    return subscribe_to_conversation()
  end):next(function()
    local opts = require("kodex.config").opts
    if opts.on_conversation_started then
      pcall(opts.on_conversation_started, state.conversation_id)
    end
    return state.conversation_id
  end):catch(function(err)
    state.conversation_promise = nil
    error(err)
  end)

  return state.conversation_promise
end

local function ensure_items(text)
  return {
    {
      type = "text",
      text = text,
    },
  }
end

function M.send_message(text, metadata)
  return ensure_conversation():next(function(conversation_id)
    local params = {
      conversation_id = conversation_id,
      items = ensure_items(text),
    }
    local opts = require("kodex.config").opts
    if metadata and metadata.summary then
      params.summary = metadata.summary
    end
    if metadata and metadata.cwd then
      params.cwd = metadata.cwd
    end
    if metadata and metadata.approval_policy then
      params.approval_policy = metadata.approval_policy
    elseif opts.conversation and opts.conversation.approval_policy then
      params.approval_policy = opts.conversation.approval_policy
    end
    if metadata and metadata.reasoning_effort then
      params.reasoning_effort = metadata.reasoning_effort
    elseif opts.conversation and opts.conversation.reasoning_effort then
      params.reasoning_effort = opts.conversation.reasoning_effort
    end
    return rpc.request("sendUserMessage", params)
  end)
end

function M.send_turn(text, metadata)
  return ensure_conversation():next(function(conversation_id)
    local opts = require("kodex.config").opts
    local params = {
      conversation_id = conversation_id,
      items = ensure_items(text),
      cwd = metadata and metadata.cwd or vim.fn.getcwd(),
    }
    if metadata and metadata.summary then
      params.summary = metadata.summary
    end
    if metadata and metadata.approval_policy then
      params.approval_policy = metadata.approval_policy
    elseif opts.conversation and opts.conversation.approval_policy then
      params.approval_policy = opts.conversation.approval_policy
    end
    if metadata and metadata.reasoning_effort then
      params.reasoning_effort = metadata.reasoning_effort
    elseif opts.conversation and opts.conversation.reasoning_effort then
      params.reasoning_effort = opts.conversation.reasoning_effort
    end
    if metadata and metadata.model then
      params.model = metadata.model
    elseif opts.conversation and opts.conversation.model then
      params.model = opts.conversation.model
    end
    return rpc.request("sendUserTurn", params)
  end)
end

function M.interrupt()
  if not state.conversation_id then
    return resolved(false)
  end
  return rpc.request("interruptConversation", {
    conversation_id = state.conversation_id,
  })
end

function M.list_models()
  return ensure_initialized():next(function()
    return rpc.request("model/list", { pageSize = 100 })
  end)
end

function M.save_feedback(payload)
  return ensure_initialized():next(function()
    return rpc.request("feedback/upload", payload)
  end)
end

function M.reset_conversation()
  if state.subscription_id then
    pcall(rpc.request, "removeConversationListener", { subscription_id = state.subscription_id })
  end
  state.subscription_id = nil
  state.conversation_id = nil
  state.conversation_promise = nil
end

function M.shutdown()
  M.reset_conversation()
  rpc.shutdown()
end

return M
