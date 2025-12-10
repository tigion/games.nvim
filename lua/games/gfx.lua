-- Graphics module for a grid based canvas in a Neovim window.
--
-- Uses block characters to represent pixels.
-- Supports single block, half block, and double block rendering.
--
-- Provides functions to:
-- - `init()` ... initialize the canvas
-- - `clear()` ... clear the canvas
-- - `draw_point(x, y)` ... draw a point at (x, y)
-- - `remove_point(x, y)` ... remove a point at (x, y)
-- - `draw_text(text, x, y, align)` ... draw text at (x, y) with alignment
-- - `center_text_in_line(text, y)` ... center text in a specific line
-- - `center_text_in_canvas(texts)` ... center multiple lines of text in the canvas
-- - `is_same_pos(x1, y1, x2, y2, check_full_block)` ... check if two positions are the same
-- - `block_positions(x, y)` ... get block positions for a coordinate
-- - `block_base_position(x, y)` ... get base block position for a coordinate
-- - `refresh()` ... refresh the canvas display

local window = require('games.window')

---@class games.gfx
local M = {}

local types = {
  singleblock = {
    factor = { width = 1.0, height = 1.0 },
  },
  halfblock = {
    factor = { width = 1.0, height = 2.0 },
  },
  doubleblock = {
    factor = { width = 0.5, height = 1.0 },
  },
}

local canvas = {
  type = nil,
  size = { width = 0, height = 0 },
  factor = { width = 0.0, height = 0.0 },
  real_size = { width = 0, height = 0 },
  cache = {},
}

-- ----------------------------------------------------------------------------

M.canvas = {}

function M.canvas.size()
  local width = canvas.size.width -- window.width() * M.canvas.factor.width
  local height = canvas.size.height -- window.height() * M.canvas.factor.height
  return { width = width, height = height }
end

function M.canvas.save(name)
  local lines = vim.api.nvim_buf_get_lines(window.buf, 0, -1, false)
  canvas.cache[name] = lines
end

function M.canvas.load(name)
  local lines = canvas.cache[name]
  if lines == nil then return end
  vim.bo[window.buf].modifiable = true
  vim.api.nvim_buf_set_lines(window.buf, 0, -1, false, lines)
  vim.bo[window.buf].modifiable = false
end

function M.canvas.remove(name) canvas.cache[name] = nil end

function M.canvas.list()
  local names = {}
  for name, _ in pairs(canvas.cache) do
    table.insert(names, name)
  end
  return names
end

function M.canvas.clear() canvas.cache = {} end

-- ----------------------------------------------------------------------------

local core = {}

function core.get_cursor()
  -- The character position is needed instead of the byte position.
  local cursor = vim.fn.getcursorcharpos(window.win)
  return { row = cursor[2], col = cursor[3] }
end

function core.get_char(row, col)
  local line = vim.api.nvim_buf_get_lines(window.buf, row, row + 1, false)[1] or ''
  local start_byte_offset = vim.str_byteindex(line, 'utf-32', col)
  local end_byte_offset = vim.str_byteindex(line, 'utf-32', col + 1)
  return vim.api.nvim_buf_get_text(window.buf, row, start_byte_offset, row, end_byte_offset, {})[1] or nil
end

-- Sets the character at the given position in the buffer.
function core.set_char(row, col, char)
  local char_length = vim.str_utfindex(char, 'utf-32')
  if char_length > 1 then char = char:sub(1, vim.str_utfindex(char, 'utf-32', 1)) end
  core.set_text(row, col, char)
end

function core.get_double_char(col, row)
  local line = vim.api.nvim_buf_get_lines(window.buf, row, row + 1, false)[1] or ''
  local start_byte_offset = vim.str_byteindex(line, 'utf-32', col)
  local end_byte_offset = vim.str_byteindex(line, 'utf-32', col + 2)
  return vim.api.nvim_buf_get_text(window.buf, row, start_byte_offset, row, end_byte_offset, {})[1] or nil
end

function core.set_double_char(row, col, char)
  local char_length = vim.str_utfindex(char, 'utf-32')
  if char_length > 2 then char = char:sub(1, vim.str_utfindex(char, 'utf-32', 2)) end
  core.set_text(col, row, char)
end

function core.set_text(row, col, text)
  -- Gets the number of chars instead of bytes.
  local text_length = vim.str_utfindex(text, 'utf-32')
  if text_length == 0 then return end

  -- Checks if the text is out of bounds.
  if row < 0 or row >= canvas.real_size.height then return end
  if col < 0 - text_length or col >= canvas.real_size.width then return end

  -- Truncates the text if it exceeds the canvas width.
  if col < 0 then
    local abs_col = 0 - col
    text = text:sub(vim.str_utfindex(text, 'utf-32', abs_col) + 1, text_length)
    text_length = vim.str_utfindex(text, 'utf-32')
    col = 0
  elseif col + text_length > canvas.real_size.width then
    text = text:sub(1, vim.str_utfindex(text, 'utf-32', canvas.real_size.width - col))
    text_length = vim.str_utfindex(text, 'utf-32')
  end

  -- Gets the line at the specified row.
  local line = vim.api.nvim_buf_get_lines(window.buf, row, row + 1, false)[1] or ''

  -- Calculates the byte offsets based on character indices.
  local start_byte_offset = vim.str_byteindex(line, 'utf-32', col)
  local end_byte_offset = vim.str_byteindex(line, 'utf-32', col + text_length)

  -- Sets the text in the buffer at the specified position.
  vim.bo[window.buf].modifiable = true
  vim.api.nvim_buf_set_text(window.buf, row, start_byte_offset, row, end_byte_offset, { text })
  vim.bo[window.buf].modifiable = false
