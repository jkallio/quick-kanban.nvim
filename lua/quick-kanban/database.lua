--- This module handles loading and saving all the data from and into disk.
--- @class quick-kanban.database
local M = {
    --- Configuration options
    --- @type quick-kanban.config.options
    opts = {},

    --- Dictionary of items where the key is the item.id
    --- @type table Dictionary <number, table>
    items = {},

    --- The metadata for the kanban board
    --- @type quick-kanban.metadata
    metadata = {},

    --- Logger instance
    --- @type table
    log = {},

    --- @type quick-kanban.utils
    utils = {}
}

--- Initialize the data module with the specified options.
--- @param opts quick-kanban.config.options The configuration options
--- @param metadata quick-kanban.metadata The metadata for the kanban board
--- @param log table The logger object
M.init = function(opts, metadata, log)
    M.opts = opts
    M.log = log
    M.metadata = metadata
    M.utils = require('quick-kanban.utils')
    if M.utils.directory_exists(M.opts.path) then
        M.reload_item_files()
    end
end

--- Get the items for the specified category.
--- @param category string The name of the category
--- @return table The items for the specified category sorted by order
M.get_items_for_category_sorted = function(category)
    local items = {}
    for _, item in pairs(M.items) do
        if item.category == category then
            table.insert(items, item)
        end
    end

    table.sort(items, function(a, b)
        return a.order < b.order
    end)

    for i, item in ipairs(items) do
        item.order = i
    end

    return items
end

--- Get the archived items.
--- @return table items The archived items
M.get_archived_items = function()
    local items = {}
    local archive_path = M.utils.concat_paths(M.opts.path, M.opts.subdirectories.archive)
    if M.utils.directory_exists(archive_path) then
        local file_list = vim.fn.readdir(archive_path)
        for _, file_name in ipairs(file_list) do
            local file_path = M.utils.concat_paths(archive_path, file_name)
            if M.utils.file_exists(file_path) then
                local item = vim.fn.json_decode(M.utils.read_file_contents(file_path))
                table.insert(items, item)
            else
                M.log.error("File not found: " .. file_path)
            end
        end
    end
    return items
end

--- Get item by id (including archived items).
--- @param item_id number The id of the item to get
--- @return table? item The item or nil if the item was not found
M.get_item = function(item_id)
    local item = M.items[item_id]
    if item == nil then
        local items = M.get_archived_items()
        for _, archived_item in ipairs(items) do
            if archived_item.id == item_id then
                return archived_item
            end
        end
    end
    return item
end

--- Move an item from one category to another.
--- @param item_id number The id of the item to move
--- @param category string The category to move the item to
--- @return boolean true if the item was moved successfully, false otherwise
M.move_item_to_category = function(item_id, category)
    local item = M.items[item_id]
    if item == nil or category == nil then
        M.log.error("Invalid argument(s): "
            .. "item_id=" .. (item_id or "nil") .. "; "
            .. "category=" .. (category or "nil"))
        return false
    end

    if item.category == category then
        M.log.warn("Item [" .. item.id .. "] already in category " .. category)
        return false
    end

    item.category = category
    item.order = 0
    M.save_item(item)
    return true
end

--- Move an item to a new position in the same category.
--- @param item_id number The id of the item to move
--- @param increment number The number of positions to move the item
--- @return boolean true if the item was moved successfully, false otherwise
M.move_item_within_category = function(item_id, increment)
    local item = M.items[item_id]
    if item == nil then
        M.log.error("Invalid argument: item_id=" .. (item_id or "nil"))
        return false
    end

    local new_pos = item.order + increment
    local items = M.get_items_for_category_sorted(item.category)

    -- Increment/decrement the order of the items in the category
    for _, category_item in ipairs(items) do
        if increment < 0 and category_item.order >= new_pos and category_item.order < item.order then
            category_item.order = category_item.order + 1
            M.save_item(category_item)
        elseif increment > 0 and category_item.order <= new_pos and category_item.order > item.order then
            category_item.order = category_item.order - 1
            M.save_item(category_item)
        end
    end

    item.order = new_pos
    M.save_item(item)
    return true
end

