local M = {}
local api = vim.api
local state = require "showkeys.state"

local is_mouse = function(x)
  return x:match "Mouse" or x:match "Scroll" or x:match "Drag" or x:match "Release"
end

local function format_mapping(str)
  local keyformat = state.config.keyformat

  local str1 = string.match(str, "<(.-)>")
  if not str1 then
    return str
  end

  local before, after = string.match(str1, "([^%-]+)%-(.+)")

  if before then
    before = "<" .. before .. ">"
    before = keyformat[before] or before
    str1 = before .. " + " .. string.lower(after)
  end

  local str2 = string.match(str, ">(.+)")
  return str1 .. (str2 and (" " .. str2) or "")
end

M.gen_winconfig = function()
  local lines = vim.o.lines
  local cols = vim.o.columns
  state.config.winopts.width = state.w

  local pos = state.config.position

  if string.find(pos, "bottom") then
    state.config.winopts.row = lines - 5
  end

  if pos == "top-right" then
    state.config.winopts.col = cols - state.w - 3
  elseif pos == "top-center" or pos == "bottom-center" then
    state.config.winopts.col = math.floor(cols / 2) - math.floor(state.w / 2)
  elseif pos == "bottom-right" then
    state.config.winopts.col = cols - state.w - 3
  end
end

local update_win_w = function()
  -- Check and reset invalid window references
  if state.win and not api.nvim_win_is_valid(state.win) then
    state.win = nil
  end

  -- Early return if window becomes invalid
  if not state.win then
    return
  end

  local keyslen = #state.keys
  state.w = keyslen + 1 + (2 * keyslen) -- 2 spaces around each key

  for _, v in ipairs(state.keys) do
    state.w = state.w + vim.fn.strwidth(v.txt)
  end

  M.gen_winconfig()
  --[[
    Fix: Add a second check to ensure the window is still valid
    immediately before calling nvim_win_set_config. This prevents
    a race condition where the window could become invalid after
    the initial check but before the config is set.
  ]]
  if state.win and api.nvim_win_is_valid(state.win) then
    -- Wrap in pcall to prevent errors from invalid windows
    pcall(api.nvim_win_set_config, state.win, state.config.winopts)
  end
end

M.draw = function()
  local virt_txts = require "showkeys.ui"()

  if not state.extmark_id then
    api.nvim_buf_set_lines(state.buf, 0, -1, false, { " " })
  end

  local opts = { virt_text = virt_txts, virt_text_pos = "overlay", id = state.extmark_id }
  local id = api.nvim_buf_set_extmark(state.buf, state.ns, 0, 1, opts)

  if not state.extmark_id then
    state.extmark_id = id
  end
end

M.redraw = function()
  update_win_w()
  M.draw()
end

M.clear_and_close = function()
  state.keys = {}
  M.redraw()
  local tmp = state.win
  state.win = nil
  -- Add window validity check before closing
  if tmp and api.nvim_win_is_valid(tmp) then
    api.nvim_win_close(tmp, true)
  end
end

M.parse_key = function(char)
  local opts = state.config

  if vim.tbl_contains(opts.excluded_modes, vim.api.nvim_get_mode().mode) then
    if state.win then
      M.clear_and_close()
    end
    return
  end

  local key = vim.fn.keytrans(char)

  if is_mouse(key) or key == "" then
    return
  end

  key = opts.keyformat[key] or key
  key = format_mapping(key)

  local arrlen = #state.keys
  local last_key = state.keys[arrlen]

  if opts.show_count and last_key and key == last_key.key then
    local count = (last_key.count or 1) + 1

    state.keys[arrlen] = {
      key = key,
      txt = count .. " " .. key,
      count = count,
    }
  else
    if arrlen == opts.maxkeys then
      table.remove(state.keys, 1)
    end

    table.insert(state.keys, { key = key, txt = key })
  end

  M.redraw()
end

return M
