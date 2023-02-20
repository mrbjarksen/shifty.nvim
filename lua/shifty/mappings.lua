local utils = require 'shifty.utils'
local config = require 'shifty.config'

local M = {}

M.has_attached = {}

M.disabled_bufs = {}

M.with_opts = function(opts, callback, ...)
  local prev_eventignore = vim.opt.eventignore:get()

  -- Set desired options (without triggering OptionSet)
  vim.opt.eventignore:append('OptionSet')
  local opts_restore = {}
  for opt, val in pairs(opts) do
    if vim.opt[opt] ~= val then
      opts_restore[opt] = vim.opt[opt]
      vim.opt[opt] = val
    end
  end
  vim.opt.eventignore = prev_eventignore

  local return_val = callback(...)

  local has_been_reset = false
  local reset_opts = function()
    if has_been_reset then return end
    vim.opt.eventignore:append('OptionSet')
    for opt, val in pairs(opts_restore) do
      vim.opt[opt] = val
    end
    vim.opt.eventignore = prev_eventignore
    has_been_reset = true
    pcall(vim.cmd.IndentBlanklineRefresh)
  end

  -- Schedule resetting options until it is safe
  -- (this should happen after func has finished)
  vim.schedule(function()
    -- Wait to reset options if in operator-pending mode
    if utils.is_in_op_pend() then
      local op_pend_group = vim.api.nvim_create_augroup('shifty_operator_pending_reset', { clear = true })
      vim.api.nvim_create_autocmd('ModeChanged', {
        group = op_pend_group,
        pattern = 'no*',
        callback = vim.schedule_wrap(function()
          if not utils.is_in_op_pend() then
            reset_opts()
            pcall(vim.api.nvim_del_augroup_by_id, op_pend_group)
          end
        end)
      })
    else
      reset_opts()
    end
  end)

  return return_val
end

M.with_opts_if = function(opts, cond, callback, ...)
  print("mapping")
  if cond then
    return M.with_opts(opts, callback, ...)
  else
    return callback(...)
  end
end

M.make_callback = function(rhs, is_expr, cond)
  local callback = rhs
  if type(rhs) == 'string' then
    if not is_expr then
      callback = function()
        return rhs
      end
    else
      callback = function()
        return vim.api.nvim_eval(rhs)
      end
    end
  end

  if cond == nil then
    return function()
      return M.with_opts(utils.get_opts(), callback)
    end
  else
    return function()
      return M.with_opts_if(utils.get_opts(), cond(), callback)
    end
  end
end

M.attach_mapping = function(bufnr, lhs, modes, cond)
  if type(modes) == 'string' then modes = { modes } end
  for _, mode in ipairs(modes) do
    local prev = vim.fn.maparg(lhs, mode, false, true)
    if bufnr == nil and prev.buffer == 1 then
      vim.keymap.del(mode, lhs, { buffer = true })
      local global_prev = vim.fn.maparg(lhs, mode, false, true)
      vim.fn.mapset(mode, false, prev)
      prev = global_prev
    end

    local rhs = prev.callback or prev.rhs or lhs

    local map_opts = {
      silent = prev.silent == 1 or nil,
      remap = prev.noremap == 0 or nil,
      script = prev.script == 1 or nil,
      nowait = prev.nowait == 1 or nil,
      expr = prev.expr == 1 or nil,
      replace_keycodes = prev.replace_keycodes == 1,
      buffer = bufnr,
      desc = "shifty.nvim override for " .. lhs,
    }

    if prev.desc or prev.rhs then
      map_opts.desc = map_opts.desc .. ", previously: " .. (prev.desc or prev.rhs)
    end

    if type(rhs) == 'string' and prev.expr ~= 1 then
      map_opts.remap = false
      map_opts.expr = true
      map_opts.replace_keycodes = true
    end

    local callback = M.make_callback(rhs, prev.expr == 1, cond)
    vim.keymap.set(mode, lhs, callback, map_opts)
  end
end

M.attach = function(bufnr)
  if M.has_attached[bufnr] then
    return
  end

  for lhs, modes in pairs(config.cur.embedded.mappings) do
    M.attach_mapping(bufnr, lhs, modes, function()
      if config.cur.embedded.enabled then
        return not M.disabled_bufs[bufnr]
      else
        return M.disabled_bufs[bufnr] == false
      end
    end)
  end

  M.has_attached[bufnr] = true
end

return M
