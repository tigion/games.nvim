---@class games.snake.snake
local M = {}

---@alias games.snake.SnakeDirection 'up' | 'down' | 'left' | 'right'

---@alias games.snake.SnakePosition { x: integer, y: integer }
---@alias games.snake.SnakeSegment games.snake.SnakePosition
---@alias games.snake.SnakeSegments games.snake.SnakeSegment[]

---@class games.snake.SnakeOld
---@field head? games.snake.SnakeSegment
---@field tail? games.snake.SnakeSegment
---@field lost games.snake.SnakeSegment[]

---The possible directions the snake can move.
---@type games.snake.SnakeDirection[]
M.directions = { 'up', 'down', 'left', 'right' }

---The segments of the snake.
---@type games.snake.SnakeSegments
M.segments = {}

---Current direction of the snake.
---@type games.snake.SnakeDirection
M.direction = 'right'

---The old tail segment and the lost segments.
---@type games.snake.SnakeOld
local old = {
  tail = nil,
  lost = {},
}

---Initializes the snake.
---@param x integer Initial x-coordinate of the snake's head.
---@param y integer Initial y-coordinate of the snake's head.
---@param dir games.snake.SnakeDirection Initial direction of the snake.
---@param len? integer Initial length of the snake.
function M.init(x, y, dir, len)
  len = len or 3
  M.segments = {}
  local segment = { x = x, y = y }
  for _ = 1, len do
    table.insert(M.segments, segment)
  end
  M.direction = dir
end

---Returns the length of the snake.
---@return integer
function M.length() return #M.segments end

---Returns the first segment of the snake as the head.
---@return games.snake.SnakeSegment
function M.head() return M.segments[1] end

---Returns the last segment of the snake as the tail.
---@return games.snake.SnakeSegment
function M.tail() return M.segments[#M.segments] end

---Returns the saved old tail segment's position.
---@return games.snake.SnakeSegment?
function M.old_tail() return old.tail end

---Returns the list of lost segments when the snake was shrunk.
---@return games.snake.SnakeSegments
function M.lost_segments() return old.lost end

---Checks if all segments of the snake are visible.
---@return boolean
function M.is_fully_visible()
  if #M.segments < 2 then return false end
  local s1 = M.tail()
  local s2 = M.segments[#M.segments - 1]
  if s1.x == s2.x and s1.y == s2.y then return false end
  return true
end

---Moves the snake in the current direction.
function M.move()
  -- Saves the current tail position if there is no further segment at the same last position.
  if M.is_fully_visible() then
    local segment = M.tail()
    old.tail = { x = segment.x, y = segment.y }
  else
    old.tail = nil
  end

  -- Calculates the new head position.
  local new = { x = M.head().x, y = M.head().y }
  if M.direction == 'right' then
    new.x = new.x + 1
  elseif M.direction == 'left' then
    new.x = new.x - 1
  elseif M.direction == 'up' then
    new.y = new.y - 1
  elseif M.direction == 'down' then
    new.y = new.y + 1
  end

  -- Inserts the new head at the front of the segments list
  -- and removes the last segment to simulate movement.
  table.insert(M.segments, 1, { x = new.x, y = new.y })
  if #M.segments > 1 then local s = table.remove(M.segments) end
end

---Grows or shrinks the snake by a specified number of segments.
---Returns false if the snake cannot be shrunk further.
---@param count integer
---@return boolean
function M.grow(count)
  count = count or 1
  old.lost = {} -- Resets the lost segments list.

  if count > 0 then
    -- Grows the snake by adding segments at the tail.
    for _ = 1, count do
      local tail = M.tail()
      local new = { x = tail.x, y = tail.y }
      table.insert(M.segments, new)
    end
  elseif count < 0 then
    -- Shrinks the snake by removing segments from the tail.
    for _ = 1, (0 - count) do
      if #M.segments < 2 then return false end
      table.insert(old.lost, table.remove(M.segments))
    end
  end

  return true
end

return M
