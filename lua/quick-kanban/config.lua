--- @class quick-kanban.config
local M = {
    --- Configuration options for the quick-kanban plugin.
    --- @class quick-kanban.config.options Configuration options for the quick-kanban plugin. These can be overriden by calling the `setup` function.
    options = {
        --- Full path to directory where the kanban board data will be stored.
        --- On default the '/quick-kanban' directory will be created in the current working directory.
        --- @type string?
        path = nil,

        --- Log level for the plugin
        --- @type "debug" | "info" | "warn" | "error" | nil
        log_level = "warn",

        --- Subdirectories for different files in the kanban board.
        --- @type table
        subdirectories = {
            items = ".items",             -- Directory for the items metadata
            archive = ".archive",         -- Directory for the archived items
            attachments = ".attachments", -- Directory for the attachments
        },

        --- A list of categories for the default kanban board.
        --- @type string[]
        default_categories = {
            'Backlog',
            'In Progress',
            'Done',
        },

        --- The key mappings for interacting with the windows in the kanban board.
        --- Each command can be assigned with multiple keys
        --- @type table
        mappings = {
            show_help = '?',
            next_category = 'l',
            prev_category = 'h',
            next_item = 'j',
            prev_item = 'k',
            add_item = 'a',
            edit_item = 'e',
            end_editing = '<esc><esc>',
            archive_item = 'd',
            unarchive_item = 'u',
            delete = 'D',
            open_item = '<leader>o',
            rename = 'r',
            select_item = '<cr>',
            toggle_archive = '<leader>a',
            toggle_preview = '<leader>p',
            quit = { 'q', '<esc>' }, -- You can assign multiple keys to a command
        },

        --- List of disabled key mappings (to improve the usability of the kanban board)
        --- @type string[]
        disabled_keys = { 'a', 'c', 'd', 'i', 'm', 'o', 'p', 'r', 'x', 'gg', 'G', '<esc>', '<tab>', '<cr>', '<bs>', '<del>' },

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
            --- @type string[]
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

--- Initialize the configuration options for the quick-kanban plugin.
--- @param opts table? User defined configuration options
function M.init(opts)
    if opts then
        M.options = vim.tbl_deep_extend("force", M.options, opts)
    end

    -- Set default path if no path was given
    if not M.options.path then
        local utils = require('quick-kanban.utils')
        M.options.path = utils.concat_paths(utils.get_working_directory_path(), ".quick-kanban")
    end
end

return M
