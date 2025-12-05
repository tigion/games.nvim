local config = require('games.config')

---@class games.window
local M = {}

---The window ID.
---@type integer|nil
M.win = nil

---The buffer ID.
---@type integer|nil
M.buf = nil

---Calculates the window size and position.
---@return integer, integer, integer, integer # height, width, row, col
local function calc_window_size_and_pos()
  local lines = vim.o.lines
  local columns = vim.o.columns
  local cmd_height = vim.o.cmdheight
  local border = vim.tbl_get(config.options, 'window', 'border') or vim.o.winborder
  local border_size = (border ~= 'none' and border ~= '') and 2 or 0
  local padding_v, padding_h = 1, 2

  local usable_height = lines - cmd_height - border_size - 2 * padding_v
  local usable_width = columns - border_size - 2 * padding_h

  local height = config.options.window.height
  local width = config.options.window.width

  ---Uses relative size if between 0 and 1. Otherwise, uses absolute size.
  if height >= 0 and height <= 1 then height = math.floor(usable_height * height) end
  if width >= 0 and width <= 1 then width = math.floor(usable_width * width) end

  -- Limits the size between min and max.
  local min_height = vim.tbl_get(config.options, 'window', 'min', 'height') or 15
  local min_width = vim.tbl_get(config.options, 'window', 'min', 'width') or 30
  local max_height = vim.tbl_get(config.options, 'window', 'max', 'height') or 30
  local max_width = vim.tbl_get(config.options, 'window', 'max', 'width') or 60
  if max_height < 1 or max_height > usable_height then max_height = usable_height end
  if max_width < 1 or max_width > usable_width then max_width = usable_width end
  height = math.floor(math.max(min_height, math.min(max_height, height)))
  width = math.floor(math.max(min_width, math.min(max_width, width)))

  -- Uses 3:4 aspect ratio.
  if not vim.tbl_get(config.options, 'window', 'ignore_34_aspect_ratio') then
    local aspect_ratio = 3.0 / 4.0
    local block_aspect_ratio = 2.0
    local win_aspect_ratio = (height * block_aspect_ratio) / width
    if win_aspect_ratio < aspect_ratio then
      width = math.floor(height * block_aspect_ratio / aspect_ratio)
    else
      height = math.floor(width * aspect_ratio / block_aspect_ratio)
    end
  end

  -- Calculates the window position to center it.
  local row = math.floor((lines - height - cmd_height - border_size) / 2)
  local col = math.floor((columns - width - border_size) / 2)

  return height, width, row, col
end

---Opens a floating window.
---@return boolean # True if the window was opened successfully, false otherwise.
function M.open()
  -- Checks if a game is already active.
  if vim.g.tigion_games_is_active == true then return false end

  -- Creates a new buffer.
  M.buf = vim.api.nvim_create_buf(false, true)
  if M.buf == 0 then
    vim.notify('Failed to create buffer', vim.log.levels.ERROR)
    return false
  end

  -- Sets the buffer options.
  vim.bo[M.buf].buftype = 'nofile'
  vim.bo[M.buf].bufhidden = 'wipe'
  vim.bo[M.buf].modifiable = false
  vim.bo[M.buf].filetype = 'game_canvas'
  vim.bo[M.buf].swapfile = false
  vim.bo[M.buf].undofile = false

  -- Calculates the window size and position.
  local height, width, row, col = calc_window_size_and_pos()

  -- Gets the border style.
  local border = vim.tbl_get(config.options, 'window', 'border') or vim.o.winborder

  -- Sets the window options.
  local opts = {
    style = 'minimal',
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = border,
  }

  -- Opens the floating window with the given options.
  M.win = vim.api.nvim_open_win(M.buf, true, opts)
  if not M.win then
    vim.notify('Failed to open float window', vim.log.levels.ERROR)
    return false
  end

  -- Checks the minimum size requirements.
  local size = M.size()

  -- local win_border = vim.api.nvim_win_get_config(M.win).border or {}
  -- local has_border = #win_border > 0
  -- local cmdheight = vim.go.cmdheight
  -- if border ~= 'none' then
  --   width = width - 2
  --   height = height - 2
  -- end

  if size.width < width or size.height < height then
    M.close()
    vim.notify('Window size is too small for the game', vim.log.levels.ERROR)
    return false
  end

  -- Sets special window options.
  vim.api.nvim_set_option_value('winfixbuf', true, { win = M.win })
  vim.api.nvim_set_option_value('winfixwidth', true, { win = M.win })
  vim.api.nvim_set_option_value('winfixheight', true, { win = M.win })

  -- Adds an autocmd to close the window when leaving it.
  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = M.buf,
    callback = function()
      -- Marks the game as inactive.
      vim.g.tigion_games_is_active = false
    end,
  })

  -- Marks the game as active.
  vim.g.tigion_games_is_active = true

  return true
end

---Returns the size of the window.
---@return {width: integer, height: integer}
function M.size()
  local width = vim.api.nvim_win_get_width(M.win)
  local height = vim.api.nvim_win_get_height(M.win)
  return { width = width, height = height }
end

---Checks if the window is valid.
---@return boolean
function M.win_is_valid() return vim.api.nvim_win_is_valid(M.win) end

---Checks if the buffer is valid.
---@return boolean
function M.buf_is_valid() return vim.api.nvim_buf_is_valid(M.buf) end

---Closes the floating window and deletes the buffer.
function M.close()
  if M.win_is_valid() then vim.api.nvim_win_close(M.win, true) end
  if M.buf_is_valid() then vim.api.nvim_buf_delete(M.buf, { force = true }) end
  M.win = nil
  M.buf = nil

  -- Marks the game as inactive.
  vim.g.tigion_games_is_active = false
end

---Sets the window title.
---@param title string The title to set.
function M.set_title(title)
  if M.win_is_valid() then vim.api.nvim_win_set_config(M.win, {
    title = title,
    title_pos = 'center',
  }) end
end

---Sets the window footer.
---@param footer string The footer to set.
function M.set_footer(footer)
  if M.win_is_valid() then vim.api.nvim_win_set_config(M.win, {
    footer = footer,
    footer_pos = 'center',
  }) end
end

---Redraws the buffer content.
function M.redraw_buffer()
  vim.api.nvim_buf_call(M.buf, function() vim.cmd('redraw') end)
end

return M
