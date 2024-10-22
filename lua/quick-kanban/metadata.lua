--- @class quick-kanban.metadata
local M = {
    --- The path to the metadata file
    --- @type string
    path = "",

    --- Configuration options
    --- @type table
    opts = {},

    --- Logger instance
    --- @type table
    log = {},

    --- Common utilities
    --- @type quick-kanban.utils
    utils = {}
}

--- The metadata JSON object
--- @class quick-kanban.metadata.json
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

--- Initialize the metadata module
--- @param opts quick-kanban.config.options The configuration options for the metadata module
M.init = function(opts, log)
    M.opts = opts
    M.log = log
    M.utils = require('quick-kanban.utils')
    M.path = M.utils.concat_paths(M.opts.path, '.metadata.json')
    if M.utils.file_exists(M.path) then
        M.reload_from_file()
        M.log.debug('Metadata loaded from file: ' .. M.path)
    else
        M.json.id = 0
        M.json.categories = M.opts.default_categories
        M.json.default_category = M.opts.default_categories[1]
        M.save_to_file()
        M.log.debug('Metadata initialized with default values')
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
    local ok, json = pcall(vim.fn.json_decode, M.utils.read_file_contents(M.path))
    if ok and json ~= nil then
        M.json = json
    else
        M.log.error('Failed to decode JSON file: ' .. M.path)
    end
end

--- Save the metadata to the file
M.save_to_file = function()
    if not M.utils.write_to_file(M.path, vim.fn.json_encode(M.json)) then
        M.log.error('Failed to save metadata to file: ' .. M.path)
    end
end

--- Add a new category to the categories list.
--- @param category string The category to add.
--- @return boolean Whether the category was added or not.
M.add_category = function(category)
    if M.get_category_index(category) == nil then
        table.insert(M.json.categories, category)
        M.save_to_file()
        return true
    end
    return false
end

--- Rename a category in the categories list.
--- @param old_category string The category to rename.
--- @param new_category string The new name for the category.
--- @return boolean Whether the category was renamed or not.
M.rename_category = function(old_category, new_category)
    local index = M.get_category_index(old_category)
    if index ~= nil then
        M.json.categories[index] = new_category
        M.save_to_file()
        return true
    end
    return false
end

--- Delete a category from the categories list.
--- @param category string The category to delete.
--- @return boolean Whether the category was deleted or not.
M.delete_category = function(category)
    local index = M.get_category_index(category)
    if index ~= nil then
        table.remove(M.json.categories, index)
        M.save_to_file()
        return true
    end
    return false
end

return M
