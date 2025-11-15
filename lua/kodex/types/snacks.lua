---@meta

---@class KodexSnacksInputOpts
---@field enabled? boolean
---@field prompt? string
---@field icon? string
---@field win? table
local SnacksInputOpts = {}
---@alias snacks.input.Opts KodexSnacksInputOpts

---@class KodexSnacksUiSelectOpts
---@field prompt? string
---@field format_item? fun(item:any):string
local SnacksUiSelectOpts = {}
---@alias snacks.picker.ui_select.Opts KodexSnacksUiSelectOpts

---@alias snacks.picker.Text { [1]: string, [2]?: string }

---@class KodexSnacksExtmark
---@field row integer
---@field col integer
---@field end_col integer
---@field hl_group? string
local SnacksExtmark = {}
---@alias snacks.picker.Extmark KodexSnacksExtmark

---@class KodexSnacksTerminalOpts
---@field cmd? string|string[]
---@field env? table<string,string>
local SnacksTerminalOpts = {}
---@alias snacks.terminal.Opts KodexSnacksTerminalOpts

---@class KodexClientAgent
---@field id string
---@field name string
---@field description? string
local Agent = {}
---@alias kodex.client.Agent KodexClientAgent

return {
  SnacksInputOpts = SnacksInputOpts,
  SnacksUiSelectOpts = SnacksUiSelectOpts,
  SnacksExtmark = SnacksExtmark,
  SnacksTerminalOpts = SnacksTerminalOpts,
  Agent = Agent,
}
