local M = {}
local api = vim.api

local state = require "showkeys.state"
local utils = require "showkeys.utils"

state.ns = api.nvim_create_namespace "Showkeys"

M.setup = function(opts)
  state.config = vim.tbl_deep_extend("force", state.config, opts or {})
end

M.open = function()
  state.visible = true
  state.buf = api.nvim_create_buf(false, true)
  utils.gen_winconfig()
  vim.bo[state.buf].ft = "Showkeys"

  state.timer = vim.loop.new_timer()
  state.on_key = vim.on_key(function(_, char)
    -- Added check: Verify window exists and is valid
    if not state.win or not api.nvim_win_is_valid(state.win) then
      -- Cleanup invalid window reference
      if state.win then
        pcall(api.nvim_win_close, state.win, true) 
      end
      -- Recreate window if missing/invalid
      state.win = api.nvim_open_win(state.buf, false, state.config.winopts)
      api.nvim_set_option_value("winhl", state.config.winhl, { win = state.win })
    end

    utils.parse_key(char)

    state.timer:stop()
    state.timer:start(state.config.timeout * 1000, 0, vim.schedule_wrap(utils.clear_and_close))
  end)

  api.nvim_set_hl(0, "SkInactive", { default = true, link = "Visual" })
  api.nvim_set_hl(0, "SkActive", { default = true, link = "pmenusel" })

  local augroup = api.nvim_create_augroup("ShowkeysAu", { clear = true })

  api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      if state.win then
        utils.redraw()
      end
    end,
  })

  api.nvim_create_autocmd("TabEnter", {
    group = augroup,
    callback = function()
      if state.win then
        M.close()
        M.open()
      end
    end,
  })

  api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function()
      if state.win then
        M.close()
        M.open()
      end
    end,
    buffer = state.buf,
  })
end

M.close = function()
  api.nvim_del_augroup_by_name "ShowkeysAu"
  state.timer:stop()
  state.keys = {}
  state.w = 1
  state.extmark_id = nil
  vim.cmd("bd" .. state.buf)
  vim.on_key(nil, state.on_key)
  state.visible = false
  state.win = nil
end

M.toggle = function()
  M[state.visible and "close" or "open"]()
end

return M