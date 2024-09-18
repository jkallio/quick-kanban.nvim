local utils = require('quick-kanban.utils')
local data = require('quick-kanban.data')
local WIN_HILIGHT_INACTIVE = 100
local WIN_HILIGHT_ACTIVE = 101
local WIN_HILIGHT_ITEM_SELECTED = 102
local PREVIEW_KEY = "preview"
local ARCHIVE_KEY = "archive"
local KANBAN_KEY = "kanban"

--- Public interface
--- @type table
local M = {
    -- Options for the plugin
    opts = {},

    state = {
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
        --- @type table where the key is the name of the category from opts.categories
        windows = {}
    }
}

-------------------------------------------------------------------------------
--- Autocommands
-------------------------------------------------------------------------------

--- Autogroup which monitors entering a window and quits if it's not Kanban
vim.api.nvim_create_autocmd('WinEnter', {
    group = vim.api.nvim_create_augroup('MonitorWindowEnter', { clear = true }),
    callback = function()
        if M.get_current_win_id() == nil and M.state.is_open then
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
    if not utils.directory_exists(path) then
        if vim.fn.confirm(
                'Kanban directory does not exist for this project.\r\nCreate Kanban directory?\r\n' .. path .. '?',
                '&Yes\n&No', 2) ~= 1 then
            return false
        end

        utils.touch_directory(path)
        utils.touch_directory(utils.concat_paths(path, M.opts.subdirectories.items))
        utils.touch_directory(utils.concat_paths(path, M.opts.subdirectories.archive))
        utils.touch_directory(utils.concat_paths(path, M.opts.subdirectories.attachments))
        data.reload_kanban_meta_file()
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
    if category == nil then
        utils.log.error("Invalid argument: category=nil")
        return
    end

    local items = category == ARCHIVE_KEY and data.get_archived_items() or data.get_items_for_category_sorted(category)
    local buf_lines = {}
    for _, item in ipairs(items) do
        table.insert(buf_lines, " [" .. item.id .. "] " .. item.title)
    end

    local bufnr = M.state.windows[category].bufnr
    if bufnr == nil then
        return
    end

    vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, buf_lines)
    hilight_item_ids_in_buffer(bufnr)
    vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
end

--- Get the category for the given index
--- @param index number The index of a table
--- @return string? category The category for the given index (or `nil` if not found)
M.get_category = function(index)
    for i, category in ipairs(M.opts.categories) do
        if i == index then
            return category
        end
    end
    utils.log.error("Failed to get category for index: " .. index)
    return nil
end

--- Get the table index for the given window id
--- @param wid number The window id
--- @return number? index The table index for the given window id (or `nil` if not found)
M.get_win_index = function(wid)
    for _, win in pairs(M.state.windows) do
        if win.id == wid then
            return win.index
        end
    end
    return nil
end

--- Get the currently active window id
--- @return number? wid The current window id (or `nil` if Kanban window is not active)
M.get_current_win_id = function()
    local wid = vim.api.nvim_get_current_win()
    for _, win in pairs(M.state.windows) do
        if win.id == wid then
            return wid
        end
    end
    return nil
end

--- Get the currently active buffer number
--- @return number? bufnr The current buffer number (or `nil` if not found)
M.get_current_bufnr = function()
    local wid = M.get_current_win_id()
    if wid ~= nil then
        return vim.api.nvim_win_get_buf(wid)
    end
    return nil
end

--- Get the ID from the item currenlty under the cursor
--- @return number? item_id The ID of the item under the cursor (or `nil` if not found)
M.get_item_id_under_cursor = function()
    local wid = M.get_current_win_id()
    if wid == nil then
        utils.log.error("Failed to get item; Active window not found")
        return nil
    end

    local line_num = vim.fn.line('.', wid)
    if line_num == 0 then
        utils.log.error("Failed to get item; Active line not found")
        return nil
    end

    local item_id = string.match(vim.fn.getline(line_num), "%[(.*)%]")
    if item_id ~= nil then
        return tonumber(item_id)
    end

    return nil
end

--- Set the focus to the category at the given index
--- @param index number The index of the category to focus
M.set_category_focus = function(index)
    local cur_category = M.state.selected_category
    local new_category = nil

    if index > #M.opts.categories and M.opts.show_archive then
        if M.state.selected_item_id ~= nil then
            M.archive_selected_item()
            M.toggle_selected_item()
            return
        end
        new_category = ARCHIVE_KEY
    elseif M.state.selected_category == ARCHIVE_KEY then
        new_category = M.opts.categories[#M.opts.categories]
    else
        index = vim.fn.max({ 1, vim.fn.min({ #M.opts.categories, index }) })
        new_category = M.get_category(index)
    end

    if cur_category == nil or new_category == nil then
        utils.log.error("Invalid argument(s): "
            .. "cur_category=" .. (cur_cateogry or "nil") .. "; "
            .. "new_cateogory=" .. (new_category or "nil"))
        return
    end

    local cur_wid = M.state.windows[cur_category].id
    local new_wid = M.state.windows[new_category].id
    if new_wid == nil or cur_wid == nil then
        utils.log.error("Unexpected error: "
            .. "cur_wid=" .. (cur_wid or "nil") .. "; "
            .. "new_wid=" .. (new_wid or "nil"))
        return
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
        and data.move_item_to_category(M.state.selected_item_id, M.state.selected_category)
    then
        reload_buffer_for_category(cur_category)
        reload_buffer_for_category(new_category)
        M.set_item_focus(1)
    else
        M.set_item_focus(M.state.windows[new_category].selected_line or 1)
    end
end

--- Set the focus to the item at the given index
--- @param new_idx number The index of the item to focus
M.set_item_focus = function(new_idx)
    -- Ensure the line is within the bounds
    local cur_idx = vim.fn.line('.')
    new_idx = vim.fn.max({ 1, vim.fn.min({ vim.fn.line('$'), new_idx }) })

    -- If item is currently selected, move it to new index
    if M.state.selected_item_id ~= nil
        and cur_idx ~= new_idx
        and data.move_item_within_category(M.state.selected_item_id, new_idx - cur_idx) then
        reload_buffer_for_category(M.state.selected_category)
    end

    -- Update the cursor position in buffer
    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { new_idx, 99 })
    M.state.windows[M.state.selected_category].selected_line = new_idx
end

--- Hide the cursor (...and save the original settings)
M.hide_cursor = function()
    vim.g.saved_cursor_blend = vim.api.nvim_get_hl(0, { name = "Cursor" }).blend
    vim.g.saved_guicursor = vim.o.guicursor
    vim.cmd([[hi Cursor blend=100]])
    vim.cmd([[set guicursor+=a:Cursor/lCursor]])
end

--- Show the cursor (...by restoring the original settings)
M.show_cursor = function()
    if vim.g.saved_cursor_blend ~= nil then
        vim.cmd([[hi Cursor blend=vim.g.saved_cursor_blend]])
    end
    if vim.g.saved_guicursor ~= nil then
        vim.o.guicursor = vim.g.saved_guicursor
    end
end

local get_help_text = function()
    local function right_pad(str, len)
        if #str <= len then
            return str .. string.rep(" ", len - #str)
        else
            return str
        end
    end

    local rows = vim.fn.floor(M.opts.window.height / 2) - 3
    local items = {
        "   Quit            " .. M.opts.keymaps.quit,
        "   Next Category   " .. M.opts.keymaps.next_category,
        "   Prev Category   " .. M.opts.keymaps.prev_category,
        "   Next Item       " .. M.opts.keymaps.next_item,
        "   Prev Item       " .. M.opts.keymaps.prev_item,
        "   Select Item     " .. M.opts.keymaps.select_item,
        "   Open Attachment " .. M.opts.keymaps.open_item,
        "   Rename Item     " .. M.opts.keymaps.rename,
        "   Add Item        " .. M.opts.keymaps.add_item,
        "   Edit Item       " .. M.opts.keymaps.edit_item,
        "   Archive Item    " .. M.opts.keymaps.archive_item,
        "   Delete Item     " .. M.opts.keymaps.delete,
        "   Toggle Archive  " .. M.opts.keymaps.toggle_archive,
        "   Toggle Preview  " .. M.opts.keymaps.toggle_preview,
        "   Show Help       " .. M.opts.keymaps.show_help,
    }

    local lines = {}
    for i, item in ipairs(items) do
        local row = ((i - 1) % rows) + 1
        local line = lines[row] or ""
        line = line .. right_pad(item, rows > 10 and 35 or 30)
        lines[row] = line
    end
    return lines
end

-------------------------------------------------------------------------------
--- Public Module functions
-------------------------------------------------------------------------------

--- Setup the plugin with the given options
--- @param opts table The options to configure the plugin
M.setup = function(opts)
    M.opts = opts
    data.setup(opts)

    M.state.selected_view = KANBAN_KEY
    M.state.selected_category = M.opts.default_category
    for i, category in ipairs(M.opts.categories) do
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
    --vim.api.nvim_set_hl(WIN_HILIGHT_ACTIVE, "LineNr", { bg = "None", fg = M.opts.window.accent_color })
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
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "FloatBorder", { bg = "None", fg = M.opts.window.hilight_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "FloatTitle", { bg = "None", fg = M.opts.window.hilight_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "FloatFooter", { bg = "None", fg = M.opts.window.hilight_color })
    vim.api.nvim_set_hl(WIN_HILIGHT_ITEM_SELECTED, "PrefixHilight", { bg = "None", fg = "#888888" })
end

--- Move focus to the next category
M.next_category = function()
    if M.state.selected_category == ARCHIVE_KEY then
        return
    end

    for i, category in ipairs(M.opts.categories) do
        if category == M.state.selected_category then
            M.set_category_focus(i + 1)
            M.update_preview()
            return
        end
    end
end

--- Move focus to the previous category
M.prev_category = function()
    if M.state.selected_category == ARCHIVE_KEY then
        M.set_category_focus(#M.opts.categories)
        M.update_preview()
    else
        for i, category in ipairs(M.opts.categories) do
            if category == M.state.selected_category then
                M.set_category_focus(i - 1)
                M.update_preview()
                return
            end
        end
    end
end

--- Move item focus to the next item
M.next_item = function()
    local curline = vim.fn.line('.')
    M.set_item_focus(curline + 1)
    M.update_preview()
end

--- Move item focus to the previous ite
M.prev_item = function()
    local curline = vim.fn.line('.')
    M.set_item_focus(curline - 1)
    M.update_preview()
end

--- Open the kanban board UI
M.open_ui = function()
    if not utils.directory_exists(M.opts.path) then
        if not create_kanban_directories(M.opts.path) then
            return
        end
    end

    --- Local helper function for setting buffer options for a category window
    local function set_buffer_options(bufnr)
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
        vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
        vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
    end

    --- Local helper function for setting window options for a category window
    local function set_window_options(wid, opts)
        vim.api.nvim_set_option_value('relativenumber', false, { win = wid })
        vim.api.nvim_set_option_value('cursorline', true, { win = wid })
        vim.api.nvim_set_option_value('cursorlineopt', 'both', { win = wid })
        vim.api.nvim_set_option_value('number', opts.number, { win = wid })
        vim.api.nvim_set_option_value('winblend', opts.window.blend, { win = wid })
        vim.api.nvim_set_option_value('wrap', opts.wrap, { win = wid })
        vim.api.nvim_set_option_value('linebreak', opts.wrap, { win = wid })
        vim.api.nvim_win_set_hl_ns(wid, WIN_HILIGHT_INACTIVE)
    end

    -- Local helper function for configuring the keymaps for a buffer
    local function set_keymap(buf, key, cmd)
        if key ~= nil and cmd ~= nil then
            vim.api.nvim_buf_set_keymap(buf, 'n', key, cmd, { noremap = true, silent = true })
        end
    end

    --- Local helper function to disable default vim keys
    local function disable_default_keys(bufnr)
        local disabled_keys = { 'a', 'c', 'd', 'i', 'o', 'p', 'r', 'x', 'gg', 'G', '<esc>', '<tab>', '<cr>', '<bs>',
            '<del>' }
        for _, key in ipairs(disabled_keys) do
            set_keymap(bufnr, string.lower(key), '<nop>')
            set_keymap(bufnr, string.upper(key), '<nop>')
        end
    end

    --- Local helper function for setting keymaps for a buffer
    local function set_keymaps(bufnr, keymaps)
        set_keymap(bufnr, keymaps.show_help, ':lua require("quick-kanban").show_help_text()<cr>')
        set_keymap(bufnr, keymaps.archive_item, ':lua require("quick-kanban").archive_item()<cr>')
        set_keymap(bufnr, keymaps.toggle_archive, ':lua require("quick-kanban").toggle_archive_window()<cr>')
        set_keymap(bufnr, keymaps.toggle_preview, ':lua require("quick-kanban").toggle_preview_window()<cr>')
        set_keymap(bufnr, keymaps.add_item, ':lua require("quick-kanban").add_item()<cr>')
        set_keymap(bufnr, keymaps.delete, ':lua require("quick-kanban").delete_item()<cr>')
        set_keymap(bufnr, keymaps.quit, ':lua require("quick-kanban").close_ui()<cr>')
        set_keymap(bufnr, keymaps.next_category, ':lua require("quick-kanban").next_category()<cr>')
        set_keymap(bufnr, keymaps.prev_category, ':lua require("quick-kanban").prev_category()<cr>')
        set_keymap(bufnr, keymaps.next_item, ':lua require("quick-kanban").next_item()<cr>')
        set_keymap(bufnr, keymaps.prev_item, ':lua require("quick-kanban").prev_item()<cr>')
        set_keymap(bufnr, keymaps.open_item, ':lua require("quick-kanban").open_item()<cr>')
        set_keymap(bufnr, keymaps.select_item, ':lua require("quick-kanban").select_item()<cr>')
        set_keymap(bufnr, keymaps.rename, ':lua require("quick-kanban").rename_item()<cr>')
    end

    if M.opts.window.hide_cursor then
        M.hide_cursor()
    end

    -- Get the main UI (1st element in the ui list)
    local ui = vim.api.nvim_list_uis()[1]
    local win_width = vim.fn.min({ M.opts.window.width, vim.fn.floor(ui.width / #M.opts.categories) })
    local win_height = vim.fn.min({ M.opts.window.height - 2 * M.opts.window.vertical_gap, (ui.height - 3) -
    2 * M.opts.window.vertical_gap })
    local win_pos_left = vim.fn.floor(ui.width / 2 - (win_width * #M.opts.categories / 2)) -
        (M.opts.show_archive and (win_width / 2) or 0)
    if M.opts.show_preview then
        win_height = vim.fn.floor(win_height / 2)
    end

    -- Create a window for each category
    for i, category in ipairs(M.opts.categories) do
        local win_size = {
            width = win_width,
            height = win_height
        }
        local win_pos = {
            col = win_pos_left + (i - 1) * (win_width + M.opts.window.horizontal_gap),
            row = M.opts.window.vertical_gap
        }
        local wid, bufnr = utils.open_popup_window(
            (M.opts.window.title_decoration[1] .. category .. M.opts.window.title_decoration[2]), win_size, win_pos)

        M.state.windows[category].id = wid
        M.state.windows[category].bufnr = bufnr

        set_window_options(wid, M.opts)
        set_buffer_options(bufnr)
        disable_default_keys(bufnr)
        set_keymaps(bufnr, M.opts.keymaps)

        M.state.windows[category].selected_line = M.state.windows[category].selected_line or 1
        reload_buffer_for_category(category)
    end

    --- Create preview window
    if M.opts.show_preview then
        local wid, bufnr = utils.open_popup_window("",
            {
                width = vim.fn.round(#M.opts.categories * win_width) +
                    (#M.opts.categories - 1) * M.opts.window.horizontal_gap,
                height = win_height
            },
            {
                col = win_pos_left,
                row = win_height + 1 + M.opts.window.vertical_gap * 2
            })

        M.state.windows[PREVIEW_KEY] = {}
        M.state.windows[PREVIEW_KEY].id = wid
        M.state.windows[PREVIEW_KEY].bufnr = bufnr

        vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, get_help_text())

        -- Set the buffer options
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
        vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
        vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

        -- Set the window options
        vim.api.nvim_set_option_value('number', false, { win = wid })
        vim.api.nvim_set_option_value('winblend', M.opts.window.blend, { win = wid })
        vim.api.nvim_set_option_value('wrap', false, { win = wid })
        vim.api.nvim_set_option_value('linebreak', false, { win = wid })

        -- On default, set the hilight to inactive
        vim.api.nvim_win_set_hl_ns(wid, WIN_HILIGHT_ACTIVE)

        --- Disable default keys for the preview window
        disable_default_keys(bufnr)
    end

    --- Create the archive window
    if M.opts.show_archive then
        local wid, bufnr = utils.open_popup_window(
            (M.opts.window.title_decoration[1] .. "Archive" .. M.opts.window.title_decoration[2]),
            {
                width = win_width,
                height = win_height + (M.opts.show_preview and (win_height + M.opts.window.vertical_gap * 2) or 0)
            },
            {
                col = win_pos_left + (#M.opts.categories) * (win_width + M.opts.window.horizontal_gap),
                row = M.opts
                    .window.vertical_gap
            })

        M.state.windows[ARCHIVE_KEY] = {}
        M.state.windows[ARCHIVE_KEY].id = wid
        M.state.windows[ARCHIVE_KEY].bufnr = bufnr

        set_window_options(wid, M.opts)
        set_buffer_options(bufnr)
        disable_default_keys(bufnr)
        set_keymaps(bufnr, M.opts.keymaps)
        set_keymap(bufnr, M.opts.keymaps.archive_item, ':lua require("quick-kanban").unarchive_item()<cr>')
        set_keymap(bufnr, M.opts.keymaps.unarchive_item, ':lua require("quick-kanban").unarchive_item()<cr>')

        M.state.windows[ARCHIVE_KEY].selected_line = M.state.windows[ARCHIVE_KEY].selected_line or 1
        reload_buffer_for_category(ARCHIVE_KEY)
    end

    M.set_category_focus(M.state.windows[M.state.selected_category].index or 1)
    M.set_item_focus(M.state.windows[M.state.selected_category].selected_line or 1)
    M.update_preview()
    M.state.is_open = true
end

--- Close the Kanban board UI
M.close_ui = function()
    M.state.is_open = false
    M.state.selected_item_id = nil

    if M.opts.window.hide_cursor then
        M.show_cursor()
    end

    for key, win in pairs(M.state.windows) do
        if vim.api.nvim_win_is_valid(win.id or -1) then
            vim.api.nvim_win_close(win.id, true)
        end
        M.state.windows[key].id = nil

        if vim.api.nvim_buf_is_valid(win.bufnr or -1) then
            vim.api.nvim_buf_delete(win.bufnr, { force = true })
        end
        M.state.windows[key].bufnr = nil
    end
end

--- Select/Deselect the item under cursor
M.toggle_selected_item = function()
    if M.state.selected_category == ARCHIVE_KEY then
        return
    end

    local wid = M.get_current_win_id()
    if wid == nil then
        utils.log.error("Cannot select item; Active window not found")
        return
    end

    M.state.selected_item_id = M.state.selected_item_id == nil and M.get_item_id_under_cursor() or nil
    vim.api.nvim_win_set_hl_ns(wid,
        M.state.selected_item_id ~= nil and WIN_HILIGHT_ITEM_SELECTED or WIN_HILIGHT_ACTIVE)
end

--- Open the item under cursor
M.open_selected_item = function()
    local item = data.items[M.get_item_id_under_cursor() or -1]
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

    data.add_item(M.opts.default_category, input)
    reload_buffer_for_category(M.opts.default_category)
end

--- Rename the current item
M.rename_item = function()
    local item = data.items[M.get_item_id_under_cursor() or -1]
    if item == nil then
        return
    end

    local input = vim.fn.input({ prompt = 'New name for item [' .. item.id .. ']', default = item.title })
    if input ~= nil and #input > 0 then
        item.title = input
        data.save_item(item)
        reload_buffer_for_category(item.category)
    end
end

--- Archive the selected item
--- @return boolean `true` if the item was archived
M.archive_selected_item = function()
    local item = data.items[M.get_item_id_under_cursor() or -1]
    if item == nil then
        utils.log.error("Failed to archive item: item=nil")
        return false
    end

    local confirm = vim.fn.confirm('Archive item "[' .. item.id .. '] ' .. item.title .. '"?', '&Yes\n&No', 2) == 1
    if confirm then
        data.archive_item(item.id)
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
        utils.log.warn("Cannot unarchive item")
        return false
    end

    local item = data.unarchive_item(M.get_item_id_under_cursor() or -1)
    if item == nil then
        utils.log.error("Failed to unarchive item: item=nil")
        return false
    end

    reload_buffer_for_category(item.category)
    reload_buffer_for_category(ARCHIVE_KEY)
    return true
end

--- Delete selected item
--- @return boolean `true` if the item was deleted
M.delete_selected_item = function()
    local item_id = M.get_item_id_under_cursor() or -1
    local item = data.items[item_id] or data.get_archived_item(item_id)
    if item == nil then
        utils.log.error("Failed to delete item: item=nil")
        return false
    end

    local confirm = vim.fn.confirm(
        'Permanently DELETE item "[' .. item.id .. '] ' .. item.title .. '"? (This cannot be undone)',
        '&Yes\n&No', 2) == 1
    if confirm then
        data.delete_item(item.id)
        reload_buffer_for_category(M.state.selected_category)
        return true
    end
    return false
end

--- Update the preview window
M.update_preview = function()
    if not M.opts.show_preview then
        return
    end

    local item_id = M.get_item_id_under_cursor()
    if item_id ~= nil and M.state.preview_item_id == item_id then
        return
    end

    local item = M.state.selected_category == ARCHIVE_KEY and data.get_archived_item(item_id or -1) or
        data.items[item_id]
    if item == nil then
        M.show_help_text()
        return
    elseif item.attachment_path == nil or not utils.file_exists(item.attachment_path) then
        -- Create a new empty buffer
        vim.api.nvim_win_set_buf(M.state.windows[PREVIEW_KEY].id, vim.api.nvim_create_buf(false, true))
        return
    end

    vim.api.nvim_set_current_win(M.state.windows[PREVIEW_KEY].id)
    vim.cmd('edit! ' .. item.attachment_path)
    --local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_win(M.state.windows[M.state.selected_category].id)
end

--- Show the help text in the preview window
M.show_help_text = function()
    if not M.opts.show_preview then
        M.toggle_preview_window()
    end
    vim.api.nvim_win_set_buf(M.state.windows[PREVIEW_KEY].id, M.state.windows[PREVIEW_KEY].bufnr)
end

--- Toggle the visibility of the archive category
M.toggle_archive_window = function()
    M.opts.show_archive = not M.opts.show_archive
    if (M.opts.show_archive == false) and M.state.selected_category == ARCHIVE_KEY then
        M.state.selected_category = M.opts.default_category
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
--- TODO: Implement this function
M.edit_item = function()
    utils.log.error("Not implemented")
end

return M
