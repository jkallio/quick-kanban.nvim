local WIN_HILIGHT_INACTIVE = 10100
local WIN_HILIGHT_ACTIVE = 10101
local WIN_HILIGHT_ITEM_SELECTED = 10102
local PREVIEW_KEY = "preview"
local ARCHIVE_KEY = "archive"

--- @class quick-kanban.quick-kanban
local M = {
    ---  @type quick-kanban.config.options
    opts = {},

    --- @type quick-kanban.state
    state = {},

    --- @type quick-kanban.database
    database = {},

    --- @type quick-kanban.metadata
    metadata = {},

    --- @type table
    log = {},

    --- Utility functions
    --- @type quick-kanban.utils
    utils = {}
}

-------------------------------------------------------------------------------
--- Autocommands
-------------------------------------------------------------------------------

--- Autogroup which monitors entering a window and quits if it's not Kanban
vim.api.nvim_create_autocmd('WinEnter', {
    group = vim.api.nvim_create_augroup('MonitorWinEnter', { clear = true }),
    callback = function()
        local wid = M.state.get_current_wid()
        if wid == nil then
            if M.state.is_open then
                M.close_ui()
            end
        end
    end
})

--- Autogroup which monitors entering a window and quits if it's not Kanban
vim.api.nvim_create_autocmd('WinLeave', {
    group = vim.api.nvim_create_augroup('MonitorWinLeave', { clear = true }),
    callback = function()
        local wid = M.state.get_current_wid()
        if wid ~= nil and wid == M.state.get_wid_for_category(PREVIEW_KEY) then
            -- Save unsaved changes to the attachment file
            local bufnr = vim.api.nvim_win_get_buf(wid)
            if vim.api.nvim_get_option_value('modified', { buf = bufnr }) then
                vim.api.nvim_command('write')
            end
        end
    end
})

-- Set up an autocommand to trigger on buffer enter
vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("MonitorBufferChange", { clear = true }),
    callback = function()
        if M == nil or M.state == nil or M.state.check_windows_validity == nil then
            return
        end

        if not M.state.check_windows_validity() then
            M.log.warn("Invalid window(s) detected; Closing UI")
            M.close_ui()
        end
    end
})


-------------------------------------------------------------------------------
--- Local Helper functions
-------------------------------------------------------------------------------

--- Create all the required Kanban directories
--- @param path string path to the directory
--- @return boolean `false` if the user rejects the prompt
local create_kanban_directories = function(path)
    if not M.utils.directory_exists(path) then
        if vim.fn.confirm(
                'Kanban directory does not exist for this project.\r\nCreate Kanban directory?\r\n' .. path .. '?',
                '&Yes\n&No', 2) ~= 1 then
            return false
        end

        M.utils.touch_directory(path)
        M.utils.touch_directory(M.utils.concat_paths(path, M.opts.subdirectories.items))
        M.utils.touch_directory(M.utils.concat_paths(path, M.opts.subdirectories.archive))
        M.utils.touch_directory(M.utils.concat_paths(path, M.opts.subdirectories.attachments))
        M.metadata.save_to_file()
    end
    return true
end

--- Apply the highlight to the item IDs in the buffer
--- @param bufnr number The buffer number
local hilight_item_ids_in_buffer = function(bufnr)
    for i = 0, vim.api.nvim_buf_line_count(bufnr) - 1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
        if line then
            -- Find the start and end positions of the prefix
            local s, e = string.find(line, "%[(.*)%]")
            if s and e then
                vim.api.nvim_buf_add_highlight(bufnr, 0, "PrefixHilight", i, s - 1, e)
            end
        end
    end
end

