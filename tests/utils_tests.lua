package.path = package.path .. ';../lua/?.lua;../lua/?/init.lua'
-- local mock = require('luassert.mock')
-- local stub = require('luassert.stub')
local utils = require('quick-kanban.utils')

describe('Utils test', function()
    before_each(function()
        -- Called before each test
    end)

    it('should return current working directory', function()
        local path = utils.get_working_directory_path()
        assert.is_string(path)
        assert.equals(path, vim.fn.getcwd())
    end)

    it('should concatenate given strings and provide a valid path', function()
        local path = utils.concat_paths("$HOME", ".local", "bin")
        assert.is_string(path)
        assert.equals(path, "$HOME/.local/bin")
    end)

    it('Should check if a directory exists', function()
        local directory_exists = quick_kanban.directory_exists('/path/to/directory')
        assert.is_boolean(directory_exists)
    end)
end)


--     it('should check if a file exists', function()
--         local file_exists = quick_kanban.file_exists('/path/to/file.txt')
--         assert.is_boolean(file_exists)
--     end)
--
--     it('should create a file if it does not exist', function()
--         quick_kanban.touch_file('/path/to/newfile.txt')
--         local file_exists = quick_kanban.file_exists('/path/to/newfile.txt')
--         assert.is_true(file_exists)
--     end)
--
--     it('should move a file from one directory to another', function()
--         quick_kanban.move_file('/path/to/sourcefile.txt', '/path/to/destinationfile.txt')
--         local file_exists = quick_kanban.file_exists('/path/to/destinationfile.txt')
--         assert.is_true(file_exists)
--     end)
--
--     it('should create a directory if it does not exist', function()
--         quick_kanban.touch_directory('/path/to/newdirectory')
--         local directory_exists = quick_kanban.directory_exists('/path/to/newdirectory')
--         assert.is_true(directory_exists)
--     end)
--
--     it('should read file contents into a table', function()
--         local contents = quick_kanban.read_file_contents('/path/to/file.txt')
--         assert.is_table(contents)
--     end)
--
--     it('should write to a file', function()
--         local success = quick_kanban.write_to_file('/path/to/newfile.txt', 'Hello, World!')
--         assert.is_true(success)
--     end)
--
--     it('should delete a file', function()
--         quick_kanban.delete_file('/path/to/file.txt')
--         local file_exists = quick_kanban.file_exists('/path/to/file.txt')
--         assert.is_false(file_exists)
--     end)
--
--     it('should write lines to a file', function()
--         quick_kanban.write_lines_to_file('/path/to/newfile.txt', {'Line 1', 'Line 2', 'Line 3'})
--         local contents = quick_kanban.read_file_contents('/path/to/newfile.txt')
--         assert.is_table(contents)
--     end)
--
--     it('should append lines to a file', function()
--         quick_kanban.append_file('/path/to/newfile.txt', {'Line 4', 'Line 5'})
--         local contents = quick_kanban.read_file_contents('/path/to/newfile.txt')
--         assert.is_table(contents)
--     end)
--
--     it('should check if a string starts with a given start string', function()
--         local starts_with = quick_kanban.starts_with('Hello, World!', 'Hello')
--         assert.is_true(starts_with)
--     end)
--
--     it('should open a popup window', function()
--         local size = { width = 20, height = 10 }
--         local pos = { row = 5, col = 10 }
--         local wid, bufnr = quick_kanban.open_popup_window('Popup Window', size, pos)
--         assert.is_number(wid)
--         assert.is_number(bufnr)
--     end)
--
--     it('should hide and show the cursor', function()
--         quick_kanban.hide_cursor()
--         quick_kanban.show_cursor()
--     end)
--
--     it('should pad a string to the right', function()
--         local padded_str = quick_kanban.right_pad('Hello', 10)
--         assert.is_string(padded_str)
--     end)
--
--     it('should pad a string to the left', function()
--         local padded_str = quick_kanban.left_pad('Hello', 10)
--         assert.is_string(padded_str)
--     end)
--
--     it('should trim whitespace from the beginning of a string', function()
--         local trimmed_str = quick_kanban.trim_left('   Hello')
--         assert.is_string(trimmed_str)
--     end)
--
--     it('should trim whitespace from the beginning and end of a string', function()
--         local trimmed_str = quick_kanban.trim('   Hello   ')
--         assert.is_string(trimmed_str)
--     end)
--
--     it('should set keymaps for a buffer', function()
--         local bufnr = 1
--         local keymap = '<leader>q'
--         local cmd = ':quit'
--         quick_kanban.set_keymap(bufnr, keymap, cmd)
--     end)
-- end)
--
--
