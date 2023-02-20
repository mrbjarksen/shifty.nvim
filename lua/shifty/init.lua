local config = require 'shifty.config'
local utils = require 'shifty.utils'

local M = {}

M.setup = function(user_config)
  config.merge(user_config)

  local shifty_augroup = vim.api.nvim_create_augroup('shifty', { clear = true })

  vim.api.nvim_create_autocmd('FileType', {
    group = shifty_augroup,
    callback = function(a)
      local opts = utils.get_ft_opts(a.match)
      for opt, val in pairs(opts) do
        if vim.bo[a.buf][opt] ~= val then
          vim.bo[a.buf][opt] = val
        end
      end
    end,
    desc = "Set shifty.nvim options",
  })

  if config.cur.embedded.enabled then
    local mappings = require 'shifty.mappings'
    vim.api.nvim_create_autocmd('FileType', {
      group = shifty_augroup,
      callback = function(a)
        -- Mappings should attach after other mappings
        -- vim.schedule(function()
          mappings.attach(a.buf)
        -- end)
      end,
      desc = "Attach shifty.nvim mappings",
    })
  end

  vim.api.nvim_exec_autocmds('FileType', {
    group = shifty_augroup
  })

  vim.api.nvim_create_user_command('Shifty', function(cmd)
    if #cmd.fargs == 0 then
      utils.error("Argument missing")
      return
    elseif #cmd.fargs > 1 then
      utils.error("Too many arguments")
      return
    end

    local arg = cmd.fargs[1]
    local bufnr = cmd.bang and nil or 0

    if arg == 'enable' then
      M.enable(bufnr)
    elseif arg == 'disable' then
      M.disable(bufnr)
    else
      utils.error("Invalid argument `%s`", arg)
    end
  end, {
    nargs = '*',
    bang = true,
    complete = function(_, cmdline, _)
      if cmdline:find('enable') or cmdline:find('disable') then
        return {}
      end
      return { 'enable', 'disable' }
    end,
    desc = "Enable/disable shifty.nvim mappings",
  })
  print("loaded")
end

M.enable = function(bufnr)
  local mappings = require 'shifty.mappings'
  if bufnr == nil then
    config.cur.embedded.enabled = true
    mappings.disabled_bufs = {}
    for bufnr in vim.api.nvim_list_bufs() do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        mappings.attach(bufnr)
      end
    end
  else
    if bufnr == 0 then
      bufnr = vim.api.nvim_get_current_buf()
    end
    mappings.disabled_bufs[bufnr] = false
    mappings.attach(bufnr)
  end
end

M.disable = function(bufnr)
  local mappings = require 'shifty.mappings'
  if bufnr == nil then
    config.cur.embedded.enabled = false
  else
    if bufnr == 0 then
      bufnr = vim.api.nvim_get_current_buf()
    end
    mappings.disabled_bufs[bufnr] = true
  end
end

return M
