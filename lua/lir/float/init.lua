local actions = require 'lir.actions'
local lvim = require 'lir.vim'
local config = require 'lir.config'

local a = vim.api

---@class lir_float
local float = {}

--- borderchars にハイライトをつけたテーブルを返す
--- { {'=', 'LirFloatBorder'}, {'|', 'LirFloatBorder'}, ... } のようなテーブルを作る
---@param borderchars table
local make_border_opts = function(borderchars)
  return vim.tbl_map(function(char)
    return { char, 'LirFloatBorder' }
  end, borderchars)
end

--- オプションのデフォルト値を返す
---@param opts table
---@return table
local function default_opts(opts)
  vim.validate {
    percentage = { opts.percentage, 'n' },
    borderchars = { opts.borderchars, 't' },
  }

  local width = math.floor(vim.o.columns * opts.percentage)
  local height = math.floor(vim.o.lines * opts.percentage)

  local top = math.floor(((vim.o.lines - height) / 2) - 1)
  local left = math.floor((vim.o.columns - width) / 2)

  local result = {
    relative = 'editor',
    row      = top,
    col      = left,
    width    = width,
    height   = height,
    style    = 'minimal',
    border   = make_border_opts(opts.borderchars)
  }

  return result
end

--- 中央配置のウィンドウを開く
---@param opts table
---@return number win_id
local function open_centered_win(opts)
  vim.validate {
    percentage = { opts.percentage, 'n' },
    winblend = { opts.winblend, 'n' },
    borderchars = { opts.borderchars, 't' },
    shadow = { opts.shadow, 'b' },
  }

  local win_opts = default_opts(opts)

  if opts.shadow then
    win_opts.border = 'shadow'
  end

  local bufnr = a.nvim_create_buf(false, true)
  local win_id = a.nvim_open_win(bufnr, true, win_opts)

  vim.cmd('setlocal nocursorcolumn')
  a.nvim_win_set_option(win_id, 'winblend', opts.winblend)

  vim.cmd(
    string.format(
      "autocmd WinLeave <buffer> silent! execute 'bdelete! %s'",
      bufnr
    )
  )

  return win_id
end


---@return number
local function find_lir_float_win()
  for _, win in ipairs(a.nvim_tabpage_list_wins(0)) do
    local buf = a.nvim_win_get_buf(win)
    local is_float = vim.F.npcall(a.nvim_win_get_var, win, 'lir_is_float')
    if a.nvim_buf_get_option(buf, 'filetype') == 'lir' and is_float then
      return win
    end
  end
  return nil
end

---@param dir string
function float.toggle(dir)
  local float_win = find_lir_float_win()
  if float_win then
    a.nvim_set_current_win(float_win)
    actions.quit()
  else
    float.init(dir)
  end
end

---@param dir_path? string
function float.init(dir_path)
  local dir, file, old_win
  if vim.bo.filetype == 'lir' then
    dir = lvim.get_context().dir
    file = lvim.get_context():current_value()

    if not vim.w.lir_is_float then
      old_win = a.nvim_get_current_win()
    end
  else
    dir = dir_path or vim.fn.expand('%:p:h')
    file = vim.fn.expand('%:p')
  end

  local win_id = open_centered_win({
    percentage = config.values.float.size_percentage,
    winblend = config.values.float.winblend,
    borderchars = config.values.float.borderchars,
    shadow = config.values.float.shadow,
  })

  vim.t.lir_float_winid = win_id
  -- To move the cursor
  if file then
    vim.w.lir_file_jump_cursor = file
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(dir))
  vim.w.lir_is_float = true

  a.nvim_win_set_option(win_id, 'winhl', 'Normal:LirFloatNormal,EndOfBuffer:LirFloatNormal')

  -- 空バッファに置き換える
  if old_win then
    a.nvim_win_set_buf(old_win, a.nvim_create_buf(true, false))
  end
end

return float
