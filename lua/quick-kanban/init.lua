local qkb = require('quick-kanban.quick-kanban')

--- Public interface
local M = {}

--- Setup function should be called once before using any other functions in the plugin.
--- @param options? table Options to configure the plugin [optional]
M.setup = function(options)
    local config = require('quick-kanban.config')
    config.setup(options)
    qkb.setup(config.options)
end

--- Open the kanban board UI
M.open_ui = function()
    qkb.open_ui()
end

--- Close the kanban board UI
M.close_ui = function()
    qkb.close_ui()
end

--- Toggle the kanban board UI open/close
M.toggle_ui = function()
    if qkb.state.is_open then
        M.close_ui()
    else
        M.open_ui()
    end
end

--- Switch focus to the next category
M.next_category = function()
    qkb.next_category()
end

--- Switch focus to the previous category
M.prev_category = function()
    qkb.prev_category()
end

--- Switch focus to the next item in the current category
M.next_item = function()
    qkb.next_item()
end

--- Switch focus to the previous item in the current category
M.prev_item = function()
    qkb.prev_item()
end

--- Add a new item to the current category
M.add_item = function()
    qkb.add_item()
end

--- Archive the selected item
M.archive_item = function()
    qkb.archive_selected_item()
end

--- Rename an item
M.rename_item = function()
    qkb.rename_item()
end

--- Delete selected item
M.delete_item = function()
    qkb.delete_item()
end

-- Activate the selected item
M.select_item = function()
    qkb.toggle_selected_item()
end

--- Open the selected item
M.open_selected_item = function()
    qkb.open_selected_item()
end

--- Toggle the visibility of the archive category
M.toggle_archive = function()
    qkb.toggle_archive()
end

--- Display the help message
M.show_help = function()
    qkb.show_help()
end

return M
