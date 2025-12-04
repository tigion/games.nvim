---A simple matrix class for managing a 2D grid of integers.
---
---- y is the row index (1-based)
---- x is the column index (1-based)
---- `values[y][x]` holds the integer value at position (y, x)
---@class games.Matrix
---@field width integer
---@field height integer
---@field values integer[][]
local Matrix = {}
Matrix.__index = Matrix

---Shifts 0-based positions to 1-based.
---@param y integer
---@param x integer
---@return integer, integer
local function shift_0_to_1based(y, x) return y + 1, x + 1 end

---Shifts 1-based positions to 0-based.
---@param y integer
---@param x integer
---@return integer, integer
local function shift_1_to_0based(y, x) return y - 1, x - 1 end

---Initializes the matrix with given width and height, filled with zeros.
---@param height integer
---@param width integer
---@return integer[][]
local function init(height, width)
  local values = {}
  for y = 1, height do
    values[y] = {}
    for x = 1, width do
      values[y][x] = 0
    end
  end
  return values
end

---Creates a new Matrix instance.
---@param height integer
---@param width integer
---@return games.Matrix
function Matrix:new(height, width)
  local obj = {
    height = height,
    width = width,
    values = init(height, width),
  }
  setmetatable(obj, self)
  return obj
end

---Clears the matrix by setting all values to zero.
function Matrix:clear()
  for y = 1, self.height do
    for x = 1, self.width do
      self.values[y][x] = 0
    end
  end
end

---Sets the value at the specified (y, x) position
---if the position is valid.
---@param y integer
---@param x integer
---@param value integer
function Matrix:set(y, x, value)
  y, x = shift_0_to_1based(y, x)
  if self.values[y] == nil or self.values[y][x] == nil then return end
  self.values[y][x] = value
end

---Gets the value at the specified (y, x) position
---or nil if the position is invalid.
---@param y integer
---@param x integer
---@return integer?
function Matrix:get(y, x)
  y, x = shift_0_to_1based(y, x)
  if self.values[y] == nil or self.values[y][x] == nil then return nil end
  return self.values[y][x]
end

---Finds all positions of the specified value in the matrix.
---Returns nil if no positions are found.
---@param value integer
---@param ignore_snake_halfblock boolean
---@return { y: integer, x: integer }[]
function Matrix:get_positions_of(value, ignore_snake_halfblock)
  if ignore_snake_halfblock == nil then ignore_snake_halfblock = false end
  local positions = {}
  for y = 1, self.height do
    for x = 1, self.width do
      local ignore = false
      -- In snake game with halfblock graphics,
      -- ignore the empty halfblock part of the snake.
      -- -- TODO: not correct
      if ignore_snake_halfblock then
        local y2 = y % 2 == 0 and y - 1 or y + 1
        if self.values[y2][x] == 1 then ignore = true end
      end
      -- Add position if not ignored and value matches.
      if not ignore and self.values[y][x] == value then
        local x1, y1 = shift_1_to_0based(x, y)
        table.insert(positions, { y = y1, x = x1 })
      end
    end
  end
  return positions
end

---Prints the matrix to the console.
function Matrix:print()
  for y = 1, self.height do
    print(table.concat(self.values[y]))
  end
end

return Matrix
