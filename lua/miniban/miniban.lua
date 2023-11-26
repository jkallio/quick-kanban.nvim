local utils = require('miniban.utils')

local M = {}
local _state = {
    is_open = false,
    winids = {},
    bufnrs = {},
}

local _opts = {
    path = utils.get_working_directory_path() .. '/miniban',
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

    utils.touch_directory(_opts.path)
    for _, win in ipairs(_opts.windows) do
        utils.touch_directory(_opts.path .. '/' .. win)
    end
end

M.configure_buf_keymaps = function(bufnr)
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.close, ':lua require("miniban").close_ui()<CR>', {
        noremap = true,
        silent = true
    })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.next_window, ':lua require("miniban").next_window()<CR>', {
        noremap = true,
        silent = true
    })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.prev_window, ':lua require("miniban").prev_window()<CR>', {
        noremap = true,
        silent = true
    })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.next_item, ':lua require("miniban").next_item()<CR>', {
        noremap = true,
        silent = true
    })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', _opts.keymaps.prev_item, ':lua require("miniban").prev_item()<CR>', {
        noremap = true,
        silent = true
    })
end

M.is_open = function()
    return _state.is_open
end

M.findWindowKey = function(wid)
    for key, value in pairs(_state.winids) do
        if value == wid then
            return key
        end
    end
    return nil
end

M.findWindowIndex = function(key)
    for index, value in ipairs(_opts.windows) do
        if value == key then
            return index
        end
    end
    return -1
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

        vim.api.nvim_buf_set_lines(_state.bufnrs[key], 0, -1, false,
            { 'TODO', 'Read', 'Contents', 'Of', 'Directory', key })

        vim.api.nvim_buf_set_option(_state.bufnrs[key], 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(_state.bufnrs[key], 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(_state.bufnrs[key], 'modifiable', false)
        vim.api.nvim_win_set_option(_state.winids[key], 'wrap', true)
        vim.api.nvim_win_set_option(_state.winids[key], 'number', false)
        M.configure_buf_keymaps(_state.bufnrs[key])
    end

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

M.switch_window_focus = function(idx_offset)
    local cur_key = M.findWindowKey(vim.api.nvim_get_current_win())
    if cur_key == nil then
        utils.log.error('Failed to get the window key for current window')
        return
    end

    local cur_index = M.findWindowIndex(cur_key)
    if cur_index == -1 then
        utils.log.error('Failed to get the window index for window key: ' .. cur_key)
        return
    end

    local next_index = vim.fn.max({ 1, vim.fn.min({ #_opts.windows, (cur_index + idx_offset) }) })
    local next_key = _opts.windows[next_index]
    local next_win = _state.winids[next_key]
    if next_win == nil then
        utils.log.error('Failed to get the window for index: ' .. next_index)
        return
    end
    vim.api.nvim_set_current_win(next_win)
end

return M
