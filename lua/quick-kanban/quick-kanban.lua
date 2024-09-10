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
        --- This variable is `true` if Kanban UI is open
        --- @type boolean
        is_open = false,

        --- Dictionary of window Ids for each category
        --- @type table The "key" is "category" name
        win_ids = {},

        --- Dictionary of buffer numbers for each category
        --- @type table The "key" is "category" name
        buf_nrs = {},

        --- Dictionary of previously selected line numbers for each category
        --- @type table The "key" is "category" name
        sel_line_nums = {},

        --- The name of the currently active category.
        --- @type string? The category name
        selected_category = nil,

        --- The id of the currently selected item
        --- @type number?
        selected_item_id = nil
    }
}

-------------------------------------------------------------------------------
--- Autocommands
-------------------------------------------------------------------------------

--- Autogroup which monitors entering a window and quits if it's not Kanban
vim.api.nvim_create_autocmd('WinEnter', {
    group = vim.api.nvim_create_augroup('MonitorWindowEnter', { clear = true }),
    callback = function()
        if L.get_current_win_id() == nil and L.state.is_open then
            M.close_ui()
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
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.next_category, ':lua require("quick-kanban").next_category()<CR>',
        opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.prev_category, ':lua require("quick-kanban").prev_category()<CR>',
        opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.next_item, ':lua require("quick-kanban").next_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.prev_item, ':lua require("quick-kanban").prev_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.open_item, ':lua require("quick-kanban").open_selected_item()<CR>',
        opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.select_item, ':lua require("quick-kanban").select_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', keymaps.rename, ':lua require("quick-kanban").rename_item()<CR>', opts)
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

--- Helper function to get the index for the given category
--- @param category string The category key
--- @return number? The table index for the given category (or `nil` if not found)
L.get_index_for_category = function(category)
    for i, value in ipairs(L.opts.categories) do
        if value == category then
            return i
        end
    end
    utils.log.error("Failed to get index for category: " .. category)
    return nil
end

--- Helper function to get the category for the given table index
--- @param index number The index of a table
--- @return string? The category for the given index (or `nil` if not found)
L.get_category_for_index = function(index)
    for i, category in ipairs(L.opts.categories) do
        if i == index then
            return category
        end
    end
    utils.log.error("Failed to get category for index: " .. index)
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
--- @param category string The category where the item is located
--- @param target_index number The index to move the item to
L.move_item_to_index = function(item_id, category, target_index)
    data.move_item_to_index(item_id, category, target_index)
    L.reload_items_for_category(category)
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

--- Helper function to set the focus to the category at the given index
--- @param index number The index of the category to focus
L.set_category_focus = function(index)
    -- Ensure the index is within the bounds
    index = vim.fn.max({ 1, vim.fn.min({ #L.opts.categories, index }) })
    local prev_index = L.get_win_index_for_win_id(vim.api.nvim_get_current_win())
    if prev_index == nil or prev_index == index then
        return
    end

    local prev_category = L.get_category_for_index(prev_index)
    local new_category = L.get_category_for_index(index)
    if prev_category == nil or new_category == nil then
        utils.log.error("Invalid argument(s): "
            .. "index=" .. (index or "nil") .. "; "
            .. "prev_category=" .. (prev_category or "nil") .. "; "
            .. "new_cateogory=" .. (new_category or "nil"))
        return
    end

    local new_wid = L.state.win_ids[new_category]
    local prev_wid = L.state.win_ids[prev_category]
    if new_wid == nil or prev_wid == nil then
        utils.log.error("Unexpected error: (prev_wid=" .. prev_wid .. "; new_wid=" .. new_wid)
        return
    end

    -- Set the window hilight groups
    vim.api.nvim_win_set_hl_ns(prev_wid, 0)
    if L.state.selected_item_id ~= nil then
        vim.api.nvim_win_set_hl_ns(new_wid, WIN_HILIGHT_NAMESPACE_ITEM_SELECTED)
    else
        vim.api.nvim_win_set_hl_ns(new_wid, WIN_HILIGHT_NAMESPACE_ACTIVE)
    end

    -- Set the focus to the new window
    vim.api.nvim_set_current_win(new_wid)
    L.state.selected_category = new_category
    if L.state.sel_line_nums[new_category] == nil or L.state.selected_item_id ~= nil then
        L.state.sel_line_nums[new_category] = 1
    end

    -- Move selected item to the new category (or restore the previously selected item)
    if L.state.selected_item_id ~= nil then
        L.move_item_to_category(L.state.selected_item_id, prev_category, new_category)
        L.set_item_focus(1)
    else
        L.set_item_focus(L.state.sel_line_nums[new_category])
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

    --local cur_category = L.get_category_for_win_id(vim.api.nvim_get_current_win())
    if L.state.selected_item_id ~= nil then
        L.move_item_to_index(L.state.selected_item_id, L.state.selected_category, new_idx)
    end
    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { new_idx, 0 })
    L.state.sel_line_nums[L.state.selected_category] = new_idx
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

--- Move focus to the next category
M.next_category = function()
    local cur_index = L.get_index_for_category(L.state.selected_category)
    L.set_category_focus(cur_index + 1)
end

--- Move focus to the previous category
M.prev_category = function()
    local cur_index = L.get_index_for_category(L.state.selected_category)
    L.set_category_focus(cur_index - 1)
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
    data.save_all_unsaved_item_changes()
    data.reload_item_files()

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

    -- Create a window for each category
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
        vim.api.nvim_set_option_value('linebreak', L.opts.wrap, { win = L.state.win_ids[category] })
        vim.api.nvim_set_hl(WIN_HILIGHT_NAMESPACE_ACTIVE, "CursorLine", { bg = "#AAAAAA", fg = "#000000" })
        vim.api.nvim_set_hl(WIN_HILIGHT_NAMESPACE_ACTIVE, "CursorLineNr", { bg = "#AAAAAA", fg = "#000000" })
        vim.api.nvim_set_hl(WIN_HILIGHT_NAMESPACE_ITEM_SELECTED, "CursorLine", { bg = "#ffffAA", fg = "#000000" })
        vim.api.nvim_set_hl(WIN_HILIGHT_NAMESPACE_ITEM_SELECTED, "CursorLineNr", { bg = "#ffffAA", fg = "#000000" })

        L.configure_buf_keymaps(L.state.buf_nrs[category], L.opts.keymaps)

        -- Init the selected line number for the category
        if L.state.sel_line_nums[category] == nil then
            L.state.sel_line_nums[category] = 1
        end
    end

    -- If no cateogyr is selected, select the first category
    if L.state.selected_category == nil then
        L.state.selected_category = L.opts.categories[1]
    end

    L.set_category_focus(L.state.win_ids[L.state.selected_category])
    L.state.is_open = true
end

--- Close the Kanban board UI
M.close_ui = function()
    L.state.is_open = false
    L.state.selected_item_id = nil

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
    local item_id = L.get_item_id_under_cursor()
    if item_id == nil then
        return
    end

    local item = data.get_item(item_id)
    if item == nil then
        return
    end

    if item.attachment_path == nil then
        if not data.create_attachment(item) then
            utils.log.error("Failed to create attachment for item: " .. item.id)
            return
        end
    end

    vim.cmd('new ' .. item.attachment_path)
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

--- Rename the current item
M.rename_item = function()
    local item_id = L.get_item_id_under_cursor()
    local item = data.get_item(item_id or -1)
    if item == nil then
        return
    end

    local input = vim.fn.input({ prompt = 'New name for item [' .. item_id .. ']', default = item.title })
    if input ~= nil and #input > 0 then
        item.title = input
        data.save_item(item)
        L.reload_items_for_category(L.state.selected_category)
    end
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

    data.save_all_unsaved_item_changes()
end

return M
