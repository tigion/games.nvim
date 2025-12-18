-- Graphics module for a grid based canvas in a Neovim window.
--
-- Uses block characters to represent pixels.
-- Supports single, half, quarter, sixth and double block rendering.

local window = require('games.window')

---@class games.gfx
local M = {}

local canvas = {
  type = nil,
  size = { width = 0, height = 0 },
  real_size = { width = 0, height = 0 },
  cache = {},
}

local function is_out_of_bounds(x, y) return x < 0 or x > canvas.size.width - 1 or y < 0 or y > canvas.size.height - 1 end

local function y_to_row(y) return math.floor(y / canvas.type.factor.height) end

local function x_to_col(x) return math.floor(x / canvas.type.factor.width) end

-- ----------------------------------------------------------------------------

M.canvas = {}

function M.canvas.size()
  local width = canvas.size.width
  local height = canvas.size.height
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

function core.get_double_char(row, col)
  local line = vim.api.nvim_buf_get_lines(window.buf, row, row + 1, false)[1] or ''
  local start_byte_offset = vim.str_byteindex(line, 'utf-32', col)
  local end_byte_offset = vim.str_byteindex(line, 'utf-32', col + 2)
  return vim.api.nvim_buf_get_text(window.buf, row, start_byte_offset, row, end_byte_offset, {})[1] or nil
end

function core.set_double_char(row, col, char)
  local char_length = vim.str_utfindex(char, 'utf-32')
  if char_length > 2 then char = char:sub(1, vim.str_utfindex(char, 'utf-32', 2)) end
  core.set_text(row, col, char)
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

function helper.is_empty(text) return text == nil or text == '' end

function helper.find_table_index(table, value)
  for i, v in ipairs(table) do
    if v == value then return i end
  end
  return nil
end

-- ----------------------------------------------------------------------------

local singleblock = {
  name = 'singleblock',
  factor = { width = 1.0, height = 1.0 },
  icons = { ' ', '█' }, -- 0-1
  -- gradient = {'░', '▒', '▓'},
}

function singleblock.set_point(x, y, active)
  active = active == nil and true or active == true

  if is_out_of_bounds(x, y) then return end
  local row, col = y, x

  local existing_char = core.get_char(row, col)
  if existing_char == nil then return end

  local icon_idx = helper.find_table_index(singleblock.icons, existing_char)
  if icon_idx == nil then return end

  local new_idx = active and 2 or 1
  if new_idx == icon_idx or new_idx == nil or new_idx < 1 or new_idx > #singleblock.icons then return end

  local char = singleblock.icons[new_idx]
  core.set_char(row, col, char)
end

function singleblock.add_point(x, y) singleblock.set_point(x, y, true) end

function singleblock.remove_point(x, y) singleblock.set_point(x, y, false) end

function singleblock.base_position(x, y) return { x = x, y = y } end

function singleblock.block_positions(x, y) return { { x = x, y = y } } end

function singleblock.adjust_cursor_position(x, y) return { x = x, y = y } end

-- ----------------------------------------------------------------------------

local halfblock = {
  name = 'halfblock',
  factor = { width = 1.0, height = 2.0 },
  icons = { ' ', '▀', '▄', '█' }, -- 0-3
}

-- 1 - 01: '▀' <-- upper half
-- 2 - 10: '▄' <-- lower half

function halfblock.set_point(x, y, active)
  active = active == nil and true or active == true

  if is_out_of_bounds(x, y) then return end
  local row = y_to_row(y)
  local col = x

  local existing_char = core.get_char(row, col)
  if existing_char == nil then return end

  local icon_idx = helper.find_table_index(halfblock.icons, existing_char)
  if icon_idx == nil then return end

  local is_upper_half = (y % halfblock.factor.height) == 0
  local is_lower_half = not is_upper_half

  local bitmask = 0
  if is_upper_half then bitmask = 1 end
  if is_lower_half then bitmask = 2 end
  if bitmask == 0 then return end

  local new_idx = nil
  icon_idx = icon_idx - 1 -- Shift to 0-based index.
  if active == true then
    new_idx = bit.bor(icon_idx, bitmask)
  else
    new_idx = bit.band(icon_idx, bit.bnot(bitmask))
  end
  if new_idx == icon_idx or new_idx == nil or new_idx < 0 or new_idx > #halfblock.icons - 1 then return end
  new_idx = new_idx + 1 -- Shift to 1-based index.
  local char = halfblock.icons[new_idx]

  core.set_char(row, col, char)
end

function halfblock.add_point(x, y) halfblock.set_point(x, y, true) end

function halfblock.remove_point(x, y) halfblock.set_point(x, y, false) end

function halfblock.base_position(x, y)
  -- local base_y = y % 2 == 0 and y + 1 or y
  local base_y = y - (y % 2)
  return { x = x, y = base_y }
