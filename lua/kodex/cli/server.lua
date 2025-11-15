local Promise = require("kodex.promise")

local M = {}

local function resolved(value)
  local promise = Promise.new()
  promise:resolve(value)
  return promise
end

function M.ensure()
  return resolved(true)
end

return M
