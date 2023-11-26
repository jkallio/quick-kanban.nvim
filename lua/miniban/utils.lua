local logger = require('plenary.log')
local M = {}

--- Initialize the plenary logger
M.log = logger.new({
    plugin = 'miniban',
    level = 'info',
})

--- Returns the path for the current working directory
M.get_working_directory_path = function()
    return vim.fn.getcwd()
end

--- Creates a file in the given path if it doesn't exist
--- @param path string The path to the file
M.touch_file = function(path)
    local file = io.open(path, 'r')
    if file ~= nil then
        file:close()
        return
    end

    file = io.open(path, 'w')
    if file ~= nil then
        M.log.info('Created file: ' .. path)
        file:close()
        return
    end
    M.log.error('Failed to touch file: ' .. path)
end

--- Create a directory in the given path if it doesn't exist
--- @param path string The path to the directory
M.touch_directory = function(path)
    if vim.fn.isdirectory(path) == 1 then
        return
    end

    M.log.info('Creating directory: ' .. path)
    if vim.fn.mkdir(path, 'p') == 0 then
        M.log.error('Failed to create directory: ' .. path)
    end
end

--- Read file contents into a table
--- @param path string The path to the file
M.read_file_contents = function(path)
    if path == nil then
        M.log.error('Invalid path: ' .. path)
        return nil
    end

    local file = io.open(path, 'r')
    if file == nil then
        M.log.error('Failed to open file: ' .. path)
        return nil
    end

    local contents = {}
    for line in file:lines() do
        table.insert(contents, line)
    end
    file:close()
    return contents
end

--- Write the given contents to a file
--- @param path string The path to the file
--- @param lines string[] The contents to write to the file
M.write_file_contents = function(path, lines)
    if path == nil then
        M.log.error('Invalid path: ' .. path)
        return
    end

    local file = io.open(path, 'w')
    if file == nil then
        M.log.error('Failed to open file: ' .. path)
        return
    end

    for _, line in ipairs(lines) do
        if line ~= nil and #line > 0 then
            if line:sub(-1) == '\n' then
                file:write(line)
            else
                file:write(line .. '\n')
            end
        end
    end
    file:close()
end

--- Append file with the given rows
--- @param path string The path to the file
--- @param lines string[] The rows to append to the file
M.append_file = function(path, lines)
    if path == nil then
        M.log.error('Invalid path: ' .. path)
        return
    end

    local file = io.open(path, 'a')
    if file == nil then
        M.log.error('Failed to open file: ' .. path)
        return
    end

    for _, line in ipairs(lines) do
        if line ~= nil and #line > 0 then
            if line:sub(-1) == '\n' then
                file:write(line)
            else
                file:write(line .. '\n')
            end
        end
    end
    file:close()
end

--- Check if the given string starts with the given start string
M.starts_with = function(str, start)
    return str:sub(1, #start) == start
end

--- Open a popup window with the given contents
M.open_popup_window = function(title, size, pos)
    local bufnr = vim.api.nvim_create_buf(false, true)
    local wid = vim.api.nvim_open_win(bufnr, true, {
        relative = 'editor',
        width = size.width,
        height = size.height,
        row = pos.row,
        col = pos.col,
        style = 'minimal',
        border = 'rounded',
        title = '-=[ ' .. title .. ' ]=-',
        title_pos = 'center',
    })
    return wid, bufnr
end

return M
