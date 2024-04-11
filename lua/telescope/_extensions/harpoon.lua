local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
    error("This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

return telescope.register_extension({
    exports = {
        marks = require("telescope._extensions.harpoon_marks.marks"),
    },
})
