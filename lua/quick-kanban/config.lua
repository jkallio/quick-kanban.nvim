local utils = require('quick-kanban.utils')

local M = {
    --- @class options Configuration options for the quick-kanban plugin. These can be overriden by calling the `setup` function.
    options = {
        --- Full path to directory where the kanban board data will be stored.
        --- On default the '/quick-kanban' directory will be created in the current working directory.
        --- @type string
        path = utils.concat_paths(utils.get_working_directory_path(), ".quick-kanban"),

        --- Log level for the plugin (debug, info, warn, error, nil)
        --- @type string
        log_level = "info",

        --- Subdirectories for different files in the kanban board.
        --- @type table
        subdirectories = {
            items = ".items",             -- Directory for the items metadata
            archive = ".archive",         -- Directory for the archived items
            attachments = ".attachments", -- Directory for the attachments
        },

        --- A list of categories for the default kanban board.
        --- @type table
        default_categories = {
            'Backlog',
            'In Progress',
            'Done',
        },

        --- The key mappings for interacting with the windows in the kanban board.
        --- @type table
        keymaps = {
            show_help = { keys = '?', desc = "Show help" },
            next_category = { keys = 'l', desc = "Next category" },
            prev_category = { keys = 'h', desc = "Prev category" },
            next_item = { keys = 'j', desc = "Next item" },
            prev_item = { keys = 'k', desc = "Prev item" },
            add_item = { keys = 'a', desc = "Add new item" },
            edit_item = { keys = 'e', desc = "Edit attachment" },
            end_editing = { keys = '<esc><esc>', desc = "End editing" },
            archive_item = { keys = 'd', desc = "Archvie item" },
            unarchive_item = { keys = 'u', desc = "Unarchive item" },
            delete = { keys = 'D', desc = "Delete item" },
            open_item = { keys = '<leader>o', desc = "Open item" },
            rename = { keys = { 'r', 'c' }, desc = "Rename item title" },
            select_item = { keys = '<cr>', desc = "Select item" },
            toggle_archive = { keys = '<leader>a', desc = "Toggle Archive" },
            toggle_preview = { keys = '<leader>p', desc = "Toggle Preview" },
            quit = { keys = { 'q', '<esc>' }, desc = "Quit" },
        },

        --- The window configuration for the kanban board
        --- @type table
        window = {
            --- The width of each kanban category window
            --- @type number
            width = 40,

            --- The height of the kanban UI
            --- @type number
            height = 30,

            --- Window title decoration (prefix and suffix)
            --- @type table
            title_decoration = { "-=[ ", " ]=-" },

            --- The transparency of the kanban board window.
            --- @type number
            blend = 5,

            --- The gap between the kanban board windows (vertical)
            --- @type number
            vertical_gap = 1,

            --- The gap between the kanban board windows (horizontal)
            --- @type number
            horizontal_gap = 2,

            --- Hide the cursor when the kanban board is opened.
            --- @type boolean
            hide_cursor = true,

            --- The accent color for the kanban board window.
            --- @type string
            accent_color = "#44AA44",

            --- The highlight color for the kanban board window.
            --- @type string
            hilight_color = "#FFFF44",

            --- Line background color
            --- @type string
            active_text_bg = "#448844",

            --- The color of the text of the currently active item.
            --- @type string
            active_text_fg = "#000000",

            --- The selected text background
            --- @type string
            selected_text_bg = "#888844",

            --- The color of the text of the selected item.
            --- @type string
            selected_text_fg = "#000000",
        },

        --- Show line numbers
        --- @type boolean
        number = true,

        --- Wrap lines
        --- @type boolean
        wrap = true,

        --- Show the preview window
        --- @type boolean
        show_preview = true,

        --- Show the archive window
        --- @type boolean
        show_archive = false,
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
