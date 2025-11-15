pcall(require, "kodex.types.snacks")

---`kodex.nvim` public API.
local M = {}

M.ask = require("kodex.ui.ask").ask
M.select = require("kodex.ui.select").select

M.prompt = require("kodex.api.prompt").prompt
M.command = require("kodex.api.command").command

M.toggle = require("kodex.provider").toggle
M.start = require("kodex.provider").start
M.show = require("kodex.provider").show

M.statusline = require("kodex.status").statusline

return M
