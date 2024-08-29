local utils = require('quick-kanban.utils')
local data = require('quick-kanban.data')
local WIN_HILIGHT_NAMESPACE_ACTIVE = 100
local WIN_HILIGHT_NAMESPACE_ITEM_SELECTED = 200

--- Public interface
local M = {}

--- Local state and collection of utility functions
local L = {
    -- Options for the plugin
    opts = {},

    -- Internal state of the plugin
    state = {
        is_open = false,       -- [bool] `true` if the UI is open
        win_ids = {},          -- [table] Dictionary of window IDs for each category { category = win_id, ... }
        buf_nrs = {},          -- [table] Dictionary of buffer numbers for each category { category = buf_nr, ... }
        sel_line_nums = {},    -- [table] Index of the selected line number for each category { category = index, ... }
        sel_window_key = nil,  -- [string] Category key for the selected window
        selected_item_id = nil -- [number] The ID of the selected item
    }
}

-------------------------------------------------------------------------------
--- Autocommands
-------------------------------------------------------------------------------

--- Autogroup which monitors entering Kanban window
--  This sets the hilight namespace for the active window
vim.api.nvim_create_autocmd('WinEnter', {
    group = vim.api.nvim_create_augroup('MonitorWindowEnter', { clear = true }),
    callback = function()
        local win_id = L.get_current_win_id()
        if win_id ~= nil then
            if L.state.selected_item_id ~= nil then
                vim.api.nvim_win_set_hl_ns(win_id, WIN_HILIGHT_NAMESPACE_ITEM_SELECTED)
            else
                vim.api.nvim_win_set_hl_ns(win_id, WIN_HILIGHT_NAMESPACE_ACTIVE)
            end
        elseif L.state.is_open then
            M.close_ui()
        end
    end
})

--- Autogroup which monitors leaveing Kanban window
--  This restores the default hilight namespace
vim.api.nvim_create_autocmd('WinLeave', {
    group = vim.api.nvim_create_augroup('MonitorWindowLeave', { clear = true }),
    callback = function()
        if L.state.is_open then
            local win_id = L.get_current_win_id()
            if win_id ~= nil then
                vim.api.nvim_win_set_hl_ns(win_id, 0)
            end
        end
    end
})

-------------------------------------------------------------------------------
--- Local Helper functions
-------------------------------------------------------------------------------

--- Helper function to configure keymaps for the given buffer
--- @param bufnr number The buffer number where the keymaps are to be configured
--- @param keymaps table The keymaps to configure
L.configure_buf_keymaps = function(bufnr, keymaps)
    local opts = { noremap = true, silent = true }
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.add, ':lua require("quick-kanban").add_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.delete, ':lua require("quick-kanban").delete_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.quit, ':lua require("quick-kanban").close_ui()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.next_window, ':lua require("quick-kanban").next_window()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.prev_window, ':lua require("quick-kanban").prev_window()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.next_item, ':lua require("quick-kanban").next_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.prev_item, ':lua require("quick-kanban").prev_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.select_item, ':lua require("quick-kanban").select_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.refresh, ':lua require("quick-kanban").refresh()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.commit, ':lua require("quick-kanban").commit_changes()<CR>', opts)
end

--- Helper function for creating the directory
--- @param path string path to the directory
--- @return boolean `false` if the user rejects the prompt
L.create_kanban_directory = function(path)
    if not utils.directory_exists(path) then
        if vim.fn.confirm(
                'Kanban directory does not exist for this project.\r\nCreate Kanban directory?\r\n' .. path .. '?',
                '&Yes\n&No', 2) ~= 1 then
            return false
        end
        utils.touch_directory(L.opts.path)
        utils.touch_directory(L.opts.meta_path)
    end
    return true
end

--- Helper function to reload items into given category
--- @param category string
L.reload_items_for_category = function(category)
    local items = data.get_items_for_category(category)
    if items ~= nil then
        local buf_lines = {}
        for _, item in ipairs(items) do
            table.insert(buf_lines, "[" .. item.id .. "] " .. item.title)
        end

        local bufnr = L.state.buf_nrs[category]
        vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, buf_lines)
        vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
    else
        utils.log.error("No items for category " .. category)
    end
end

--- Helper function to get the window Id for the given category key
--- @param category string The category key
--- @return number The window id for the given category
L.get_win_index_for_category = function(category)
    return L.state.win_ids[category]
end

