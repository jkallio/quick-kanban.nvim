local utils = require('quick-kanban.utils')

local M = {
    --- @class options Configuration options for the quick-kanban plugin. These can be overriden by calling the `setup` function.
    options = {
        --- Full path to directory where the kanban board data will be stored.
        --- On default the '/quick-kanban' directory will be created in the current working directory.
        --- @type string
        path = utils.concat_paths(utils.get_working_directory_path(), ".quick-kanban"),

        --- Subdirectories for different files in the kanban board.
        --- @type table
        subdirectories = {
            items = ".items",             -- Directory for the items metadata
            archive = ".archive",         -- Directory for the archived items
            attachments = ".attachments", -- Directory for the attachments
        },

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

        --- The key mappings for interacting with the windows in the kanban board.
        --- @type table
        keymaps = {
            quit = '<esc>',               -- Quit the kanban board
            toggle_archive = '<leader>B', -- Toggle the visibility of the archive category
            archive_item = 'd',           -- Archive the item under cursor
            delete = 'D',                 -- Delete the item under cursor
            next_category = 'l',          -- Move focus to the next category
            prev_category = 'h',          -- Move focus to the previous category
            next_item = 'j',              -- Move to the next item in the current category
            prev_item = 'k',              -- Move to the previous item in the current category
            add_item = 'a',               -- Create a new item in the default category
            open_item = '<leader>o',      -- Open the item under cursor
            rename = '<leader>r',         -- Rename the item under cursor
            select_item = '<CR>',         -- Select the item under cursor
        },

        --- The window configuration for the kanban board.
        --- @type table
        window = {
            --- The width of the kanban board window.
            --- @type number
            width = 40,

            --- The height of the kanban board window.
            --- @type number
            height = 20,

            --- Window title decoration (prefix and suffix)
            --- @type table
            title_decoration = { "-=[ ", " ]=-" },

            --- The transparency of the kanban board window.
            --- @type number
            blend = 5,

            --- The gap between the kanban board windows
            --- @type number
            gap = 2,

            --- Hide the cursor when the kanban board is opened.
            --- @type boolean
            hide_cursor = true,

            --- The accent color for the kanban board window.
            --- @type string
            accent_color = "#44AA44",

            --- The highlight color for the kanban board window.
            --- @type string
            hilight_color = "#FFFF44",

            --- The color of the text of the currently active item.
            --- @type string
            active_text_color = "#000000",

            --- The color of the text of the selected item.
            --- @type string
            selected_text_color = "#000000",
        },

        --- Show line numbers
        --- @type boolean
        number = false,

        --- Wrap lines
        --- @type boolean
        wrap = true,
    }
}

--- Setup the configuration options for the quick-kanban plugin.
--- @param options table? Configuration options for the quick-kanban plugin.
function M.setup(options)
    if options ~= nil then
        M.options = vim.tbl_deep_extend("force", {}, M.options, options)
    end
end

return M
