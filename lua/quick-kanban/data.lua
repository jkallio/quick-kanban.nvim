local M = {}
local utils = require('quick-kanban.utils')
local _items = {}

M.get_items_for_window = function(win_key)
    return _items[win_key] or {}
end

local read_items_from_directory = function(key, dir)
    local items = {}
    if utils.directory_exists(dir) then
        local files = vim.fn.readdir(dir)
        for _, file in ipairs(files) do
            table.insert(items, file)

            -- local path = folder .. '/' .. file
            -- local lines = utils.read_file_contents(path)
            -- if lines ~= nil then
            --     table.insert(items, { path = path, lines = lines })
            -- end
        end
    end
    return items
end

M.reload = function(directories)
    _items = {}
    for _, e in ipairs(directories) do
        local items = read_items_from_directory(e.win_key, e.path)
        _items[e.win_key] = items
    end
end
return M;
