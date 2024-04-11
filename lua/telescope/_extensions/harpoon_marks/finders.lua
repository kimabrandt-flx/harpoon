local harpoon = require("harpoon")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local entry_display = require("telescope.pickers.entry_display")
local utils = require("telescope.utils")
local strings = require("plenary.strings")

local M = {}

local function make_results(list)
    local results = {}
    for _, item in pairs(list) do
        table.insert(results, {
            value = item.value,
            context = {
                row = item.context.row,
                col = item.context.col,
            },
        })
    end
    return results
end

M.file_mark_finder = function(opts)
    local results = make_results(harpoon:list().items)
    local results_idx_str_len = string.len(tostring(#results))
    local make_file_entry = make_entry.gen_from_file(opts)
    local disable_devicons = opts.disable_devicons

    local icon_width = 0
    if not disable_devicons then
        local icon, _ = utils.get_devicons("fname", disable_devicons)
        icon_width = strings.strdisplaywidth(icon)
    end

    return finders.new_table({
        results = results,
        entry_maker = function(harpoon_item)
            local entry = make_file_entry(harpoon_item.value) -- value => path
            local icon, hl_group =
                utils.get_devicons(entry.filename, disable_devicons)
            local display_config = nil
            if not disable_devicons then
                display_config = {
                    separator = " ",
                    items = {
                        { width = results_idx_str_len },
                        { width = icon_width },
                        { remaining = true },
                        { width = 6 },
                    },
                }
            else
                display_config = {
                    separator = " ",
                    items = {
                        { width = results_idx_str_len },
                        { remaining = true },
                        { width = 6 },
                    },
                }
            end
            local displayer = entry_display.create(display_config)
            entry.display = function(et)
                local et_idx_str = tostring(et.index)
                local et_idx_str_len = string.len(et_idx_str)
                local et_idx_lpad =
                    string.rep(" ", results_idx_str_len - et_idx_str_len)
                local path_to_display = utils.transform_path(opts, et.value)
                local entry_values = nil
                local row = harpoon_item.context.row
                local column = harpoon_item.context.col + 1
                if not disable_devicons then
                    entry_values = {
                        { et_idx_lpad .. et_idx_str },
                        { icon, hl_group },
                        { path_to_display },
                        { row .. ":" .. column },
                    }
                else
                    entry_values = {
                        { et_idx_lpad .. et_idx_str },
                        { path_to_display },
                        { row .. ":" .. column },
                    }
                end
                return displayer(entry_values)
            end
            return entry
        end,
    })
end

return M