--- Helper function to get the category for the given window index
--- @param win_index number The window index
--- @return string? The category for the given window index (or `nil` if not found)
L.get_category_for_win_index = function(win_index)
    for index, category in ipairs(L.opts.categories) do
        if index == win_index then
            return category
        end
    end
    return nil
end

--- Helper function to get the category for window id
--- @param wid number Window Id
--- @return string? The category for the given window id (or `nil` if not found)
L.get_category_for_win_id = function(wid)
    for category_key, value in pairs(L.state.win_ids) do
        if value == wid then
            return category_key
        end
    end
    return nil
end

--- Helper function to get the window index for the given window id
--- @param win_id number The window id
--- @return number? The window index for the given window id (or `nil` if not found)
L.get_win_index_for_win_id = function(win_id)
    for index, category in ipairs(L.opts.categories) do
        if L.state.win_ids[category] == win_id then
            return index
        end
    end
    return nil
end

--- Helper function to get current window id
--- @return number? The current window id (or `nil` if not found)
L.get_current_win_id = function()
    local winid = vim.api.nvim_get_current_win()
    for _, value in pairs(L.state.win_ids) do
        if value == winid then
            return winid
        end
    end
    return nil
end

--- Helper function to get the current buffer number
--- @return number? The current buffer number (or `nil` if not found)
L.get_current_bufnr = function()
    local winid = L.get_current_win_id()
    if winid ~= nil then
        return vim.api.nvim_win_get_buf(winid)
    end
    return nil
end

--- Helper function to move an item from one catogry to another
--- @param item_id number The ID of the item to move
--- @param source_category string The category to move the item from
--- @param target_category string The category to move the item to
L.move_item_to_category = function(item_id, source_category, target_category)
    local source_wid = L.state.win_ids[source_category]
    local target_wid = L.state.win_ids[target_category]
    if item_id == nil or source_wid == nil or target_wid == nil then
        utils.log.error("Invalid argument(s): "
            .. "item_id=" .. (item_id or "nil") .. "; "
            .. "source_wid=" .. (source_wid or "nil") .. "; "
            .. "target_wid=" .. (target_wid or "nil"))
        return
    end
    data.move_item_to_category(item_id, source_category, target_category)
    L.reload_items_for_category(source_category)
    L.reload_items_for_category(target_category)
end

--- Helper function to move an item from one index to another
--- @param item_id number The ID of the item to move
--- @param source_index number The index to move the item from
--- @param target_index number The index to move the item to
L.move_item_to_index = function(item_id, source_index, target_index)

end

--- Helper function to retrieve the item currenlty under the cursor
--- @return number? The ID of the item under the cursor (or `nil` if not found)
L.get_item_id_under_cursor = function()
    local win_id = L.get_current_win_id()
    if win_id == nil then
        utils.log.error("Cannot get item; Active window not found")
        return nil
    end

    local line_num = vim.fn.line('.', win_id)
    if line_num == 0 then
        utils.log.error("Cannot get item; Active line not found")
        return nil
    end

    local item_id = string.match(vim.fn.getline(line_num), "%[(.*)%]")
    if item_id == nil then
        utils.log.error("Cannot get item; Item ID not found")
        return nil
    end

    return tonumber(item_id)
end

