---@class games.snake.food
local M = {}

---The different types of food.
local types = {
  normal = { icons = { 'ò', 'ó' }, grow_amount = 3 },
  big = { icons = { 'Ò', 'Ó' }, grow_amount = 5 },
  -- bad = { icons = { '+', 'x' }, grow_amount = -2 },
}

----The food items.
M.items = {}

---Adds a new food item to the food list.
---@param x integer The initial x-coordinate of the food.
---@param y integer The initial y-coordinate of the food.
function M.add(x, y)
  local n = math.random(1, 5)
  local type = n <= 4 and types.normal or types.big
  local new_food = {
    pos = { x = x, y = y },
    grow_amount = type.grow_amount,
    animation = { icons = type.icons, idx = math.random(1, #type.icons) },
  }
  local key = x .. ',' .. y
  M.items[key] = new_food
  return new_food
end

function M.get(x, y)
  local key = x .. ',' .. y
  return M.items[key]
end

---Removes a food item at the specified index.
---@param x integer The x-coordinate of the food to remove.
---@param y integer The y-coordinate of the food to remove.
function M.remove(x, y)
  local key = x .. ',' .. y
  M.items[key] = nil
end

---Returns the number of food items.
function M.count() return vim.tbl_count(M.items) end

---Clears all food items.
function M.clear() M.items = {} end

---Animates all food items by moving to the next icon in their animation.
function M.animate()
  for _, item in pairs(M.items) do
    item.animation.idx = item.animation.idx + 1
    if item.animation.idx > #item.animation.icons then item.animation.idx = 1 end
  end
end

return M
