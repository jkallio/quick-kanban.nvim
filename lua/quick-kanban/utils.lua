--- @class quick-kanban.utils
local M = {}

--- Returns the path for the current working directory
M.get_working_directory_path = function()
    return vim.fn.getcwd()
end

--- Concatenate the given paths
--- @param ... string The paths to concatenate
M.concat_paths = function(...)
    local full_path = table.concat({ ... }, '/')
    return vim.fn.resolve(full_path)
end

--- Check if directory exists
--- @param path string The path to the directory
M.directory_exists = function(path)
    return vim.fn.isdirectory(path) == 1
end

--- Check if file exists
--- @param path string The path to the file
M.file_exists = function(path)
    return vim.fn.filereadable(path) == 1
end

--- Creates a file in the given path if it doesn't exist
--- @param path string The path to the file
--- @return boolean True if the file was created successfully, false otherwise
M.touch_file = function(path)
    if M.file_exists(path) then
        return false
    end

    local file = io.open(path, 'w')
    if not file then
        return false
    end

    file:close()
    return true
end

--- Move a file from one directory to another
--- @param source string The source path of the file
--- @param destination string The destination path of the file
--- @return boolean True if the file was moved successfully, false otherwise
M.move_file = function(source, destination)
    if not M.file_exists(source) then
        return false
    end
    M.touch_directory(vim.fn.fnamemodify(destination, ':h'))
    return vim.fn.rename(source, destination) == 0
end

--- Create a directory in the given path if it doesn't exist
--- @param path string The path to the directory
--- @return boolean True if the directory was created successfully, false otherwise
M.touch_directory = function(path)
    if M.directory_exists(path) then
        return true
    end
    return vim.fn.mkdir(path, 'p') ~= 0
end

--- Read file contents into a table
--- @param path string The path to the file
--- @return string[] The contents of the file
M.read_file_contents = function(path)
    if path == nil then
        return {}
    end

    local file = io.open(path, 'r')
    if file == nil then
        return {}
    end

    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    return lines
end

--- Write given string to a file
--- @param path string The path to the file
--- @param content string The content to write to the file
--- @return boolean True if the file was written successfully, false otherwise
M.write_to_file = function(path, content)
    if path == nil then
        return false
    end

    local file = io.open(path, 'w')
    if not file then
        return false
    end

    file:write(content)
    file:close()
    return true
end

--- Delete the given file
--- @param path string The path to the file
--- @return boolean True if the file was deleted successfully, false otherwise
M.delete_file = function(path)
    if path == nil then
        return false
    end
    return vim.fn.delete(path) == 0
end

--- Append file with the given rows
--- @param path string The path to the file
--- @param lines string[] The rows to append to the file
--- @return boolean True if the file was appended successfully, false otherwise
M.append_file = function(path, lines)
    if path == nil then
        return false
    end

    local file = io.open(path, 'a')
    if not file then
        return false
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
    return true
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
        title = title,
        title_pos = 'center',
    })
    return wid, bufnr
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

--- Pad string to the right with spaces to the given length
--- @param str string The string to pad
--- @param len number The length to pad the string to
--- @param char string? The character to pad the string with
M.right_pad = function(str, len, char)
    char = char or ' '
    if #str <= len then
        return str .. string.rep(char, len - #str)
    else
        return str
    end
end

-- Pad string to the left with spaces to the given length
-- @param str string The string to pad
-- @param len number The length to pad the string to
M.left_pad = function(str, len)
    if #str <= len then
        return string.rep(" ", len - #str) .. str
    else
        return str
    end
end

--- Trim whitespace from the beginning of the given string
--- @param str string The string to trim
M.trim_left = function(str)
    return string.match(str, "^%s*(.-)$")
end

--- Trim whitespace from the beginning and end of the given string
--- @param str string The string to trim
--- @return string The trimmed string
M.trim = function(str)
    return str:match("^%s*(.-)%s*$") or ""
end

--- Configure the keymaps for the given buffer. The keymaps can be either...
--- - A single keymap string (e.g. '<leader>q')
--- - A table of keymaps (e.g. { keys = {'<esc>', '<leader>q'}, desc = 'Quit' })
--- @param bufnr number The buffer number
--- @param keymap string|table The keymaps to configure
--- @param cmd string The command to execute
--- @return boolean success `true` if successfully mapped the key
M.set_keymap = function(bufnr, keymap, cmd)
    if bufnr == nil or cmd == nil or keymap == nil then
        return false
    end

    if type(keymap) == "string" then
        vim.api.nvim_buf_set_keymap(bufnr, 'n', keymap, cmd, { noremap = true, silent = true })
    elseif type(keymap) == "table" then
        for _, k in ipairs(keymap) do
            if type(k) == "string" then
                M.set_keymap(bufnr, k, cmd)
            end
        end
    else
        -- Invalid type
        return false
    end
    return true
end

return M
