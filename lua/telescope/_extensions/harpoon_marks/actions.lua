local harpoon = require("harpoon")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local action_utils = require("telescope.actions.utils")

local M = {}

M.delete_mark_selections = function(prompt_bufnr)
    local selections = {}
    action_utils.map_selections(prompt_bufnr, function(entry)
        table.insert(selections, entry)
    end)
    table.sort(selections, function(a, b)
        return a.index < b.index
    end)

    local count = 0

    if #selections > 0 then
        -- delete marks from multi-selection
        for i = #selections, 1, -1 do
            local selection = selections[i]
            harpoon:list():remove_at(selection.index)
            count = count + 1
        end
    else
        -- delete marks from single-selection
        local selection = action_state.get_selected_entry()
        if selection ~= nil then
            harpoon:list():remove_at(selection.index)
            count = count + 1
        else
            return 0
        end
    end

    -- delete picker-selections
    local current_picker = action_state.get_current_picker(prompt_bufnr)
    current_picker:delete_selection(function() end)

    return count
end

M.delete_mark_selections_prompt = function(prompt_bufnr)
    vim.ui.input({
        prompt = "Delete selected marks? [Yes/no]: ",
        default = "y",
    }, function(input)
        if input == nil then
            return
        end

        local input_str = string.lower(input)
        if input_str == "y" or input_str == "yes" then
            local deletion_count = M.delete_mark_selections(prompt_bufnr)
            if deletion_count == 0 then
                print("No marks deleted")
            elseif deletion_count == 1 then
                print("Deleted 1 mark")
            else
                print("Deleted " .. deletion_count .. " marks")
            end
        else
            print("No action taken")
        end
    end)
end

M.move_mark_next = function(prompt_bufnr)
    -- get current index
    local current_selection = action_state.get_selected_entry()
    local current_index = current_selection.index

    -- get next index
    actions.move_selection_next(prompt_bufnr)
    local next_selection = action_state.get_selected_entry()
    local next_index = next_selection.index

    -- swap harpoon-items
    local mark_list = harpoon:list().items
    local current_item = mark_list[current_index]
    local next_item = mark_list[next_index]
    mark_list[current_index] = next_item
    mark_list[next_index] = current_item

    -- swap telescope-entries
    local current_value = current_selection.value
    local next_value = next_selection.value
    local current_display = current_selection.display
    local next_display = next_selection.display
    current_selection.value = next_value
    next_selection.value = current_value
    current_selection.display = next_display
    next_selection.display = current_display

    -- refresh picker
    local current_picker = action_state.get_current_picker(prompt_bufnr)
    local selection_row = current_picker:get_selection_row()
    current_picker:refresh()

    vim.wait(1) -- wait for refresh

    -- select row
    current_picker:set_selection(selection_row)
end

M.move_mark_previous = function(prompt_bufnr)
    -- get current index
    local current_selection = action_state.get_selected_entry()
    local current_index = current_selection.index

    -- get previous index
    actions.move_selection_previous(prompt_bufnr)
    local previous_selection = action_state.get_selected_entry()
    local previous_index = previous_selection.index

    -- swap harpoon items
    local mark_list = harpoon:list().items
    local current_item = mark_list[current_index]
    local previous_item = mark_list[previous_index]
    mark_list[current_index] = previous_item
    mark_list[previous_index] = current_item

    -- swap telescope entries
    local current_value = current_selection.value
    local previous_value = previous_selection.value
    local current_display = current_selection.display
    local previous_display = previous_selection.display
    current_selection.value = previous_value
    previous_selection.value = current_value
    current_selection.display = previous_display
    previous_selection.display = current_display

    -- refresh picker
    local current_picker = action_state.get_current_picker(prompt_bufnr)
    local selection_row = current_picker:get_selection_row()
    current_picker:refresh()

    vim.wait(1) -- wait for refresh

    -- select row
    current_picker:set_selection(selection_row)
end

return M
