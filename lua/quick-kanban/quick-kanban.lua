local utils = require('quick-kanban.utils')
local data = require('quick-kanban.data')

local M = {}
local _state = {
    is_open = false,
    winids = {},
    bufnrs = {},
    sel_window = nil,
    sel_index = {},
}

local _opts = {
    path = utils.get_working_directory_path() .. '/quick-kanban',
    windows = {
        'Backlog',
        'In Progress',
        'Done',
    },
    keymaps = {
        close = 'q',
        next_window = 'l',
        prev_window = 'h',
        next_item = 'j',
        prev_item = 'k',
    },
}

M.setup = function(opts)
    if opts ~= nil then
        _opts = vim.tbl_extend('force', _opts, opts or {})
    end
end

M.directories_exist = function()
    if not utils.directory_exists(_opts.path) then
        return false
    end
    for _, win in ipairs(_opts.windows) do
        if not utils.directory_exists(_opts.path .. '/' .. win) then
            return false
        end
    end
    return true
end

M.create_directories = function()
    utils.touch_directory(_opts.path)
    for _, win in ipairs(_opts.windows) do
        utils.touch_directory(_opts.path .. '/' .. win)
    end
end

M.get_directories = function()
    local dirs = {}
    for _, win in ipairs(_opts.windows) do
        table.insert(dirs, { win_key = win, path = _opts.path .. '/' .. win })
    end
    return dirs
end

M.get_path_for_win_key = function(win_key)
    for _, win in ipairs(_opts.windows) do
        if win == win_key then
            return _opts.path .. '/' .. win
        end
    end
    return nil
end

M.configure_buf_keymaps = function(bufnr)
    local opts = { noremap = true, silent = true }
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.close, ':lua require("quick-kanban").close_ui()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.next_window, ':lua require("quick-kanban").next_window()<CR>',
        opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.prev_window, ':lua require("quick-kanban").prev_window()<CR>',
        opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.next_item, ':lua require("quick-kanban").next_item()<CR>', opts)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.prev_item, ':lua require("quick-kanban").prev_item()<CR>', opts)
end

M.is_open = function()
    return _state.is_open
end

local find_window_key = function(wid)
    for key, value in pairs(_state.winids) do
        if value == wid then
            return key
        end
    end
    utils.log.error('Failed to get the window key for window id: ' .. wid)
    return nil
end

local find_window_index = function(key)
    for index, value in ipairs(_opts.windows) do
        if value == key then
            return index
        end
    end
    utils.log.error('Failed to get the window index for key: ' .. key)
    return -1
end

local get_current_window_index = function()
    local cur_key = find_window_key(vim.api.nvim_get_current_win())
    if cur_key == nil then
        utils.log.error('Failed to get the window key for current window')
        return -1
    end

    local cur_index = find_window_index(cur_key)
    if cur_index == -1 then
        utils.log.error('Failed to get the window index for window key: ' .. cur_key)
        return -1
    end
    return cur_index
end

local monitor_buf_close = function(bufnr)
    vim.api.nvim_buf_attach(bufnr, false, {
        -- Attach `on_lines` listener, which triggers every time a line is changed
        on_detach = function()
            --M.close_ui()
            utils.log.info('Buffer closed')
        end
    })
end

