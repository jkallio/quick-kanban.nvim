local qkb = require('quick-kanban.quick-kanban')
local data = require('quick-kanban.data')

local M = {}

M.setup = function(opts)
    qkb.setup(opts)
end

M.open_ui = function()
    if not qkb.directories_exist() then
        local create = vim.fn.confirm('Create Kanban directories?', '&Yes\n&No', 2) == 1
        if create then
            qkb.create_directories()
        else
            return
        end
    end
    data.reload(qkb.get_directories())
    qkb.open_ui()
    qkb.set_window_focus(1)
end

M.close_ui = function()
    qkb.close_ui()
end

M.toggle_ui = function()
    if qkb.is_open() then
        M.close_ui()
    else
        M.open_ui()
    end
end

M.next_window = function()
    qkb.next_window()
end

M.prev_window = function()
    qkb.prev_window()
end

M.next_item = function()
    qkb.switch_item_focus(1)
end

M.prev_item = function()
    qkb.switch_item_focus(-1)
end

return M
