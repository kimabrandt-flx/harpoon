local conf = require("telescope.config").values
local pickers = require("telescope.pickers")

return function(opts)
    local hm_finders = require("telescope._extensions.harpoon_marks.finders")
    local hm_sorters = require("telescope._extensions.harpoon_marks.sorters")
    local hm_actions = require("telescope._extensions.harpoon_marks.actions")
    opts = opts or {}
    pickers
        .new(opts, {
            prompt_title = "Harpoon Marks",
            finder = hm_finders.file_mark_finder(opts),
            sorter = hm_sorters.file_mark_sorter(opts),
            previewer = conf.file_previewer(opts),
            attach_mappings = function(_, map)
                map("i", "<c-d>", hm_actions.delete_mark_selections_prompt)
                map("n", "<c-d>", hm_actions.delete_mark_selections_prompt)
                map("i", "<c-p>", hm_actions.move_mark_previous)
                map("n", "<c-p>", hm_actions.move_mark_previous)
                map("i", "<c-n>", hm_actions.move_mark_next)
                map("n", "<c-n>", hm_actions.move_mark_next)
                return true
            end,
        })
        :find()
end
