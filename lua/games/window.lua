local config = require('games.config')

---@class games.window
local M = {}

---The window ID.
---@type integer|nil
M.win = nil

---The buffer ID.
---@type integer|nil
M.buf = nil

---Calculates the window size.
---@return integer, integer # height, width
local function calc_window_size()
  local height = config.options.window.height
  local width = config.options.window.width

  ---Uses relative size if between 0 and 1. Otherwise, uses absolute size.
  if height >= 0 and height <= 1 then height = math.floor(vim.o.lines * height) end
  if width >= 0 and width <= 1 then width = math.floor(vim.o.columns * width) end

  -- Limits the size between min and max.
  local min_height = vim.tbl_get(config.options, 'window', 'min', 'height') or 15
  local min_width = vim.tbl_get(config.options, 'window', 'min', 'width') or 30
  local max_height = vim.tbl_get(config.options, 'window', 'max', 'height') or 30
  local max_width = vim.tbl_get(config.options, 'window', 'max', 'width') or 60
  height = math.floor(math.max(min_height, math.min(max_height, height)))
  width = math.floor(math.max(min_width, math.min(max_width, width)))

  -- Uses 3:4 aspect ratio.
  if not vim.tbl_get(config.options, 'window', 'ignore_aspect_ratio') then
    local aspect_ratio = 3.0 / 4.0
    local block_aspect_ratio = 2.0
    height = math.floor(width * aspect_ratio / block_aspect_ratio)
  end

  return height, width
end

---Opens a floating window.
---@return boolean # True if the window was opened successfully, false otherwise.
function M.open()
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

  -- Calculates the window size.
  local height, width = calc_window_size()

  -- Calculates the window position to center it.
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Gets the border style.
  local border = vim.tbl_get(config.options, 'window', 'border') or 'rounded'

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
  if size.width < width or size.height < height then
    M.close()
    vim.notify('Window size is too small for the game', vim.log.levels.ERROR)
    return false
  end

  -- Sets special window options.
  vim.api.nvim_set_option_value('winfixbuf', true, { win = M.win })
  vim.api.nvim_set_option_value('winfixwidth', true, { win = M.win })
  vim.api.nvim_set_option_value('winfixheight', true, { win = M.win })

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
