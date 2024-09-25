local utils = require('quick-kanban.utils')

--- Metadata module for the quick-kanban plugin
local M = {
    --- The path to the metadata file
    --- @type string
    path = "",

    --- Configuration options
    --- @type table
    opts = {},

    --- Logger instance
    --- @type table
    log = {}
}

--- The metadata JSON object
M.json = {
    --- The ID pool for the items
    --- @type number
    id_pool = 0,

    --- The categories for the items
    --- @type table
    categories = {},

    --- The default category for the items
    --- @type string
    default_category = ""
}

--- Setup the metadata module
--- @param opts table The configuration options for the metadata module
M.setup = function(opts, log)
    M.opts = opts
    M.log = log
    M.path = utils.concat_paths(M.opts.path, '.metadata.json')
    if utils.file_exists(M.path) then
        M.reload_from_file()
    else
        M.json.id = 0
        M.json.categories = M.opts.default_categories
        M.json.default_category = M.opts.default_categories[1]
    end
end

--- Get the next id from the item id pool and increment the id counter in the metadata file.
--- @return number id_pool Next item id
M.next_id = function()
    M.json.id_pool = M.json.id_pool + 1
    M.save_to_file()
    return M.json.id_pool
end

--- Get the index of a category in the categories list.
--- @param category string The category to get the index of.
--- @return number? The index of the category in the categories list or `nil` if not found.
M.get_category_index = function(category)
    for i, v in ipairs(M.json.categories) do
        if v == category then
            return i
        end
    end
    return nil
end

--- Get the categories list.
--- @return table categories The categories list
M.get_categories = function()
    return M.json.categories
end

--- Get the category at the given index.
--- @param index number The index of the category to get.
--- @return string The category at the given index or the default category if the index is out of bounds.
M.get_category = function(index)
    return M.json.categories[index] or M.json.default_category
end

--- Reload the metadata from the file
M.reload_from_file = function()
    local ok, json = pcall(vim.fn.json_decode, utils.read_file_contents(M.path))
    if ok and json ~= nil then
        M.json = json
    else
        M.log.error('Failed to decode JSON file: ' .. M.path)
    end
end

--- Save the metadata to the file
M.save_to_file = function()
    if not utils.write_to_file(M.path, vim.fn.json_encode(M.json)) then
        M.log.error('Failed to save metadata to file: ' .. M.path)
    end
end

return M