M.open_ui = function()
    M.close_ui()

    for index, key in ipairs(_opts.windows) do
        _state.bufnrs[key] = vim.api.nvim_create_buf(false, true)
        local gap = 2
        local ui = vim.api.nvim_list_uis()[1]
        local max_width = ui.width * 0.8
        local size = {
            width = vim.fn.min({ 40, vim.fn.round(max_width / #_opts.windows) }),
            height = vim.fn.max({ 20, vim.fn.round(ui.height * 0.8) })
        }
        local pos = {
            col = vim.fn.round(ui.width / 2 - (size.width * #_opts.windows / 2) + (index - 1) * (size.width + gap)),
            row = (ui.height - size.height) / 2
        }

        _state.winids[key], _state.bufnrs[key] = utils.open_popup_window(key, size, pos)

        local items = data.get_items_for_window(key)

        vim.api.nvim_buf_set_lines(_state.bufnrs[key], 0, -1, false, items)

        vim.api.nvim_buf_set_option(_state.bufnrs[key], 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(_state.bufnrs[key], 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(_state.bufnrs[key], 'modifiable', false)
        vim.api.nvim_win_set_option(_state.winids[key], 'wrap', true)
        vim.api.nvim_win_set_option(_state.winids[key], 'number', false)
        -- Hide cursor
        vim.api.nvim_win_set_option(_state.winids[key], 'cursorline', true)
        vim.api.nvim_win_set_option(_state.winids[key], 'cursorlineopt', 'line')
        M.configure_buf_keymaps(_state.bufnrs[key])

        monitor_buf_close(_state.bufnrs[key])

        -- If no window is selected, select the first window
        if _state.sel_window == nil then
            _state.sel_window = key
            _state.sel_index[key] = 1
        end
    end

    M.set_window_focus(find_window_index(_state.sel_window))
    _state.is_open = true
end

M.close_ui = function()
    for _, key in ipairs(_opts.windows) do
        if _state.winids[key] ~= nil and vim.api.nvim_win_is_valid(_state.winids[key]) then
            vim.api.nvim_win_close(_state.winids[key], true)
        end
        _state.winids[key] = nil

        if _state.bufnrs[key] ~= nil and vim.api.nvim_buf_is_valid(_state.bufnrs[key]) then
            vim.api.nvim_buf_delete(_state.bufnrs[key], { force = true })
        end
        _state.bufnrs[key] = nil
    end

    _state.is_open = false
end

M.set_window_focus = function(index)
    index = vim.fn.max({ 1, vim.fn.min({ #_opts.windows, index }) })
    local win_key = _opts.windows[index]
    local wid = _state.winids[win_key]
    if wid == nil then
        utils.log.error('Failed to get the window for index: ' .. index)
        return
    end
    vim.api.nvim_set_current_win(wid)
    _state.sel_window = win_key
    if _state.sel_index[win_key] == nil then
        _state.sel_index[win_key] = q
    end
    M.set_item_focus(_state.sel_index[win_key])
end

M.next_window = function()
    local cur_index = get_current_window_index()
    if cur_index > 0 then
        M.set_window_focus(cur_index + 1)
    end
end

M.prev_window = function()
    local cur_index = get_current_window_index()
    if cur_index > 0 then
        M.set_window_focus(cur_index - 1)
    end
end

M.switch_item_focus = function(idx_offset)
    local cur_line = vim.fn.line('.')
    if cur_line == 0 then
        utils.log.error('Failed to get the current line')
        return
    end
    M.set_item_focus(cur_line + idx_offset)
end

M.set_item_focus = function(idx)
    -- Clear all highlights
    for _, key in ipairs(_opts.windows) do
        local bufnr = _state.bufnrs[key]
        if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
        end
    end

    local cur_win = vim.api.nvim_get_current_win()
    local cur_buf = vim.api.nvim_win_get_buf(cur_win)

    local line_num = vim.fn.max({ 1, vim.fn.min({ vim.fn.line('$'), idx }) })
    -- vim.api.nvim_buf_add_highlight(cur_buf, -1, 'Normal', cur_line - 1, 0, -1)
    -- vim.api.nvim_buf_add_highlight(cur_buf, -1, 'Visual', next_line - 1, 0, -1)
    -- Move cursor
    vim.api.nvim_win_set_cursor(cur_win, { line_num, 0 })
    _state.sel_index[_state.sel_window] = line_num
end

M.next_item = function()
    M.switch_item_focus(1)
end

M.prev_item = function()
    M.switch_item_focus(-1)
end

return M