--- Reload the data items from the files in the configured path.
--- @return boolean true if the items were reloaded successfully, false otherwise
M.reload_item_files = function()
    local items_path = M.utils.concat_paths(M.opts.path, M.opts.subdirectories.items)
    if not M.utils.directory_exists(items_path) then
        M.log.error("Invalid configuration: Items subdirectory not found")
        return false
    end

    M.items = {}
    local file_list = vim.fn.readdir(items_path)
    for _, file_name in ipairs(file_list) do
        local file_path = M.utils.concat_paths(items_path, file_name)
        if M.utils.file_exists(file_path) then
            local item = vim.fn.json_decode(M.utils.read_file_contents(file_path))
            M.items[item.id] = item
        else
            M.log.error("File not found: " .. file_path)
        end
    end
    return true
end

--- Save item changes into file
--- @param item table
M.save_item = function(item)
    local subdir = item.is_archived and M.opts.subdirectories.archive or M.opts.subdirectories.items
    local file_path = M.utils.concat_paths(M.opts.path, subdir, item.id)
    M.utils.write_to_file(file_path, vim.fn.json_encode(item))
end

--- Create a markdown attachment file for the specified item.
--- @param item table The item to create the attachment for
--- @return boolean True if the attachment was created successfully, false otherwise
M.create_attachment = function(item)
    if item == nil then
        M.log.error("Invalid argument; item=nil")
        return false
    end

    if item.attachment_path ~= nil then
        M.log.error("Item already has an attachment: " .. item.attachment_path)
        return false;
    end
    item.attachment_path = M.utils.concat_paths(M.opts.path, M.opts.subdirectories.attachments, item.id .. '.md')
    M.save_item(item)
    if not M.utils.file_exists(item.attachment_path) then
        M.utils.write_to_file(item.attachment_path, "# " .. item.id .. ": " .. item.title)
    end
    return true
end

--- Add a new item to the specified category.
--- @param category string The category to add the item to
--- @param title string The title of the item
M.add_item = function(category, title)
    local items = M.get_items_for_category_sorted(category)
    for _, item in ipairs(items) do
        item.order = item.order + 1
        M.save_item(item)
    end

    local item = {
        id = M.metadata.next_id(),
        title = title,
        category = category,
        order = 1,
        attachment_path = nil,
        created = os.date("%Y-%m-%d %H:%M:%S"),
    }
    M.items[item.id] = item
    M.save_item(item)
end

--- Archive given item
--- @param item_id number The id of the item to archive
--- @return table? item The archived item or nil if the item was not found
M.archive_item = function(item_id)
    local item = M.items[item_id]
    if item == nil then
        M.log.error("Failed to archive item: Item id [" .. item_id .. "] not found!")
        return nil
    end

    item.is_archived = true
    M.items[item_id] = nil
    M.utils.move_file(
        M.utils.concat_paths(M.opts.path, M.opts.subdirectories.items, item.id),
        M.utils.concat_paths(M.opts.path, M.opts.subdirectories.archive, item.id)
    )
    return item
end

--- Unarchive give item
--- @param item_id number The id of the item to unarchive
--- @return table? item The unarchived item or nil if the item was not found
M.unarchive_item = function(item_id)
    local items = M.get_archived_items()
    for _, item in ipairs(items) do
        if item.id == item_id then
            item.is_archived = false
            M.items[item_id] = item
            M.utils.move_file(
                M.utils.concat_paths(M.opts.path, M.opts.subdirectories.archive, item.id),
                M.utils.concat_paths(M.opts.path, M.opts.subdirectories.items, item.id)
            )
            return item
        end
    end
    return nil
end

--- Delete given item
--- @param item_id number The id of the item to delete
M.delete_item = function(item_id)
    local item_path = M.utils.concat_paths(M.opts.path, M.opts.subdirectories.items, item_id)
    if M.utils.file_exists(item_path) then
        M.utils.delete_file(item_path)
    end

    local archive_path = M.utils.concat_paths(M.opts.path, M.opts.subdirectories.archive, item_id)
    if M.utils.file_exists(archive_path) then
        M.utils.delete_file(archive_path)
    end

    local attachment_path = M.utils.concat_paths(M.opts.path, M.opts.subdirectories.attachments, item_id .. '.md')
    if M.utils.file_exists(attachment_path) then
        M.utils.delete_file(attachment_path)
    end

    M.items[item_id] = nil
end

return M;