end

-- ----------------------------------------------------------------------------

local helper = {}

function helper.is_out_of_bounds(x, y) return x < 0 or x > canvas.size.width - 1 or y < 0 or y > canvas.size.height - 1 end

function helper.is_empty(text) return text == nil or text == '' end

-- ----------------------------------------------------------------------------

local singleblock = {}

singleblock.icon = {
  empty = ' ',
  full = '█',
  -- gradient = {'░', '▒', '▓'},
}

function singleblock.set_point(x, y, active)
  active = active == nil and true or active == true
  if helper.is_out_of_bounds(x, y) then return end
  local row, col = y, x
  local existing_char = core.get_char(row, col)
  if active == true then
    if existing_char == nil or existing_char == singleblock.icon.full then return end
    core.set_char(row, col, singleblock.icon.full)
  else
    if existing_char == nil or existing_char == singleblock.icon.empty then return end
    core.set_char(row, col, singleblock.icon.empty)
  end
end

function singleblock.add_point(x, y) singleblock.set_point(x, y, true) end

function singleblock.remove_point(x, y) singleblock.set_point(x, y, false) end

-- ----------------------------------------------------------------------------

local doubleblock = {}

doubleblock.icon = {
  empty = '  ',
  full = '██',
}

function doubleblock.set_point(x, y, active)
  active = active == nil and true or active == true
  if helper.is_out_of_bounds(x, y) then return end
  local row, col = y, math.floor(x / canvas.factor.width)
  local existing_char = core.get_char(row, col)
  if active == true then
    if existing_char == nil or existing_char == doubleblock.icon.full then return end
    core.set_double_char(row, col, doubleblock.icon.full)
  else
    if existing_char == nil or existing_char == doubleblock.icon.empty then return end
    core.set_double_char(row, col, doubleblock.icon.empty)
  end
end

function doubleblock.add_point(x, y) doubleblock.set_point(x, y, true) end

function doubleblock.remove_point(x, y) doubleblock.set_point(x, y, false) end

-- ----------------------------------------------------------------------------

local halfblock = {}

halfblock.icon = {
  empty = ' ',
  upper_half = '▀',
  lower_half = '▄',
  full = '█',
}

function halfblock.set_point(x, y, active)
  active = active == nil and true or active == true

  if helper.is_out_of_bounds(x, y) then return end
  local row = math.floor(y / canvas.factor.height)
  local col = x

  local is_upper_half = (y % canvas.factor.height) == 0
  local is_lower_half = not is_upper_half

  local existing_char = core.get_char(row, col)
  if existing_char == nil then return end

  local char = nil
  if active == true then
    if existing_char == halfblock.icon.empty then
      char = is_upper_half and halfblock.icon.upper_half or halfblock.icon.lower_half
    elseif existing_char == halfblock.icon.upper_half and is_lower_half then
      char = halfblock.icon.full
    elseif existing_char == halfblock.icon.lower_half and is_upper_half then
      char = halfblock.icon.full
    end
  else
    if existing_char == halfblock.icon.full then
      char = is_upper_half and halfblock.icon.lower_half or halfblock.icon.upper_half
    elseif existing_char == halfblock.icon.upper_half and is_upper_half then
      char = halfblock.icon.empty
    elseif existing_char == halfblock.icon.lower_half and is_lower_half then
      char = halfblock.icon.empty
    end
  end
  if char == nil then return end

  core.set_char(row, col, char)
end

function halfblock.add_point(x, y) halfblock.set_point(x, y, true) end

function halfblock.remove_point(x, y) halfblock.set_point(x, y, false) end

-- ----------------------------------------------------------------------------

function M.init(type)
  type = type or 'singleblock'

  if types[type] == nil then error('Unknown gfx canvas type: ' .. tostring(type)) end
  canvas.type = type

  canvas.factor.width = types[canvas.type].factor.width
  canvas.factor.height = types[canvas.type].factor.height

  local win_size = window.size()
  canvas.size.width = math.floor(win_size.width * canvas.factor.width)
  canvas.size.height = math.floor(win_size.height * canvas.factor.height)
  canvas.real_size.width = math.floor(canvas.size.width / canvas.factor.width)
  canvas.real_size.height = math.floor(canvas.size.height / canvas.factor.height)

  M.clear()
end

