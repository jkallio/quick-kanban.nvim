local utils = require('quick-kanban.utils')

local M = {
    --- @class options Configuration options for the quick-kanban plugin. These can be overriden by calling the `setup` function.
    options = {
        --- The directory path where the kanban board data will be stored. This is typically set to the working directory concatenated with '/quick-kanban'.
        --- @type string
        path = utils.concat_paths(utils.get_working_directory_path(), ".quick-kanban"),

        --- The directory path where the metadata for the kanban board items will be stored.
        --- @type string
        meta_path = utils.concat_paths(utils.get_working_directory_path(), ".quick-kanban", ".meta"),

        --- A list of categories representing the different stages in the kanban board.
        --- @type table
        categories = {
            'Backlog',
            'In Progress',
            'Done',
        },

        --- Default categiry to add new items
        --- @type string
        default_category = "Backlog",

        --- Name of the category representing the Archive
        --- @type string
        archive_category = "Archive",

        --- Whether to add new items on top of the category.
        --- @type string | "top" | "bottom"
        new_item_position = "top",

        --- Whether to show the archive category in the kanban board.
        --- @type boolean
        show_archive = true,

        --- The key mappings for interacting with the windows in the kanban board.
        --- @type table
        keymaps = {
            quit = 'q',           -- Quit the kanban board
            add = 'a',            -- Add a new item in the current category
            delete = 'd',         -- Delete the item under cursor
            next_category = 'l',  -- Move focus to the next category
            prev_category = 'h',  -- Move focus to the previous category
            next_item = 'j',      -- Move to the next item in the current category
            prev_item = 'k',      -- Move to the previous item in the current category
            new_item = 'n',       -- Create a new item in the current category
            refresh = 'R',        -- Refresh the kanban board
            commit = 'c',         -- Commit the changes in the Kanban board into file system
            select_item = '<CR>', -- Select the item under cursor
        },

        --- The window configuration for the kanban board.
        --- @type table
        window = {
            --- The width of the kanban board window.
            --- @type number
            width = 40,

            --- The height of the kanban board window.
            --- @type number
            height = 10,

            --- Window title decoration (prefix and suffix)
            --- @type table
            title_decoration = { "-=[ ", " ]=-" },

            --- The transparency of the kanban board window.
            --- @type number
            blend = 10,

            --- The gap between the kanban board windows
            --- @type number
            gap = 2,

            --- Hide the cursor when the kanban board is opened.
            --- @type boolean
            hide_cursor = true,
        },

        --- Show line numbers
        --- @type boolean
        number = true,

        --- Wrap lines
        --- @type boolean
        wrap = true,

        --- Commit unsaved changes when closing the kanban board.
        --- @type boolean
        commit_on_close = true,

        --- Silent commit
        --- @type boolean
        silent_commit = true,
    }
}

--- Setup the configuration options for the quick-kanban plugin.
--- @param options table? Configuration options for the quick-kanban plugin.
function M.setup(options)
    if options ~= nil then
        M.options = vim.tbl_deep_extend("force", {}, M.options, options)
    end
    if M.options.show_archive then
        table.insert(M.options.categories, M.options.archive_category)
    end
end

return M
