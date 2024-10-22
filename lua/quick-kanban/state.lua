--- @class quick-kanban.state
local M = {
    --- Options for the Kanban UI
    --- @type quick-kanban.config.options
    opts = {},

    --- This variable is `true` if Kanban UI is open
    --- @type boolean
    is_open = false,

    --- The name of the currently active category.
    --- @type string? The category name
    selected_category = nil,

    --- The id of the currently selected item
    --- @type number?
    selected_item_id = nil,

    --- The id of the item currently being previewed
    --- @type number?
    preview_item_id = nil,

    --- Window information for each Kanban category
    --- @type table where the key is the name of the category from metadata.json.categories
    --- The value is a table with the following keys:
    --- - `id` (number): The window id
    --- - `bufnr` (number): The buffer number
    --- - `selected_line` (number): The selected line in the buffer
    windows = {},

    --- The logger object
    --- @type table
    log = {}
}

--- Initialize the state module
--- @param opts quick-kanban.config.options The options for the Kanban UI
--- @param log table The logger object
M.init = function(opts, log)
    M.opts = opts
    M.log = log
end

--- Get the window table for the given category
--- @param category string The name of the category
--- @return table? The window table for the category (or `nil` if the category does not exist)
M.get_window = function(category)
    if category == nil then
        M.log.error("Invalid category: " .. category)
        return nil
    end
    return M.windows[category]
end

--- Get the currently active window id
--- @return number? wid The current window id (or `nil` if Kanban window is not active)
M.get_current_wid = function()
    local wid = vim.api.nvim_get_current_win()
    for _, win in pairs(M.windows) do
        if win.id == wid then
            return wid
        end
    end
    return nil
end

--- Get the ID of the item currenlty under the cursor
--- @return number? item_id The ID of the item under the cursor (or `nil` if not found)
M.get_current_item_id = function()
    local line_num = vim.fn.line('.', M.get_current_wid())
    local item_id = string.match(vim.fn.getline(line_num), "%[(.*)%]")
    return item_id ~= nil and tonumber(item_id) or nil
end

--- Get window id for the given category
--- @param category string The name of the category
--- @return integer? wid Window id for the given category, or nil if the category does not exist
M.get_wid_for_category = function(category)
    if M.windows[category] == nil or M.windows[category].id == nil then
        return nil
    end
    return vim.api.nvim_win_is_valid(M.windows[category].id) and M.windows[category].id or nil
end

--- Set the window id for the given category
--- @param category string The name of the category
--- @param wid integer? The window id
M.set_wid_for_category = function(category, wid)
    if M.windows[category] == nil then
        M.log.error("No window for category " .. category)
        M.windows[category] = {}
    end
    M.windows[category].id = wid
end

--- Set the buffer number for the given category
--- @param category string The name of the category
--- @param bufnr integer? The buffer number
M.set_buf_for_category = function(category, bufnr)
    if M.windows[category] == nil then
        M.log.error("No window for category " .. category)
        M.windows[category] = {}
    end
    M.windows[category].bufnr = bufnr
end

--- Get buffer number for the given category
--- @param category string The name of the category
--- @return integer? The buffer number for the given category
M.get_buf_for_category = function(category)
    return M.windows[category] and M.windows[category].bufnr or nil
end

--- Get the selected category (or assign the first category if none is selected)
--- @return string The selected category
M.get_selected_category = function()
    if M.selected_category == nil then
        for category, _ in pairs(M.windows) do
            M.selected_category = category
        end
    end
    return M.selected_category
end

--- Get selected line for the given category
--- @param category string The name of the category
--- @return integer Selected line for the given category or 1 if not found
M.get_selected_line_for_category = function(category)
    return M.windows[category] and M.windows[category].selected_line or 1
end

--- Set selected line for the given category
--- @param category string The name of the category
--- @param line integer The selected line
M.set_selected_line_for_category = function(category, line)
    if M.windows[category] == nil then
        M.log.error("No window for category " .. category)
        M.windows[category] = {}
    end
    M.windows[category].selected_line = line
end

--- Check if an item is selected
--- @return boolean `true` if an item is selected, `false` otherwise
M.is_item_selected = function()
    return M.selected_item_id ~= nil
end

--- Check that all windows are valid if the Kanban UI is open
--- @return boolean `true` if all windows are valid, `false` otherwise
M.check_windows_validity = function()
    if M.is_open then
        for _, win in pairs(M.windows) do
            if win == nil or not vim.api.nvim_win_is_valid(win.id or -1) then
                return false
            end
        end
    end
    return true
end

--- Handle category renaming
--- @param old_name string The old name of the category
--- @param new_name string The new name of the category
M.handle_category_rename = function(old_name, new_name)
    if M.selected_category == old_name then
        M.selected_category = new_name
    end
    M.windows[new_name] = M.windows[old_name]
    M.windows[old_name] = nil
end

--- Handle category deletion
--- @param category string The name of the category
M.handle_category_deletion = function(category)
    if M.selected_category == category then
        M.selected_category = nil
    end
    M.windows[category] = nil
end

--- Close the window for the given category
--- @param category string The name of the category
M.close_window = function(category)
    local win = M.get_window(category)
    if win == nil then
        M.log.error("No window for category " .. category)
        return
    end

    if vim.api.nvim_win_is_valid(win.id) then
        vim.api.nvim_win_close(win.id, true)
    end

    if vim.api.nvim_buf_is_valid(win.bufnr or -1) then
        vim.api.nvim_buf_delete(win.bufnr, { force = true })
    end

    M.windows[category] = nil
end

return M
