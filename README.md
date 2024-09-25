<div align="center">

# Quick Kanban

Create a simple Kanban board for your project quickly.

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.6+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

</div>

## Description

This plugin allows you to quickly manage your project tasks in [Neovim](https://neovim.io).

The plugin creates `.quick-kanban` hidden folder inside your current project directory. All the meta data and task files are stored in the folder as text/markdown files.

## Features

- [x] Simple and intuitive user interface.
- [x] File based task managing.
- [x] Customizable Kanban boards.
- [x] Customizable keybindings.
- [x] Item archiving (for helping to keep the kanban boards clean).
- [x] Item editing directly in the Kanban UI
- [ ] Multi-selecting items.
- [ ] Use single global path for storing all the kanban boards.
- [ ] Integrate with Obsidian Kanban format

## Folder structure

Task items are stored as text files where each task contains a meta file along with (optional) attachment markdown file.

```
Project Root/
└── .quick-kanban/
    ├── .items/
    │   ├── 4
    │   ├── 5
    │   └── 6
    ├── .archive/
    │   ├── 1
    │   ├── 2
    │   └── 3
    ├── .attachments/
    │   ├── 1.md
    │   ├── 2.md
    │   ├── 3.md
    │   ├── 4.md
    │   ├── 5.md
    │   └── 6.md
    └── .metadata.json
```

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug)
```vim
Plug 'nvim-lua/plenary.nvim' " Required dependency
Plug 'jkallio/quick-kanban.nvim'
```

Using [packer](https://github.com/wbthomason/packer.nvim)
```lua
use {
  'jkallio/quick-kanban.nvim',
  requires = { {'nvim-lua/plenary.nvim'} }
}
```

Using [lazy](https://github.com/folke/lazy.nvim)
```lua
return {
    {
    'jkallio/quick-kanban.nvim',
      dependencies = { 'nvim-lua/plenary.nvim' }
    }
}
```

## Usage

Just open the Kanban plugin UI, and it prompts you if you want to create the `.quick-kanban` directories inside the current working directory.

```lua
local qk = require('quick-kanban')
qk.setup(opts) -- Setup the plugin with optional arguments
qk.open_ui() -- Open the popup UI
qk.close_ui() -- Close the popup UI
qk.toggle_ui() -- Toggle the popup UI (open/close)
```

## Configuration

Using [lazy](https://github.com/folke/lazy.nvim):
```lua
return {
  'jkallio/quick-.nvim',
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    local qk = require('quick-kanban')
    qk.setup({
      --- A list of categories for the kanban board.
      categories = {
        'Backlog',
        'In Progress',
        'Done',
      },

      --- Default category for the new items.
      default_category = "Backlog",

      --- Show line numbers
      number = false,

      --- Wrap lines
      wrap = true,

      --- Show the preview window
      show_preview = true,

      --- Show the archive window
      show_archive = false,

      --- Override the default keymaps for the kanban UI.
      keymaps = {
        show_help = { keys = '?', desc = "Show help" },
        next_category = { keys = 'l', desc = "Next category" },
        prev_category = { keys = 'h', desc = "Prev category" },
        next_item = { keys = 'j', desc = "Next item" },
        prev_item = { keys = 'k', desc = "Prev item" },
        add_item = { keys = 'a', desc = "Add new item" },
        edit_item = { keys = 'e', desc = "Edit attachment" },
        end_editing = { keys = '<esc><esc>', desc = "End editing" },
        archive_item = { keys = 'd', desc = "Archvie item" },
        unarchive_item = { keys = 'u', desc = "Unarchive item" },
        delete = { keys = 'D', desc = "Delete item" },
        open_item = { keys = '<leader>o', desc = "Open item" },
        rename = { keys = { 'r', 'c' }, desc = "Rename item title" },
        select_item = { keys = '<cr>', desc = "Select item" },
        toggle_archive = { keys = '<leader>a', desc = "Toggle Archive" },
        toggle_preview = { keys = '<leader>p', desc = "Toggle Preview" },
        quit = { keys = { 'q', '<esc>' }, desc = "Quit" },
      },

      --- The window configuration for the kanban UI
      window = {
        width = 40,                            -- The width of each kanban category window.
        height = 30,                           -- The height of the kanban UI
        title_decoration = { "-=[ ", " ]=-" }, -- Window title decoration (prefix and suffix)
        blend = 5,                             -- Window transparency (0-100)
        vertical_gap = 1,                      -- The gap between the kanban board windows (vertical)
        horizontal_gap = 2,                    -- The gap between the kanban board windows (horizontal)
        hide_cursor = true,                    -- Hide the cursor when the kanban board is active
        accent_color = "#44AA44",              -- The accent color for the UI
        hilight_color = "#FFFF44",             -- The highlight color for the UI
        active_text_bg = "#448844",            -- Background color of the item under cursor.
        active_text_fg = "#000000",            -- Text color of the the item under cursor.
        selected_text_bg = "#888844",          -- Background color of the selected/activated item.
        selected_text_fg = "#000000",          -- Text color of the selected/activated item.
      },
    })

    vim.keymap.set('n', '<leader>K', function() qk.toggle_ui() end, { desc = 'Quick-kanban: Toggle Kanban UI' })
  end
}
```

## Screenshots

![Screenshot](./screenshots/quick-kanban.gif)
![Screenshot](./screenshots/quick-kanban1.png)
![Screenshot](./screenshots/quick-kanban2.png)