--- Reload window buffer for category
--- @param category string
local reload_buffer_for_category = function(category)
    local window = M.state.get_window(category)
    if window == nil or window.bufnr == nil then
        return
    end

    local items = category == ARCHIVE_KEY and M.database.get_archived_items() or
        M.database.get_items_for_category_sorted(category)
    local lines = {}
    for _, item in ipairs(items) do
        table.insert(lines, " [" .. item.id .. "] " .. item.title)
    end

    vim.api.nvim_set_option_value('modifiable', true, { buf = window.bufnr })
    vim.api.nvim_buf_set_lines(window.bufnr, 0, -1, false, lines)
    --
    -- TODO: This iterates over all the lines twice, which is not optimal
    -- Move the highlighting into the buffer update loop above?
    --
    hilight_item_ids_in_buffer(window.bufnr)
    vim.api.nvim_set_option_value('modifiable', false, { buf = window.bufnr })
end


--- Set the focus to the category at the given index
--- @param index number The index of the category to focus
--- @return boolean `true` if the category was focused
local set_category_focus = function(index)
    local cur_category = M.state.selected_category
    local new_category = nil

    if index > #M.metadata.json.categories and M.opts.show_archive then
        -- If the index is out of bounds, move to archive (or archive the selected item)
        if M.state.selected_item_id ~= nil then
            M.archive_selected_item()
            M.toggle_selected_item()
            return false
        else
            new_category = ARCHIVE_KEY
        end
    elseif M.state.selected_category == ARCHIVE_KEY then
        -- When moving from archive, move to the last category
        new_category = M.metadata.json.categories[#M.metadata.json.categories]
    else
        -- Ensure the index is within the bounds
        index = vim.fn.max({ 1, vim.fn.min({ #M.metadata.json.categories, index }) })
        new_category = M.metadata.get_category(index)
    end

    if cur_category == nil or new_category == nil then
        M.log.error("Invalid argument(s): "
            .. "cur_category=" .. (cur_cateogry or "nil") .. "; "
            .. "new_cateogory=" .. (new_category or "nil"))
        M.close_ui()
        return false
    end

    local cur_wid = M.state.get_wid_for_category(cur_category)
    local new_wid = M.state.get_wid_for_category(new_category)
    if new_wid == nil or cur_wid == nil then
        M.log.error("Unexpected error: " ..
            "cur_wid=" .. (cur_wid or "nil") .. "; " .. "new_wid=" .. (new_wid or "nil"))
        M.close_ui()
        return false
    end

    -- Set the window hilight groups
    vim.api.nvim_win_set_hl_ns(cur_wid, WIN_HILIGHT_INACTIVE)
    vim.api.nvim_win_set_hl_ns(new_wid,
        M.state.selected_item_id ~= nil and WIN_HILIGHT_ITEM_SELECTED or WIN_HILIGHT_ACTIVE)

    -- Set the focus to the new window
    vim.api.nvim_set_current_win(new_wid)
    M.state.selected_category = new_category

    -- Move selected item to the new category (or restore the previously selected item)
    if M.state.selected_item_id ~= nil
        and cur_category ~= new_category
        and M.database.move_item_to_category(M.state.selected_item_id, M.state.selected_category)
    then
        reload_buffer_for_category(cur_category)
        reload_buffer_for_category(new_category)
        M.set_current_buffer_line_focus(1)
    else
        M.set_current_buffer_line_focus(M.state.get_selected_line_for_category(new_category))
    end

    return true
end

--- Set the focus to the line number in the current window/buffer
--- @param line_num number The line number to focus
M.set_current_buffer_line_focus = function(line_num)
    local cur_wid = M.state.get_current_wid()
    if cur_wid == nil then
        M.log.error("Failed to set item focus; Active window not found")
        M.close_ui()
        return
    end

    -- Ensure the line is within the bounds
    local cur_idx = vim.fn.line('.')
    line_num = vim.fn.max({ 1, vim.fn.min({ vim.fn.line('$'), line_num }) })
    if cur_idx == line_num then
        return
    end

    -- If an item is currently selected, move it to new index
    if M.state.is_item_selected() then
        if M.database.move_item_within_category(M.state.selected_item_id, line_num - cur_idx) then
            reload_buffer_for_category(M.state.selected_category)
        else
            M.log.error("Failed to move item; ID=" .. M.state.selected_item_id .. "; Index=" .. line_num)
            M.close_ui()
            return
        end
    end

    -- Update the cursor position in buffer
    vim.api.nvim_win_set_cursor(cur_wid, { line_num, 99 })
    M.state.set_selected_line_for_category(M.state.selected_category, line_num)
end

--- Returns
local get_help_text_lines = function(mappings)
    local lines = {}
    local center = (M.opts.window.width * #M.metadata.json.categories) / 2

    -- Collect all the keymaps from the table and format them
    local items = {}
    local rows = vim.fn.floor(M.opts.window.height / 2) - 7
    for key, mapping in pairs(mappings) do
        if key == nil or mapping == nil then
            M.log.warn("Invalid keymap: " .. vim.inspect(mapping))
            return lines
        end

        local keymap = mapping
        if type(keymap) == "table" then
            keymap = keymap[1]
        end

        --local help = M.utils.right_pad(keymap.desc, 20, '.') .. key
        local help = M.utils.right_pad((key .. ' '), 20, '.') .. ' ' .. keymap
        table.insert(items, help)
    end

    local min_width = 35
    for i, item in ipairs(items) do
        local row = ((i - 1) % rows) + 1
        local line = lines[row] or ""
        line = M.utils.trim_left(line)
        line = line .. M.utils.right_pad(item, 35)
        lines[row] = line
        min_width = vim.fn.max({ min_width, #line })
    end

    for row, line in pairs(lines) do
        local new_line = M.utils.right_pad(line, min_width)
        new_line = M.utils.left_pad(new_line, center + #new_line / 2)
        lines[row] = new_line
    end

    local title = "Quick Kanban Help"
    title = M.utils.left_pad(title, center + #title / 2)

    table.insert(lines, 1, title)
    table.insert(lines, 2, "")
    table.insert(lines, "")

    local copyright = "(c) 2024 Jussi Kallio"
    copyright = M.utils.left_pad(copyright, center + #copyright / 2)
    table.insert(lines, copyright)
    return lines
end

-------------------------------------------------------------------------------
--- Public Module functions
-------------------------------------------------------------------------------

--- Initialize the plugin with the given options
--- @param options table The config table to configure the plugin
M.init = function(options, log)
    M.opts = options
    M.log = log

    M.state = require('quick-kanban.state')
    M.state.init(M.opts, M.log)

    M.metadata = require('quick-kanban.metadata')
    M.metadata.init(M.opts, M.log)

    M.database = require('quick-kanban.database')
    M.database.init(M.opts, M.metadata, M.log)

    M.utils = require('quick-kanban.utils')

    M.state.selected_category = M.metadata.json.default_category
    for i, category in ipairs(M.metadata.json.categories) do
        M.state.windows[category] = {
            index = i,
            id = nil,
            bufnr = nil,
            selected_line = 1,
        }
    end

    -- Set the window hilight groups
    vim.api.nvim_set_hl(WIN_HILIGHT_ACTIVE, "NormalFloat", { bg = "None", fg = "#DDDDDD" })
    vim.api.nvim_set_hl(WIN_HILIGHT_ACTIVE, "CursorLine",
        { bg = M.opts.window.active_text_bg, fg = M.opts.window.active_text_fg })
    vim.api.nvim_set_hl(WIN_HILIGHT_ACTIVE, "CursorLineNr",
        { bg = M.opts.window.active_text_bg, fg = M.opts.window.active_text_fg })
    vim.api.nvim_set_hl(WIN_HILIGHT_ACTIVE, "FloatBorder", { bg = "None", fg = M.opts.window.accent_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ACTIVE, "FloatTitle", { bg = "None", fg = M.opts.window.accent_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ACTIVE, "FloatFooter", { bg = "None", fg = M.opts.window.accent_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ACTIVE, "PrefixHilight", { bg = "None", fg = M.opts.window.accent_color })

    vim.api.nvim_set_hl(WIN_HILIGHT_INACTIVE, "NormalFloat", { bg = "None", fg = "#888888" })
    vim.api.nvim_set_hl(WIN_HILIGHT_INACTIVE, "CursorLine", { bg = "#222222", fg = "None" })
    vim.api.nvim_set_hl(WIN_HILIGHT_INACTIVE, "CursorLineNr", { bg = "#222222", fg = "None" })
    vim.api.nvim_set_hl(WIN_HILIGHT_INACTIVE, "FloatBorder", { bg = "None", fg = "#444444" })
    vim.api.nvim_set_hl(WIN_HILIGHT_INACTIVE, "FloatTitle", { bg = "None", fg = M.opts.window.accent_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_INACTIVE, "FloatFooter", { bg = "None", fg = "#444444" })
    vim.api.nvim_set_hl(WIN_HILIGHT_INACTIVE, "PrefixHilight", { bg = "None", fg = "#444444" })

    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "NormalFloat", { bg = "None", fg = "#DDDDDD" })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "CursorLine",
        { bg = M.opts.window.selected_text_bg, fg = M.opts.window.selected_text_fg })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "CursorLineNr",
        { bg = M.opts.window.selected_text_bg, fg = M.opts.window.selected_text_fg })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "FloatBorder",
        { bg = "None", fg = M.opts.window.hilight_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "FloatTitle",
        { bg = "None", fg = M.opts.window.hilight_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "FloatFooter",
        { bg = "None", fg = M.opts.window.hilight_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "PrefixHilight", { bg = "None", fg = "#888888" })
end

--- Move focus to the next category
M.next_category = function()
    if M.state.selected_category == ARCHIVE_KEY then
        return
    end

    for i, category in ipairs(M.metadata.json.categories) do
        if category == M.state.selected_category then
            if set_category_focus(i + 1) then
                M.update_preview(nil, false)
            end
            return
        end
    end
end

--- Move focus to the previous category
M.prev_category = function()
    if M.state.selected_category == ARCHIVE_KEY then
        if set_category_focus(#M.metadata.json.categories) then
            M.update_preview(nil, false)
        end
    else
        for i, category in ipairs(M.metadata.json.categories) do
            if category == M.state.selected_category then
                if set_category_focus(i - 1) then
                    M.update_preview(nil, false)
                end
                return
            end
        end
    end
end

--- Move item focus to the next item
M.next_item = function()
    local curline = vim.fn.line('.')
    M.set_current_buffer_line_focus(curline + 1)
    M.update_preview(nil, false)
end

--- Move item focus to the previous ite
M.prev_item = function()
    local curline = vim.fn.line('.')
    M.set_current_buffer_line_focus(curline - 1)
    M.update_preview(nil, false)
end

--- Open the kanban board UI
M.open_ui = function()
    if not M.utils.directory_exists(M.opts.path) then
        if not create_kanban_directories(M.opts.path) then
            return
        end
    end

    --- Local helper function for setting buffer options for a category window
    --- @param bufnr number The buffer number
    local function set_buffer_options(bufnr)
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
        vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
        vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
    end

    --- Local helper function for setting window options for a category window
    --- @param wid number The window id
    --- @param opts table The options for the window
    local function set_window_options(wid, opts)
        vim.api.nvim_set_option_value('relativenumber', false, { win = wid })
        vim.api.nvim_set_option_value('cursorline', true, { win = wid })
        vim.api.nvim_set_option_value('cursorlineopt', 'both', { win = wid })
        vim.api.nvim_set_option_value('number', false, { win = wid })
        vim.api.nvim_set_option_value('winblend', opts.window.blend, { win = wid })
        vim.api.nvim_set_option_value('wrap', opts.wrap, { win = wid })
        vim.api.nvim_set_option_value('linebreak', opts.wrap, { win = wid })
        vim.api.nvim_win_set_hl_ns(wid, WIN_HILIGHT_INACTIVE)
    end

    --- Local helper function to disable default vim keys
    local function disable_keys(bufnr, keys)
        for _, key in ipairs(keys) do
            M.utils.set_keymap(bufnr, string.lower(key), '<nop>')
            M.utils.set_keymap(bufnr, string.upper(key), '<nop>')
        end
    end

    --- Local helper function for setting keymaps for a buffer
    local function set_mappings(bufnr, mappings)
        M.utils.set_keymap(bufnr, mappings.show_help, ':lua require("quick-kanban").show_help_text()<cr>')
        M.utils.set_keymap(bufnr, mappings.archive_item, ':lua require("quick-kanban").archive_item()<cr>')
        M.utils.set_keymap(bufnr, mappings.toggle_archive, ':lua require("quick-kanban").toggle_archive_window()<cr>')
        M.utils.set_keymap(bufnr, mappings.toggle_preview, ':lua require("quick-kanban").toggle_preview_window()<cr>')
        M.utils.set_keymap(bufnr, mappings.add_item, ':lua require("quick-kanban").add_item()<cr>')
        M.utils.set_keymap(bufnr, mappings.edit_item, ':lua require("quick-kanban").edit_item()<cr>')
        M.utils.set_keymap(bufnr, mappings.delete, ':lua require("quick-kanban").delete_item()<cr>')
        M.utils.set_keymap(bufnr, mappings.quit, ':lua require("quick-kanban").close_ui()<cr>')
        M.utils.set_keymap(bufnr, mappings.next_category, ':lua require("quick-kanban").next_category()<cr>')
        M.utils.set_keymap(bufnr, mappings.prev_category, ':lua require("quick-kanban").prev_category()<cr>')
        M.utils.set_keymap(bufnr, mappings.next_item, ':lua require("quick-kanban").next_item()<cr>')
        M.utils.set_keymap(bufnr, mappings.prev_item, ':lua require("quick-kanban").prev_item()<cr>')
        M.utils.set_keymap(bufnr, mappings.open_item, ':lua require("quick-kanban").open_item()<cr>')
        M.utils.set_keymap(bufnr, mappings.select_item, ':lua require("quick-kanban").select_item()<cr>')
        M.utils.set_keymap(bufnr, mappings.rename, ':lua require("quick-kanban").rename_item()<cr>')
    end

    if M.opts.window.hide_cursor then
        M.utils.hide_cursor()
    end

    -- Get the main UI (1st element in the ui list)
    local ui = vim.api.nvim_list_uis()[1]
    local win_width = vim.fn.min({ M.opts.window.width, vim.fn.floor(ui.width / #M.metadata.json.categories) })
    local win_height = vim.fn.min({ M.opts.window.height - 2 * M.opts.window.vertical_gap, (ui.height - 3) -
    2 * M.opts.window.vertical_gap })
    local win_pos_left = vim.fn.floor(ui.width / 2 - (win_width * #M.metadata.json.categories / 2)) -
        (M.opts.show_archive and (win_width / 2) or 0)
    if M.opts.show_preview then
        win_height = vim.fn.floor(win_height / 2)
    end

    -- Create a window for each category
    for i, category in ipairs(M.metadata.json.categories) do
        local win_size = {
            width = win_width,
            height = win_height
        }
        local win_pos = {
            col = win_pos_left + (i - 1) * (win_width + M.opts.window.horizontal_gap),
            row = M.opts.window.vertical_gap
        }
        local wid, bufnr = M.utils.open_popup_window(
            (M.opts.window.title_decoration[1] .. category .. M.opts.window.title_decoration[2]),
            win_size, win_pos)

        M.state.set_wid_for_category(category, wid)
        M.state.set_buf_for_category(category, bufnr)

        set_window_options(wid, M.opts)
        set_buffer_options(bufnr)
        disable_keys(bufnr, M.opts.disabled_keys)
        set_mappings(bufnr, M.opts.mappings)

        --M.state.windows[category].selected_line = M.state.windows[category].selected_line or 1
        reload_buffer_for_category(category)
    end

    --- Create preview window
    if M.opts.show_preview then
        local wid, bufnr = M.utils.open_popup_window("",
            {
                width = vim.fn.round(#M.metadata.json.categories * win_width) +
                    (#M.metadata.json.categories - 1) * M.opts.window.horizontal_gap,
                height = win_height
            },
            {
                col = win_pos_left,
                row = win_height + 1 + M.opts.window.vertical_gap * 2
            })

        M.state.windows[PREVIEW_KEY] = {}
        M.state.windows[PREVIEW_KEY].id = wid
        M.state.windows[PREVIEW_KEY].bufnr = bufnr

        -- Create a help text buffer for the default preview window
        local help_text = get_help_text_lines(M.opts.mappings)
        vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, help_text)

        -- Set the buffer options
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
        vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
        vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

        -- Set the window options
        vim.api.nvim_set_option_value('winblend', M.opts.window.blend, { win = wid })
        vim.api.nvim_set_option_value('wrap', false, { win = wid })
        vim.api.nvim_set_option_value('linebreak', false, { win = wid })

        -- On default, set the hilight to inactive
        vim.api.nvim_win_set_hl_ns(wid, WIN_HILIGHT_ACTIVE)

        --- Disable default keys for the preview window
        disable_keys(bufnr, M.opts.disabled_keys)
    end

    --- Create the archive window
    if M.opts.show_archive then
        local wid, bufnr = M.utils.open_popup_window(
            (M.opts.window.title_decoration[1] .. "Archive" .. M.opts.window.title_decoration[2]),
            {
                width = win_width,
                height = win_height +
                    (M.opts.show_preview and (win_height + M.opts.window.vertical_gap * 2) or 0)
            },
            {
                col = win_pos_left +
                    (#M.metadata.json.categories) * (win_width + M.opts.window.horizontal_gap),
                row = M.opts.window.vertical_gap
            })

        M.state.windows[ARCHIVE_KEY] = {}
        M.state.windows[ARCHIVE_KEY].id = wid
        M.state.windows[ARCHIVE_KEY].bufnr = bufnr

        set_window_options(wid, M.opts)
        set_buffer_options(bufnr)
        disable_keys(bufnr, M.opts.disabled_keys)
        set_mappings(bufnr, M.opts.mappings)
        M.utils.set_keymap(bufnr, M.opts.mappings.archive_item,
            ':lua require("quick-kanban").unarchive_item()<cr>')
        M.utils.set_keymap(bufnr, M.opts.mappings.unarchive_item,
            ':lua require("quick-kanban").unarchive_item()<cr>')

        --M.state.windows[ARCHIVE_KEY].selected_line = M.state.windows[ARCHIVE_KEY].selected_line or 1
        reload_buffer_for_category(ARCHIVE_KEY)
    end

    set_category_focus(M.metadata.get_category_index(M.state.selected_category) or 1)
    M.set_current_buffer_line_focus(M.state.get_selected_line_for_category(M.state.selected_category))
    M.update_preview(nil, false)
    M.state.is_open = true
end

--- Close the Kanban board UI
M.close_ui = function()
    M.state.is_open = false
    M.state.selected_item_id = nil
    M.utils.show_cursor()

    for key, win in pairs(M.state.windows) do
        if vim.api.nvim_win_is_valid(win.id or -1) then
            vim.api.nvim_win_close(win.id, true)
        end
        M.state.set_wid_for_category(key, nil)

        if vim.api.nvim_buf_is_valid(win.bufnr or -1) then
            vim.api.nvim_buf_delete(win.bufnr, { force = true })
        end
        M.state.set_buf_for_category(key, nil)
    end
end

--- Select/Deselect the item under cursor
M.toggle_selected_item = function()
    if M.state.selected_category == ARCHIVE_KEY then
        return
    end

    local wid = M.state.get_current_wid()
    if wid == nil then
        M.log.error("Cannot select item; Active window not found")
        M.close_ui()
        return
    end

    M.state.selected_item_id = M.state.selected_item_id == nil and M.state.get_current_item_id() or nil
    vim.api.nvim_win_set_hl_ns(wid,
        M.state.selected_item_id ~= nil and WIN_HILIGHT_ITEM_SELECTED or WIN_HILIGHT_ACTIVE)
end

--- Open the item under cursor
M.open_selected_item = function()
    local item = M.database.items[M.state.get_current_item_id() or -1]
    if item == nil then
        M.log.error("Failed to open item: item=nil")
        M.close_ui()
        return
    end

    if item.attachment_path == nil then
        M.database.create_attachment(item)
    end

    vim.cmd('new ' .. item.attachment_path)
end

--- Add a new item to the current category
M.add_item = function()
    local input = vim.fn.input('Add new item: ')
    if input == nil or input == '' then
        return
    end

    M.database.add_item(M.metadata.json.default_category, input)
    reload_buffer_for_category(M.metadata.json.default_category)

    set_category_focus(M.metadata.get_category_index(M.metadata.json.default_category) or 1)
    M.set_current_buffer_line_focus(1)
end

--- Rename the current item
M.rename_item = function()
    local item = M.database.items[M.state.get_current_item_id() or -1]
    if item == nil then
        M.log.error("Failed to rename item: item=nil")
        return
    end

    local input = vim.fn.input({ prompt = 'New name for item [' .. item.id .. ']', default = item.title })
    if input ~= nil and #input > 0 then
        item.title = input
        M.database.save_item(item)
        reload_buffer_for_category(item.category)
    end
end

--- Archive the selected item
--- @return boolean `true` if the item was archived
M.archive_selected_item = function()
    local item = M.database.items[M.state.get_current_item_id() or -1]
    if item == nil then
        M.log.error("Failed to archive item: item=nil")
        return false
    end

    local confirm = vim.fn.confirm('Archive item "[' .. item.id .. '] ' .. item.title .. '"?', '&Yes\n&No', 2) == 1
    if confirm then
        M.database.archive_item(item.id)
        reload_buffer_for_category(item.category)
        reload_buffer_for_category(ARCHIVE_KEY)
        return true
    end

    return false
end

-- Unarchive the selected item
-- @return boolean `true` if the item was unarchived
M.unarchive_selected_item = function()
    if M.state.selected_category ~= ARCHIVE_KEY then
        M.log.warn("Cannot unarchive item")
        return false
    end

    local item = M.database.unarchive_item(M.state.get_current_item_id() or -1)
    if item == nil then
        M.log.error("Failed to unarchive item: item=nil")
        return false
    end

    reload_buffer_for_category(item.category)
    reload_buffer_for_category(ARCHIVE_KEY)
    return true
end

--- Delete selected item
--- @return boolean `true` if the item was deleted
M.delete_selected_item = function()
    local item = M.database.get_item(M.state.get_current_item_id() or -1)
    if item == nil then
        M.log.error("Failed to delete item: item=nil")
        return false
    end

    local confirm = vim.fn.confirm(
        'Permanently DELETE item "[' .. item.id .. '] ' .. item.title .. '"? (This cannot be undone)',
        '&Yes\n&No', 2) == 1
    if confirm then
        M.database.delete_item(item.id)
        reload_buffer_for_category(M.state.selected_category)
        return true
    end
    return false
end

--- Update the preview window
--- @param item table? The item to preview
--- @param edit_mode boolean True if should stay in preview window
M.update_preview = function(item, edit_mode)
    if M.state.is_item_selected() or not M.opts.show_preview then
        return
    end

    -- If no item is provided, get the current item
    if item == nil then
        local item_id = M.state.get_current_item_id()
        item = M.database.get_item(item_id or -1)
        if item == nil then
            M.state.preview_item_id = nil
            M.show_help_text()
            return
        end
    end

    M.state.preview_item_id = item.id
    local wid = M.state.get_wid_for_category(PREVIEW_KEY)
    if wid == nil then
        M.log.error("Failed to update preview; Preview window not found")
        M.close_ui()
        return
    end

    -- If item has no attachment, create and set a new empty buffer in Preview window
    if item.attachment_path == nil or not M.utils.file_exists(item.attachment_path) then
        M.state.preview_item_id = nil
        vim.api.nvim_win_set_buf(wid, vim.api.nvim_create_buf(false, true))
        return
    end

    -- Store the currently active window (to restore it later)
    local cur_wid = vim.api.nvim_get_current_win()

    --
    -- TODO: Should we cache the loaded attachment buffers?
    --
    vim.api.nvim_set_current_win(wid)
    vim.cmd('edit! ' .. item.attachment_path)
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
    vim.api.nvim_set_option_value('buflisted', false, { buf = bufnr })
    vim.api.nvim_set_option_value('winblend', M.opts.window.blend, { win = wid })
    vim.api.nvim_set_option_value('number', M.opts.number, { win = wid })
    M.utils.set_keymap(bufnr, M.opts.mappings.end_editing, ':lua require("quick-kanban").end_editing()<cr>')

    if edit_mode then
        vim.api.nvim_win_set_hl_ns(wid, WIN_HILIGHT_ACTIVE)
        vim.api.nvim_win_set_hl_ns(cur_wid, WIN_HILIGHT_INACTIVE)
        M.utils.show_cursor()
    elseif cur_wid ~= nil then
        vim.api.nvim_set_current_win(cur_wid)
    else
        M.close_ui()
    end
end

--- Show the help text in the preview window
M.show_help_text = function()
    if not M.opts.show_preview then
        M.toggle_preview_window()
    end

    local win = M.state.get_window(PREVIEW_KEY)
    if win == nil or win.id == nil or win.bufnr == nil then
        M.log.error("Failed to show help text; Preview window not found")
        M.close_ui()
        return
    end
    vim.api.nvim_win_set_buf(win.id, win.bufnr)
end

--- Toggle the visibility of the archive category
M.toggle_archive_window = function()
    M.opts.show_archive = not M.opts.show_archive
    if (M.opts.show_archive == false) and M.state.selected_category == ARCHIVE_KEY then
        M.state.selected_category = M.metadata.json.default_category
    end
    M.close_ui()
    M.open_ui()
end

--- Toggle the visibility of the preview category
M.toggle_preview_window = function()
    M.opts.show_preview = not M.opts.show_preview
    M.close_ui()
    M.open_ui()
end

--- Edit the attachment of the selected item directly in the preview window
M.edit_item = function()
    if M.state.selected_category == ARCHIVE_KEY then
        M.log.warn("Cannot edit archived items")
        return
    end

    local item = M.database.get_item(M.state.get_current_item_id() or -1)
    if item == nil then
        return
    end

    if M.opts.show_preview == false then
        M.opts.show_preview = true
        M.close_ui()
        M.open_ui()
    end

    if item.attachment_path == nil then
        M.database.create_attachment(item)
    end

    M.update_preview(item, true)
end

--- End editing the attachment
M.end_editing = function()
    local wid = vim.api.nvim_get_current_win()
    if M.state.get_wid_for_category(PREVIEW_KEY) ~= wid then
        M.log.error("Not in edit mode")
        M.close_ui()
        return
    end
    vim.api.nvim_win_set_hl_ns(wid, WIN_HILIGHT_INACTIVE)

    if M.state.selected_category == nil then
        M.state.selected_category = M.metadata.json.default_category
    end

    local window = M.state.get_window(M.state.selected_category)
    if window == nil then
        M.log.error("Failed to end editing; Active window not found")
        M.close_ui()
        return
    end

    set_category_focus(window.index)
    M.set_current_buffer_line_focus(window.selected_line)

    if M.opts.window.hide_cursor then
        M.utils.hide_cursor()
    end
end

return M
