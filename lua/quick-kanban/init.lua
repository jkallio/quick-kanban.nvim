--- @class quick-kanban
local M = {}

--- @type quick-kanban.quick-kanban?
local qk = nil

--- Instance of the user provided options
--- @type table
local options = {}

--- Instance of the Plenary log module.
--- @type table
local log = {
    --- Log a debug message
    debug = function(...) end,
    --- Log an info message
    info = function(...) end,
    --- Log a warning message
    warn = function(...) end,
    --- Log an error message
    error = function(...) end,
}

---Setup function can be used to override the default options
--- @param opts table User provided options
M.setup = function(opts)
    options = opts or {}
end

--- Init function can be called explicitly to preload the plugin the plugin and
--- avoid any delay when opening the UI. However, it is not necessary to call
--- this function explicitly if you want to load the plugin lazily.
M.init = function()
    local config = require('quick-kanban.config')
    config.init(options)

    if config.options.log_level then
        log = require('plenary.log').new({
            plugin = 'quick-kanban',
            level = config.options.log_level,
        })
    end

    qk = require('quick-kanban.quick-kanban')
    qk.init(config.options, log)
    log.debug("Options: " .. vim.inspect(config.options))
    log.debug('quick-kanban plugin loaded')
end

--- Open the kanban board UI
M.open_ui = function()
    if not qk then
        M.init()
    end

    if qk then
        qk.open_ui()
    end
end

--- Close the kanban board UI
M.close_ui = function()
    if qk then
        qk.close_ui()
    end
end

--- Toggle the kanban board UI open/close
M.toggle_ui = function()
    if not qk then
        M.init()
    end
    if qk and qk.state.is_open then
        M.close_ui()
    else
        M.open_ui()
    end
end

--- Switch focus to the next category
M.next_category = function()
    if qk then
        qk.next_category()
    end
end

--- Switch focus to the previous category
M.prev_category = function()
    if qk then
        qk.prev_category()
    end
end

--- Switch focus to the next item in the current category
M.next_item = function()
    if qk then
        qk.next_item()
    end
end

--- Switch focus to the previous item in the current category
M.prev_item = function()
    if qk then
        qk.prev_item()
    end
end

--- Add a new item to the current category
M.add_item = function()
    if qk then
        qk.add_item()
    end
end

--- Archive the selected item
M.archive_item = function()
    if qk then
        qk.archive_selected_item()
    end
end

--- Unarchive the selected item
M.unarchive_item = function()
    if qk then
        qk.unarchive_selected_item()
    end
end

--- Rename an item
M.rename_item = function()
    if qk then
        qk.rename_item()
    end
end

--- Delete selected item
M.delete_item = function()
    if qk then
        qk.delete_selected_item()
    end
end

-- Activate the selected item
M.select_item = function()
    if qk then
        qk.toggle_selected_item()
    end
end

--- Open the selected item
M.open_item = function()
    if qk then
        qk.open_selected_item()
    end
end

--- Toggle the visibility of the archive category
M.toggle_archive_window = function()
    if qk then
        qk.toggle_archive_window()
    end
end

--- Toggle the visibility of the preview window
M.toggle_preview_window = function()
    if qk then
        qk.toggle_preview_window()
    end
end

--- Display the help message
M.show_help_text = function()
    if qk then
        qk.show_help_text()
    end
end

--- Edit the attachment of the selected item
M.edit_item = function()
    if qk then
        qk.edit_item()
    end
end

--- End the editing of the attachment of the selected item
M.end_editing = function()
    if qk then
        qk.end_editing()
    end
end

--- Add category
M.add_category = function()
    if qk then
        qk.add_category()
    end
end

--- Rename category
M.rename_category = function()
    if qk then
        qk.rename_category()
    end
end

--- Delete category
M.delete_category = function()
    if qk then
        qk.delete_category()
    end
end

-- Set the user commands
vim.api.nvim_create_user_command("QuickKanban", M.toggle_ui, { nargs = 0 })

return M
