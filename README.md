# games.nvim

A Neovim plugin for playing little games directly within Neovim.

![image](https://github.com/user-attachments/assets/a65616b9-e79d-4450-b6b2-d9a7c3deb0c8)

> [!WARNING]
> This plugin is still in early development. Work in progress. 🚀

## Features

- Games:
  - **Mines** - Find the Mines
  - **Snake** - The Hungry Snake
- Demos:
  - **Life** - Game of Life
  - **Snow** - Falling Snowflakes

## Installation

Use your favorite package manager to install `tigion/games.nvim`.

## Usage

Call the following command to select a game or a demo:

```lua
require('games').select()
```

## Configuration

The default options:

```lua
{
  window = {
    width = 0.8, -- 0..1 relative (%) and 2..inf absolute (columns)
    height = 0.8, -- 0..1 relative (%) and 2..inf absolute (lines)
    min = { width = 30, height = 15 },
    max = { width = 60, height = 30 },
    border = nil,
    ignore_34_aspect_ratio = false,
  },
}
```

Example configuration for max window size, but may cause
slowdowns on large screens:

```lua
{
  window = {
    width = 1,
    height = 1,
    max = { width = 0, height = 0 },
    border = 'rounded',
    ignore_34_aspect_ratio = true,
  },
},
```
