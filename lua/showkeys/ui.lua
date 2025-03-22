-- Added API reference for validity checks
local api = vim.api  
local state = require "showkeys.state"

return function()
  -- Early return if window is invalid
  if not state.win or not api.nvim_win_is_valid(state.win) then
    return {}
  end

  -- Early return if buffer is invalid
  if not state.buf or not api.nvim_buf_is_valid(state.buf) then
    return {}
  end

  local list = state.keys
  local list_len = #list
  local virt_txts = {}

  for i, val in ipairs(list) do
    local hl = i == list_len and "skactive" or "skinactive"
    table.insert(virt_txts, { " " .. val.txt .. " ", hl })
    table.insert(virt_txts, { " " })
  end

  return virt_txts
end