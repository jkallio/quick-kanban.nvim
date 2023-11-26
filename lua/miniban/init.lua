local miniban = require('miniban.miniban')
local M = {}

M.setup = function(opts)
    miniban.setup(opts)
end

M.open_ui = function()
    miniban.open_ui()
end

M.close_ui = function()
    miniban.close_ui()
end

M.toggle_ui = function()
    if miniban.is_open() then
        M.close_ui()
    else
        M.open_ui()
    end
end

M.next_window = function()
    miniban.switch_window_focus(1)
end

M.prev_window = function()
    miniban.switch_window_focus(-1)
end

return M