end

function halfblock.block_positions(x, y)
  local base = halfblock.base_position(x, y)
  return {
    { x = base.x, y = base.y },
    { x = base.x, y = base.y + 1 },
  }
end

function halfblock.adjust_cursor_position(x, y)
  y = y * halfblock.factor.height
  return { x = x, y = y }
end

-- ----------------------------------------------------------------------------

local quarterblock = {
  name = 'quarterblock',
  factor = { width = 2.0, height = 2.0 },
  -- stylua: ignore start
  icons = {
    ' ', '▘', '▝', '▀', '▖', '▌', '▞', '▛', -- 0-7
    '▗', '▚', '▐', '▜', '▄', '▙', '▟', '█', -- 8-15
  },
  -- stylua: ignore end
}

--  1 - 0001: '▘' <-- upper left
--  2 - 0010: '▝' <-- upper right
--  4 - 0100: '▖' <-- lower left
--  8 - 1000: '▗' <-- lower right

function quarterblock.set_point(x, y, active)
  active = active == nil and true or active == true

  if is_out_of_bounds(x, y) then return end
  local row = y_to_row(y)
  local col = x_to_col(x)

  local existing_char = core.get_char(row, col)
  if existing_char == nil then return end

  local icon_idx = helper.find_table_index(quarterblock.icons, existing_char)
  if icon_idx == nil then return end

  local is_upper_left = (x % quarterblock.factor.width) == 0 and (y % quarterblock.factor.height) == 0
  local is_upper_right = (x % quarterblock.factor.width) ~= 0 and (y % quarterblock.factor.height) == 0
  local is_lower_left = (x % quarterblock.factor.width) == 0 and (y % quarterblock.factor.height) ~= 0
  local is_lower_right = (x % quarterblock.factor.width) ~= 0 and (y % quarterblock.factor.height) ~= 0

  local bitmask = 0
  if is_upper_left then bitmask = 1 end
  if is_upper_right then bitmask = 2 end
  if is_lower_left then bitmask = 4 end
  if is_lower_right then bitmask = 8 end
  if bitmask == 0 then return end

  local new_idx = nil
  icon_idx = icon_idx - 1 -- Shift to 0-based index.
  if active == true then
    new_idx = bit.bor(icon_idx, bitmask)
  else
    new_idx = bit.band(icon_idx, bit.bnot(bitmask))
  end
  if new_idx == icon_idx or new_idx == nil or new_idx < 0 or new_idx > #quarterblock.icons - 1 then return end
  new_idx = new_idx + 1 -- Shift to 1-based index.
  local char = quarterblock.icons[new_idx]

  core.set_char(row, col, char)
end

function quarterblock.add_point(x, y) quarterblock.set_point(x, y, true) end

function quarterblock.remove_point(x, y) quarterblock.set_point(x, y, false) end

function quarterblock.base_position(x, y)
  local base_x = x - (x % 2)
  local base_y = y - (y % 2)
  return { x = base_x, y = base_y }
end

function quarterblock.block_positions(x, y)
  local base = quarterblock.base_position(x, y)
  return {
    { x = base.x, y = base.y },
    { x = base.x + 1, y = base.y },
    { x = base.x, y = base.y + 1 },
    { x = base.x + 1, y = base.y + 1 },
  }
end

function quarterblock.adjust_cursor_position(x, y)
  x = x * quarterblock.factor.width
  y = y * quarterblock.factor.height
  return { x = x, y = y }
end

-- ----------------------------------------------------------------------------

local sixthblock = {
  name = 'sixthblock',
  factor = { width = 2.0, height = 3.0 },
  -- stylua: ignore start
  icons = { -- Needs supported fonts.
    ' ', '🬀', '🬁', '🬂', '🬃', '🬄', '🬅', '🬆', -- 0-7
    '🬇', '🬈', '🬉', '🬊', '🬋', '🬌', '🬍', '🬎', -- 8-15
    '🬏', '🬐', '🬑', '🬒', '🬓', '▌', '🬔', '🬕', -- 16-23
    '🬖', '🬗', '🬘', '🬙', '🬚', '🬛', '🬜', '🬝', -- 24-31
    '🬞', '🬟', '🬠', '🬡', '🬢', '🬣', '🬤', '🬥', -- 32-39
    '🬦', '🬧', '▐', '🬨', '🬩', '🬪', '🬫', '🬬', -- 40-47
    '🬭', '🬮', '🬯', '🬰', '🬱', '🬲', '🬳', '🬴', -- 48-55
    '🬵', '🬶', '🬷', '🬸', '🬹', '🬺', '🬻', '█', -- 56-63
  },
  -- stylua: ignore end
}

