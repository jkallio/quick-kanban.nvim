local utils = require('quick-kanban.utils')

--- This module handles loading and saving all the data from and into disk.
--- @type table
local M = {
    --- Configuration options
    --- @type table
    opts = {},

    --- Struct of parameters for the metadata of the kanban board
    --- @type table
    metadata = {},

    --- Dictionary of items where the key is the item.id
    --- @type table Dictionary <number, table>
    items = {},
}

--- Setup the data module with the specified options.
--- @param opts table The configuration options
M.setup = function(opts)
    M.opts = opts
    if utils.directory_exists(M.opts.path) then
        M.reload_kanban_meta_file()
        M.reload_item_files()
    end
end

--- Get the next item id from the item id pool and increment the id counter in the metadata file.
--- @return number The next item id
M.next_item_id = function()
    M.metadata.id = M.metadata.id + 1
    M.save_kanban_metadata()
    return M.metadata.id
end

--- Get the items for the specified category.
--- @param category string The name of the category
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

--- Move an item from one category to another.
--- @param item_id number The id of the item to move
--- @param category string The category to move the item to
--- @return boolean true if the item was moved successfully, false otherwise
M.move_item_to_category = function(item_id, category)
    local item = M.items[item_id]
    if item == nil or category == nil then
        utils.log.error("Invalid argument(s): "
            .. "item_id=" .. (item_id or "nil") .. "; "
            .. "category=" .. (category or "nil"))
        return false
    end

    if item.category == category then
        utils.log.warn("Item [" .. item.id .. "] already in category " .. category)
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
        utils.log.error("Invalid argument: item_id=" .. (item_id or "nil"))
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

--- Reload the kanban metadata file
--- @return boolean true if the metadata was reloaded successfully, false otherwise
M.reload_kanban_meta_file = function()
    local metadata_path = utils.concat_paths(M.opts.path, ".metadata.json")
    if not utils.file_exists(metadata_path) then
        local meta_defaults = {
            id = 0
        }
        utils.write_to_file(metadata_path, vim.fn.json_encode(meta_defaults))
        utils.log.info("Quick Kanban meta file initialized.")
    end
    local lines = utils.read_file_contents(metadata_path)
    M.metadata = vim.fn.json_decode(lines)
    return true
end

--- Save the metadata to the metadata file
M.save_kanban_metadata = function()
    local path = utils.concat_paths(M.opts.path, ".metadata.json")
    utils.write_to_file(path, vim.fn.json_encode(M.metadata))
end

--- Reload the data items from the files in the configured path.
--- @return boolean true if the items were reloaded successfully, false otherwise
M.reload_item_files = function()
    local items_path = utils.concat_paths(M.opts.path, M.opts.subdirectories.items)
    if not utils.directory_exists(items_path) then
        utils.log.error("Invalid configuration: Items subdirectory not found")
        return false
    end

    M.items = {}
    local file_list = vim.fn.readdir(items_path)
    for _, file_name in ipairs(file_list) do
        local file_path = utils.concat_paths(items_path, file_name)
        if utils.file_exists(file_path) then
            local item = vim.fn.json_decode(utils.read_file_contents(file_path))
            M.items[item.id] = item
        else
            utils.log.error("File not found: " .. file_path)
        end
    end
    return true
end

--- Save item changes into file
--- @param item table
M.save_item = function(item)
    local subdir = item.is_archived and M.opts.subdirectories.archive or M.opts.subdirectories.items
    local file_path = utils.concat_paths(M.opts.path, subdir, item.id)
    utils.write_to_file(file_path, vim.fn.json_encode(item))
end

--- Create an attachment for the specified item.
--- @param item table The item to create the attachment for
--- @return boolean True if the attachment was created successfully, false otherwise
M.create_attachment = function(item)
    if item == nil then
        utils.log.error("Invalid argument; item=nil")
        return false
    end

    if item.attachment_path ~= nil and utils.file_exists(item.attachment_path) then
        utils.log.error("Item already has an attachment")
        return false
    end

    item.attachment_path = utils.concat_paths(M.opts.path, M.opts.subdirectories.attachments, item.id .. '.md')
    utils.write_to_file(item.attachment_path, "# " .. item.id .. ": " .. item.title)
    M.save_item(item)
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
        id = M.next_item_id(),
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
M.archive_item = function(item_id)
    local item = M.items[item_id]
    if item == nil then
        utils.log.error("Failed to archive item: Item id [" .. item_id .. "] not found!")
        return
    end

    item.is_archived = true
    M.items[item_id] = nil
    utils.move_file(
        utils.concat_paths(M.opts.path, M.opts.subdirectories.items, item.id),
        utils.concat_paths(M.opts.path, M.opts.subdirectories.archive, item.id)
    )
end

--- Delete given item
--- @param item_id number The id of the item to delete
M.delete_item = function(item_id)
    local item_path = utils.concat_paths(M.opts.path, M.opts.subdirectories.items, item_id)
    if utils.file_exists(item_path) then
        utils.delete_file(item_path)
    end

    local archive_path = utils.concat_paths(M.opts.path, M.opts.subdirectories.archive, item_id)
    if utils.file_exists(archive_path) then
        utils.delete_file(archive_path)
    end

    local attachment_path = utils.concat_paths(M.opts.path, M.opts.subdirectories.attachments, item_id .. '.md')
    if utils.file_exists(attachment_path) then
        utils.delete_file(attachment_path)
    end

    M.items[item_id] = nil
end

return M;