--- Helper function to set the focus to the window at the given index
--- @param new_idx number The index of the window to focus
L.set_window_focus = function(new_idx)
    -- Ensure the index is within the bounds
    new_idx = vim.fn.max({ 1, vim.fn.min({ #L.opts.categories, new_idx }) })
    local cur_idx = L.get_win_index_for_win_id(vim.api.nvim_get_current_win())
    if cur_idx == nil or cur_idx == new_idx then
        return
    end

    local cur_category = L.get_category_for_win_index(cur_idx)
    local new_category = L.get_category_for_win_index(new_idx)
    if cur_category == nil or new_category == nil then
        utils.log.error("Invalid argument(s): "
            .. "index=" .. (new_idx or "nil") .. "; "
            .. "cur_category=" .. (cur_category or "nil") .. "; "
            .. "new_cateogory=" .. (new_category or "nil"))
        return
    end

    local win_id = L.state.win_ids[new_category]
    if win_id == nil then
        utils.log.error('Failed to get the window for index: ' .. new_idx)
        return
    end

    -- If item was selected, move it to the new category
    if L.state.selected_item_id ~= nil then
        L.move_item_to_category(L.state.selected_item_id, cur_category, new_category)
    end

    -- Set the focus to the new window
    vim.api.nvim_set_current_win(win_id)
    L.state.sel_window_key = new_category
    if L.state.sel_line_nums[new_category] == nil then
        L.state.sel_line_nums[new_category] = 1
    end

    local sel_index = L.state.sel_line_nums[win_id]
    if sel_index ~= nil then
        sel_index = 1
    end

    if sel_index ~= nil then
        L.set_item_focus(sel_index)
    end
end

--- Set the focus to the item at the given index
--- @param new_idx number The index of the item to focus
L.set_item_focus = function(new_idx)
    -- Ensure the line is within the bounds
    new_idx = vim.fn.max({ 1, vim.fn.min({ vim.fn.line('$'), new_idx }) })
    local cur_idx = vim.fn.line('.')
    if cur_idx == new_idx then
        return
    end

    if L.state.selected_item_id ~= nil then
        L.move_item_to_index(L.state.selected_item_id, cur_idx, new_idx)
    end

    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { new_idx, 0 })
    L.state.sel_line_nums[L.state.sel_window_key] = id
end

--- Hide the cursor (...and save the original settings)
L.hide_cursor = function()
    vim.g.saved_cursor_blend = vim.api.nvim_get_hl(0, { name = "Cursor" }).blend
    vim.g.saved_guicursor = vim.o.guicursor
    vim.cmd([[hi Cursor blend=100]])
    vim.cmd([[set guicursor+=a:Cursor/lCursor]])
end

--- Show the cursor (...by restoring the original settings)
L.show_cursor = function()
    if vim.g.saved_cursor_blend ~= nil then
        vim.cmd([[hi Cursor blend=vim.g.saved_cursor_blend]])
    end
    if vim.g.saved_guicursor ~= nil then
        vim.o.guicursor = vim.g.saved_guicursor
    end
end

-------------------------------------------------------------------------------
--- Public Module functions
-------------------------------------------------------------------------------

--- Setup the plugin with the given options
--- @param opts table The options to configure the plugin
M.setup = function(opts)
    L.opts = opts
    data.setup(opts)
end

--- Check if the Kanban board UI is open
--- @return boolean `true` if the UI is open
M.is_open = function()
    return L.state.is_open
end

--- Move focus to the next window
M.next_window = function()
    local cur_index = L.get_win_index_for_win_id(vim.api.nvim_get_current_win())
    if cur_index ~= nil then
        L.set_window_focus(cur_index + 1)
    end
end

--- Move focus to the previous windoj
M.prev_window = function()
    local cur_index = L.get_win_index_for_win_id(vim.api.nvim_get_current_win())
    if cur_index > 0 then
        L.set_window_focus(cur_index - 1)
    end
end

--- Move item focus to the next item
M.next_item = function()
    local curline = vim.fn.line('.')
    L.set_item_focus(curline + 1)
end

--- Move item focus to the previous ite
M.prev_item = function()
    local curline = vim.fn.line('.')
    L.set_item_focus(curline - 1)
end

--- Refresh the kanban board data
M.refresh = function()
    data.save_to_file()
    data.reload_files()
    for _, category in ipairs(L.opts.categories) do
        L.reload_items_for_category(category)
    end
end


--- Open the kanban board UI
M.open_ui = function()
    if not utils.directory_exists(L.opts.path) then
        if not L.create_kanban_directory(L.opts.path) then
            return
        end
    end

    if L.opts.window.hide_cursor then
        L.hide_cursor()
    end

    -- Get the main UI (1st element in the ui list)
    local ui = vim.api.nvim_list_uis()[1]
    local max_win_width = ui.width * 0.99
    local max_win_height = ui.height * 0.99

    for index, category in ipairs(L.opts.categories) do
        local win_size = {
            width = vim.fn.min({ L.opts.window.width, vim.fn.round(max_win_width / #L.opts.categories) }),
            height = vim.fn.min({ L.opts.window.height, vim.fn.round(max_win_height) })
        }

        local win_pos = {
            col = vim.fn.round(ui.width / 2 - (win_size.width * #L.opts.categories / 2) +
                (index - 1) * (win_size.width + L.opts.window.gap)),
            row = (ui.height - win_size.height) / 2
        }

        L.state.win_ids[category], L.state.buf_nrs[category] = utils.open_popup_window(
            (L.opts.window.title_decoration[1] .. category .. L.opts.window.title_decoration[2]), -- Title
            win_size,                                                                             -- Window size
            win_pos)                                                                              -- Window position

        L.reload_items_for_category(category)

        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = L.state.buf_nrs[category] })
        vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = L.state.buf_nrs[category] })
        vim.api.nvim_set_option_value('modifiable', false, { buf = L.state.buf_nrs[category] })
        vim.api.nvim_set_option_value('relativenumber', false, { win = L.state.win_ids[category] })
        vim.api.nvim_set_option_value('cursorline', true, { win = L.state.win_ids[category] })
        vim.api.nvim_set_option_value('cursorlineopt', 'both', { win = L.state.win_ids[category] })
        vim.api.nvim_set_option_value('number', L.opts.number, { win = L.state.win_ids[category] })
        vim.api.nvim_set_option_value('winblend', L.opts.window.blend, { win = L.state.win_ids[category] })
        vim.api.nvim_set_option_value('wrap', L.opts.wrap, { win = L.state.win_ids[category] })
        vim.api.nvim_set_hl(WIN_HILIGHT_NAMESPACE_ACTIVE, "CursorLine", { bg = "#AAAAAA", fg = "#000000" })
        vim.api.nvim_set_hl(WIN_HILIGHT_NAMESPACE_ACTIVE, "CursorLineNr", { bg = "#AAAAAA", fg = "#000000" })
        vim.api.nvim_set_hl(WIN_HILIGHT_NAMESPACE_ITEM_SELECTED, "CursorLine", { bg = "#ffffAA", fg = "#000000" })
        vim.api.nvim_set_hl(WIN_HILIGHT_NAMESPACE_ITEM_SELECTED, "CursorLineNr", { bg = "#ffffAA", fg = "#000000" })

        L.configure_buf_keymaps(L.state.buf_nrs[category], L.opts.keymaps)

        -- If no window is selected, select the first window
        if L.state.sel_window_key == nil then
            L.state.sel_window_key = category
        end
        if L.state.sel_line_nums[category] == nil then
            L.state.sel_line_nums[category] = 1
        end
    end

    L.set_window_focus(L.state.win_ids[L.state.sel_window_key])
    L.state.is_open = true
end

--- Close the Kanban board UI
M.close_ui = function()
    L.state.is_open = false

    if L.opts.window.hide_cursor then
        L.show_cursor()
    end

    if L.opts.commit_on_close then
        M.commit_changes()
    end

    for _, category in ipairs(L.opts.categories) do
        if L.state.win_ids[category] ~= nil and vim.api.nvim_win_is_valid(L.state.win_ids[category]) then
            vim.api.nvim_win_close(L.state.win_ids[category], true)
        end
        L.state.win_ids[category] = nil

        if L.state.buf_nrs[category] ~= nil and vim.api.nvim_buf_is_valid(L.state.buf_nrs[category]) then
            vim.api.nvim_buf_delete(L.state.buf_nrs[category], { force = true })
        end
        L.state.buf_nrs[category] = nil
    end
end

--- Select/Deselect the item under cursor
M.toggle_selected_item = function()
    local wid = L.get_current_win_id()
    if wid ~= nil then
        if L.state.selected_item_id ~= nil then
            L.state.selected_item_id = nil
            vim.api.nvim_win_set_hl_ns(wid, WIN_HILIGHT_NAMESPACE_ACTIVE)
        else
            L.state.selected_item_id = L.get_item_id_under_cursor()
            if L.state.selected_item_id == nil then
                utils.log.error("Failed to get the item under cursor")
                return
            end
            vim.api.nvim_win_set_hl_ns(wid, WIN_HILIGHT_NAMESPACE_ITEM_SELECTED)
        end
    else
        utils.log.error("Cannot select item; Active window not found")
    end
end

--- Open the item under cursor
M.open_selected_item = function()
    utils.log.error("Not implemented")
end

--- Add a new item to the current category
M.add_item = function()
    local input = vim.fn.input('Add new item: ')
    if input == nil or input == '' then
        return
    end

    data.add_item(L.opts.default_category, input)
    L.reload_items_for_category(L.opts.default_category)
end

--- Delete selected item
M.delete_item = function()
    local item_id = L.get_item_id_under_cursor()
    local confirm = vim.fn.confirm('Delete item [' .. item_id .. ']?', '&Yes\n&No', 2) == 1
    if confirm and item_id ~= nil then
        data.delete_item(item_id)
    end
    M.refresh()
end

--- Commit unsaved changes
M.commit_changes = function()
    if not data.has_unsaved_changes() then
        return
    end

    if not L.opts.silent_commit then
        if vim.fn.confirm('Commit changes?', '&Yes\n&No', 2) ~= 1 then
            return
        end
    end

    data.save_to_file()
end

return M