--  1 - 000001: '🬀' <-- upper left
--  2 - 000010: '🬁' <-- upper rught
--  4 - 000100: '🬃' <-- middle left
--  8 - 001000: '🬇' <-- middle right
-- 16 - 010000: '🬏' <-- lower left
-- 32 - 100000: '🬞' <-- lower right

function sixthblock.set_point(x, y, active)
  active = active == nil and true or active == true

  if is_out_of_bounds(x, y) then return end
  local row = y_to_row(y)
  local col = x_to_col(x)

  local existing_char = core.get_char(row, col)
  if existing_char == nil then return end

  local icon_idx = helper.find_table_index(sixthblock.icons, existing_char)
  if icon_idx == nil then return end

  local is_upper_left = (x % sixthblock.factor.width) == 0 and (y % sixthblock.factor.height) == 0
  local is_upper_right = (x % sixthblock.factor.width) ~= 0 and (y % sixthblock.factor.height) == 0
  local is_middle_left = (x % sixthblock.factor.width) == 0 and (y % sixthblock.factor.height) == 1
  local is_middle_right = (x % sixthblock.factor.width) ~= 0 and (y % sixthblock.factor.height) == 1
  local is_lower_left = (x % sixthblock.factor.width) == 0 and (y % sixthblock.factor.height) == 2
  local is_lower_right = (x % sixthblock.factor.width) ~= 0 and (y % sixthblock.factor.height) == 2

  local bitmask = 0
  if is_upper_left then bitmask = 1 end
  if is_upper_right then bitmask = 2 end
  if is_middle_left then bitmask = 4 end
  if is_middle_right then bitmask = 8 end
  if is_lower_left then bitmask = 16 end
  if is_lower_right then bitmask = 32 end
  if bitmask == 0 then return end

  local new_idx = nil
  icon_idx = icon_idx - 1 -- Shift to 0-based index.
  if active == true then
    new_idx = bit.bor(icon_idx, bitmask)
  else
    new_idx = bit.band(icon_idx, bit.bnot(bitmask))
  end
  if new_idx == icon_idx or new_idx == nil or new_idx < 0 or new_idx > #sixthblock.icons - 1 then return end
  new_idx = new_idx + 1 -- Shift to 1-based index.
  local char = sixthblock.icons[new_idx]

  core.set_char(row, col, char)
end

function sixthblock.add_point(x, y) sixthblock.set_point(x, y, true) end

function sixthblock.remove_point(x, y) sixthblock.set_point(x, y, false) end

function sixthblock.base_position(x, y)
  local base_x = x - (x % 2)
  local base_y = y - (y % 3)
  return { x = base_x, y = base_y }
end

function sixthblock.block_positions(x, y)
  local base = sixthblock.base_position(x, y)
  return {
    { x = base.x, y = base.y },
    { x = base.x + 1, y = base.y },
    { x = base.x, y = base.y + 1 },
    { x = base.x + 1, y = base.y + 1 },
    { x = base.x, y = base.y + 2 },
    { x = base.x + 1, y = base.y + 2 },
  }
end

function sixthblock.adjust_cursor_position(x, y)
  x = x * sixthblock.factor.width
  y = y * sixthblock.factor.height
  return { x = x, y = y }
end

-- ----------------------------------------------------------------------------

local doubleblock = {
  name = 'doubleblock',
  factor = { width = 0.5, height = 1.0 },
  icons = { '  ', '██' }, -- 0-1
}

function doubleblock.set_point(x, y, active)
  active = active == nil and true or active == true

  if is_out_of_bounds(x, y) then return end
  local row = y
  local col = x_to_col(x)

  local existing_char = core.get_double_char(row, col)
  if existing_char == nil then return end

  local icon_idx = helper.find_table_index(doubleblock.icons, existing_char)
  if icon_idx == nil then return end

  local new_idx = active and 2 or 1
  if new_idx == icon_idx or new_idx == nil or new_idx < 1 or new_idx > #singleblock.icons then return end

  local char = doubleblock.icons[new_idx]
  core.set_double_char(row, col, char)
end

function doubleblock.add_point(x, y) doubleblock.set_point(x, y, true) end

function doubleblock.remove_point(x, y) doubleblock.set_point(x, y, false) end

function doubleblock.base_position(x, y)
  local base_x = x % 2 == 0 and x or x - 1
  return { x = base_x, y = y }
end

function doubleblock.block_positions(x, y)
  local base = doubleblock.base_position(x, y)
  return {
    { x = base.x, y = base.y },
    { x = base.x + 1, y = base.y },
  }
end

function doubleblock.adjust_cursor_position(x, y)
  x = math.floor(x * doubleblock.factor.width)
  return { x = x, y = y }
end

-- ----------------------------------------------------------------------------

