local qkb = require('quick-kanban.quick-kanban')
local config = require('quick-kanban.config')

--- Public interface
local M = {}

--- Setup function should be called once before using any other functions in the plugin.
--- @param options? table Options to configure the plugin [optional]
M.setup = function(options)
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

--- Unarchive the selected item
M.unarchive_item = function()
    qkb.unarchive_selected_item()
end

--- Rename an item
M.rename_item = function()
    qkb.rename_item()
end

--- Delete selected item
M.delete_item = function()
    qkb.delete_selected_item()
end

-- Activate the selected item
M.select_item = function()
    qkb.toggle_selected_item()
end

--- Open the selected item
M.open_item = function()
    qkb.open_selected_item()
end

--- Toggle the visibility of the archive category
M.toggle_archive_window = function()
    qkb.toggle_archive_window()
end

--- Toggle the visibility of the preview window
M.toggle_preview_window = function()
    qkb.toggle_preview_window()
end

--- Display the help message
M.show_help_text = function()
    qkb.show_help_text()
end

--- Edit the attachment of the selected item
M.edit_item = function()
    qkb.edit_item()
end

--- End the editing of the attachment of the selected item
M.end_editing = function()
    qkb.end_editing()
end

return M
