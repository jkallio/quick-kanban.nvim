local utils = require('quick-kanban.utils')

local M = {
    opts = {},
    items = {},
    dirty = {},
}

M.setup = function(opts)
    M.opts = opts
    M.reload_files()
end

--- Get the items for the specified category.
--- @param category string The name of the category
M.get_items_for_category = function(category)
    return M.items[category] or {}
end

--- Returns true if any of the categories have unsaved changes
--- @return boolean
M.has_unsaved_changes = function()
    for _, category in ipairs(M.opts.categories) do
        if M.dirty[category] then
            return true
        end
    end
    return false
end

--- Move an item from one category to another.
--- @param item_id number The id of the item to move
--- @param from_category string The category to move the item from
--- @param to_category string The category to move the item to
M.move_item_to_category = function(item_id, from_category, to_category)
    if item_id == nil then
        utils.log.error("Invalid argument: item_id=nil")
        return
    end

    for i, item in ipairs(M.items[from_category]) do
        if item.id == item_id then
            table.insert(M.items[to_category], 1, item)
            table.remove(M.items[from_category], i)
            M.dirty[from_category] = true
            M.dirty[to_category] = true
            return
        end
    end

    utils.log.error("Item not found: item_id=" .. item_id)
end

--- Search for an item in all categories.
M.search_item_from_all_categories = function(search_id)
    for _, category in ipairs(M.opts.categories) do
        local item = category[search_id]
        if item ~= nil then
            return item
        end
        utils.log.warn("Item not found: " .. search_id)
    end
    return nil
end

--- Reload the data items from the files in the configured path.
M.reload_files = function()
    if not utils.directory_exists(M.opts.path) then
        return
    end

    M.items = {}
    for _, category in ipairs(M.opts.categories) do
        M.items[category] = {}
        M.dirty[category] = false
    end

    local files = vim.fn.readdir(M.opts.meta_path)
    for _, file in ipairs(files) do
        local full_file_path = utils.concat_paths(M.opts.meta_path, file)
        if utils.file_exists(full_file_path) then
            local lines = utils.read_file_contents(full_file_path)
            local item = vim.fn.json_decode(lines)
            local category_items = nil
            for _, category in ipairs(M.opts.categories) do
                if string.lower(category) == string.lower(item.category) then
                    category_items = M.items[category]
                end
            end
            if category_items ~= nil then
                table.insert(category_items, item)
            end
        else
            utils.log.error("File not found: " .. full_file_path)
        end
    end
end

--- Save changes in to the kanban files
M.save_to_file = function()
    if not utils.directory_exists(M.opts.path) then
        debug("Kanban folder not found: Invalid configuration")
        return false
    end

    for _, category in ipairs(M.opts.categories) do
        if M.dirty[category] then
            for i, item in ipairs(M.items[category]) do
                item.order = i
                item.category = category
                local file_path = utils.concat_paths(M.opts.meta_path, item.id)
                utils.write_to_file(file_path, vim.fn.json_encode(item))
            end
        end
    end
end

--- Add a new item to the specified category.
--- @param category string The category to add the item to
--- @param title string The title of the item
M.add_item = function(category, title)
    local pos = 1
    if M.opts.new_item_position ~= "top" and M.items[category] ~= nil then
        pos = #M.items[category] + 1
    end

    local new_item = {
        id = os.time(),
        title = title,
        category = category,
        order = pos
    }
    print(pos .. " (" .. type(pos) .. ")")
    table.insert(M.items[category], pos, new_item)
    M.dirty[category] = true
end

--- Delete given item
--- @param item_id number The id of the item to delete
M.delete_item = function(item_id)
    for _, category in ipairs(M.opts.categories) do
        for i, item in ipairs(M.items[category]) do
            if item.id == item_id then
                table.remove(M.items[category], i)
                local file_path = utils.concat_paths(M.opts.meta_path, item.id)
                utils.delete_file(file_path)
                return
            end
        end
    end
    utils.log.error("Failed to delete. Item [" .. item_id .. "] not found!")
end

return M;
