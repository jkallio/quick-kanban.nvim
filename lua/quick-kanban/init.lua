local mkb = require('quick-kanban.quick-kanban')

local M = {}

M.setup = function(opts)
    mkb.setup(opts)
end

M.open_ui = function()
    if not mkb.directories_exist() then
        local create = vim.fn.confirm('Create Kanban directories?', '&Yes\n&No', 2) == 1
        if create then
            mkb.create_directories()
        else
            return
        end
    end
    mkb.open_ui()
    mkb.set_window_focus(1)
end

M.close_ui = function()
    mkb.close_ui()
end

M.toggle_ui = function()
    if mkb.is_open() then
        M.close_ui()
    else
        M.open_ui()
    end
end

M.next_window = function()
    mkb.next_window()
end

M.prev_window = function()
    mkb.prev_window()
end

M.next_item = function()
    mkb.switch_item_focus(1)
end

M.prev_item = function()
    mkb.switch_item_focus(-1)
end

return M