local types = {
  singleblock = singleblock,
  halfblock = halfblock,
  quarterblock = quarterblock,
  sixthblock = sixthblock,
  doubleblock = doubleblock,
}

---Initializes the graphics canvas with the specified type.
---@param type string The canvas type: 'singleblock' (default)
function M.init(type)
  type = type or 'singleblock'

  if types[type] == nil then error('Unknown gfx canvas type: ' .. tostring(type)) end
  canvas.type = types[type]

  local win_size = window.size()
  canvas.size.width = math.floor(win_size.width * canvas.type.factor.width)
  canvas.size.height = math.floor(win_size.height * canvas.type.factor.height)
  canvas.real_size.width = math.floor(canvas.size.width / canvas.type.factor.width)
  canvas.real_size.height = math.floor(canvas.size.height / canvas.type.factor.height)

  M.clear()
end

---Clears the canvas.
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

---Draws a point at the specified (x, y) coordinate.
---@param x integer The x-coordinate.
---@param y integer The y-coordinate.
function M.draw_point(x, y)
  if is_out_of_bounds(x, y) then return end
  canvas.type.add_point(x, y)
end

---Removes a point at the specified (x, y) coordinate.
---@param x integer The x-coordinate.
---@param y integer The y-coordinate.
function M.remove_point(x, y)
  if is_out_of_bounds(x, y) then return end
  canvas.type.remove_point(x, y)
end

---Draws text at the specified (x, y) coordinate with alignment.
---@param text string The text to draw.
---@param x integer The x-coordinate.
---@param y integer The y-coordinate.
---@param align string? The alignment: 'left' (default), 'center', or 'right'.
function M.draw_text(text, x, y, align)
  align = align or 'left'
  if helper.is_empty(text) then return end

  if align == 'center' or align == 'right' then
    local text_length = vim.str_utfindex(text, 'utf-32')
    x = align == 'center' and x - math.floor(text_length / 2) or x - text_length + 1
  end

  local base = canvas.type.base_position(x, y)
  local row, col = y_to_row(base.y), x_to_col(base.x)
  core.set_text(row, col, text)
end

---Centers text in a specific line (y-coordinate) of the canvas.
---@param text string The text to center.
---@param y integer The y-coordinate of the line.
function M.center_text_in_line(text, y)
  if helper.is_empty(text) then return end
  local text_length = vim.str_utfindex(text, 'utf-32')
  local base = canvas.type.base_position(0, y)
  local row = y_to_row(base.y)
  local col = math.floor((canvas.real_size.width - text_length) / 2)
  core.set_text(row, col, text)
end

---Centers multiple lines of text in the canvas.
---@param texts string[] List of text lines to center.
function M.center_text_in_canvas(texts)
  if texts == nil or #texts == 0 then return end

  local total_lines = #texts
  local start_row = math.floor((canvas.real_size.height - total_lines) / 2)
  for i, line in ipairs(texts) do
    local text_length = vim.str_utfindex(line, 'utf-32')
    local col = math.floor((canvas.real_size.width - text_length) / 2)
    local row = start_row + i - 1
    core.set_text(row, col, line)
  end
end

---Returns true if the (x1, y1) position is in the same block position
---like (x2, y2), false otherwise.
---@param x1 integer The x-coordinate of the first position.
---@param y1 integer The y-coordinate of the first position.
---@param x2 integer The x-coordinate of the second position.
---@param y2 integer The y-coordinate of the second position.
---@return boolean
function M.is_same_block_position(x1, y1, x2, y2)
  local block_positions = halfblock.block_positions(x2, y2)
  for _, pos in ipairs(block_positions) do
    if x1 == pos.x and y1 == pos.y then return true end
  end
  return false
end

---Returns a list of block positions for the given (x, y) coordinate.
---In halfblock mode, returns both upper and lower half positions.
---In doubleblock mode, returns both left and right block positions.
---@param x integer The x-coordinate.
---@param y integer The y-coordinate.
---@return { x: integer, y: integer }[]
function M.block_positions(x, y) return canvas.type.block_positions(x, y) end

---Returns the base block position for the given (x, y) coordinate.
---Always returns the top-left position of the block.
---@param x integer The x-coordinate.
---@param y integer The y-coordinate.
---@return { x: integer, y: integer }
function M.block_base_position(x, y) return canvas.type.base_position(x, y) end

---Returns the position of the cursor relative to the canvas type.
---@return { x: integer, y: integer }
function M.cursor_position()
  local cursor = core.get_cursor()
  local x, y = cursor.col - 1, cursor.row - 1 -- Shifts from 1-based to 0-based.
  return canvas.type.adjust_cursor_position(x, y)
end

---Refreshes the canvas display.
function M.refresh() window.redraw_buffer() end

return M