function M.clear()
  local lines = {}
  local line = string.rep(' ', canvas.real_size.width)
  for _ = 1, canvas.real_size.height do
    table.insert(lines, line)
  end
  vim.bo[window.buf].modifiable = true
  vim.api.nvim_buf_set_lines(window.buf, 0, -1, false, lines)
  vim.bo[window.buf].modifiable = false
end

function M.draw_point(x, y)
  if helper.is_out_of_bounds(x, y) then return end
  if canvas.type == 'singleblock' then
    singleblock.add_point(x, y)
  elseif canvas.type == 'halfblock' then
    halfblock.add_point(x, y)
  elseif canvas.type == 'doubleblock' then
    doubleblock.add_point(x, y)
  end
end

function M.remove_point(x, y)
  if helper.is_out_of_bounds(x, y) then return end
  if canvas.type == 'singleblock' then
    singleblock.remove_point(x, y)
  elseif canvas.type == 'halfblock' then
    halfblock.remove_point(x, y)
  elseif canvas.type == 'doubleblock' then
    doubleblock.remove_point(x, y)
  end
end

function M.draw_text(text, x, y, align)
  if helper.is_empty(text) then return end

  align = align or 'left'
  if align == 'center' then
    local text_length = vim.str_utfindex(text, 'utf-32')
    x = x - math.floor(text_length / 2)
  elseif align == 'right' then
    local text_length = vim.str_utfindex(text, 'utf-32')
    x = x - text_length + 1
  end

  local row, col = y, x
  if canvas.type == 'halfblock' then
    row = math.floor(y / canvas.factor.height)
  elseif canvas.type == 'doubleblock' then
    col = math.floor(x / canvas.factor.width)
  end

  core.set_text(row, col, text)
end

function M.center_text_in_line(text, y)
  if helper.is_empty(text) then return end
  local row = y
  local text_length = vim.str_utfindex(text, 'utf-32')
  local col = math.floor((canvas.real_size.width - text_length) / 2)
  core.set_text(row, col, text)
end

function M.center_text_in_canvas(texts)
  if texts == nil or #texts == 0 then return end
  local total_lines = #texts
  local start_y = math.floor((canvas.real_size.height - total_lines) / 2)
  for i, line in ipairs(texts) do
    M.center_text_in_line(line, start_y + i - 1)
  end
end

---Returns true if the positions are the same, false otherwise.
---@param x1 integer The x-coordinate of the first position.
---@param y1 integer The y-coordinate of the first position.
---@param x2 integer The x-coordinate of the second position.
---@param y2 integer The y-coordinate of the second position.
---@param check_full_block? boolean Whether to check for full block match in halfblock mode.
---@return boolean
function M.is_same_pos(x1, y1, x2, y2, check_full_block)
  -- Allows checking for full block match in halfblock mode.
  if check_full_block == true and canvas.type == 'halfblock' then
    check_full_block = true
  else
    check_full_block = false
  end

  -- When checking for full block, compare both halves.
  if check_full_block then
    local x2b = x2
    local y2b = y2 % 2 == 0 and y2 + 1 or y2 - 1
    return x1 == x2 and y1 == y2 or x1 == x2b and y1 == y2b
  end

  -- Normal comparison.
  return x1 == x2 and y1 == y2
end

---Returns a list of block positions for the given (x, y) coordinate.
---In halfblock mode, returns both upper and lower half positions.
---In doubleblock mode, returns both left and right block positions.
---@param x integer The x-coordinate.
---@param y integer The y-coordinate.
---@return { x: integer, y: integer }[]
function M.block_positions(x, y)
  if canvas.type == 'halfblock' then
    local y2 = y % 2 == 0 and y + 1 or y - 1
    return { { x = x, y = y }, { x = x, y = y2 } }
  elseif canvas.type == 'doubleblock' then
    local x2 = x % 2 == 0 and x + 1 or x - 1
    return { { x = x, y = y }, { x = x2, y = y } }
  else
    return { { x = x, y = y } }
  end
end

---Returns the base block position for the given (x, y) coordinate.
---In halfblock mode, returns the position of the lower half.
---In doubleblock mode, returns the position of the left block.
---@param x integer The x-coordinate.
---@param y integer The y-coordinate.
---@return { x: integer, y: integer }
function M.block_base_position(x, y)
  if canvas.type == 'halfblock' then
    y = y % 2 == 0 and y + 1 or y
  elseif canvas.type == 'doubleblock' then
    x = x % 2 == 0 and x or x - 1
  end
  return { x = x, y = y }
end

function M.cursor_position()
  local cursor = core.get_cursor()
  local x, y = cursor.col - 1, cursor.row - 1 -- Shifts from 1-based to 0-based.
  if canvas.type == 'halfblock' then
    y = y * canvas.factor.height
  elseif canvas.type == 'doubleblock' then
    x = x * canvas.factor.width
  end
  return { x = x, y = y }
end

---Refreshes the canvas display.
function M.refresh() window.redraw_buffer() end

return M
