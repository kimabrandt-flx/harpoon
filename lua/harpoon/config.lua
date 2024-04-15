local Extensions = require("harpoon.extensions")
local Logger = require("harpoon.logger")
local Path = require("plenary.path")
local function normalize_path(buf_name, root)
    return Path:new(buf_name):make_relative(root)
end

local M = {}
local DEFAULT_LIST = "__harpoon_files"
M.DEFAULT_LIST = DEFAULT_LIST

---@alias HarpoonListItem {value: any, context: any}
---@alias HarpoonListFileItem {value: string, context: {row: number, col: number}, meta: {bufnr: number}}
---@alias HarpoonListFileOptions {split: boolean, vsplit: boolean, tabedit: boolean, open_file_command: string}

---@class HarpoonPartialConfigItem
---@field select_with_nil? boolean defaults to false
---@field open_file_command? string defaults to "edit"
---@field encode? (fun(list_item: HarpoonListItem): string) | boolean
---@field decode? (fun(obj: string): any)
---@field display? (fun(list_item: HarpoonListItem): string)
---@field select? (fun(list_item?: HarpoonListItem, list: HarpoonList, options: any?): nil)
---@field equals? (fun(list_line_a: HarpoonListItem, list_line_b: HarpoonListItem): boolean)
---@field create_list_item? fun(config: HarpoonPartialConfigItem, item: any?): HarpoonListItem
---@field BufLeave? fun(evt: any, list: HarpoonList): nil
---@field VimLeavePre? fun(evt: any, list: HarpoonList): nil
---@field get_root_dir? fun(): string

---@class HarpoonSettings
---@field save_on_toggle boolean defaults to false
---@field sync_on_ui_close? boolean
---@field key (fun(): string)

---@class HarpoonPartialSettings
---@field save_on_toggle? boolean
---@field sync_on_ui_close? boolean
---@field key? (fun(): string)

---@class HarpoonConfig
---@field default HarpoonPartialConfigItem
---@field settings HarpoonSettings
---@field [string] HarpoonPartialConfigItem

---@class HarpoonPartialConfig
---@field default? HarpoonPartialConfigItem
---@field settings? HarpoonPartialSettings
---@field [string] HarpoonPartialConfigItem

---@return HarpoonPartialConfigItem
function M.get_config(config, name)
    return vim.tbl_extend("force", {}, config.default, config[name] or {})
end

local edit_buffer
do
    local map = {
        edit = "buffer",
        new = "sbuffer",
        vnew = "vert sbuffer",
        tabedit = "tab sb",
    }

    edit_buffer = function(command, bufnr)
        command = map[command]
        if command == nil then
            error("There was no associated buffer-command")
        end

        vim.cmd(string.format("%s %d", command, bufnr))
    end
end

local edit_file
do
    local map = {
        edit = "edit",
        new = "new",
        vnew = "vnew",
        tabedit = "tabedit",
    }

    edit_file = function(command, filename)
        command = map[command]
        if command == nil then
            error("There is no such open-command")
        end

        vim.cmd(string.format("%s %s", command, vim.fn.fnameescape(filename)))
    end
end

---@return HarpoonConfig
function M.get_default_config()
    return {

        settings = {
            save_on_toggle = false,
            sync_on_ui_close = false,

            key = function()
                return vim.loop.cwd()
            end,
        },

        default = {

            --- select_with_nill allows for a list to call select even if the provided item is nil
            select_with_nil = false,

            -- the command to use to open a file
            -- valid commands include: "edit", "new", "vnew", "tabedit"
            open_file_command = "edit",

            ---@param obj HarpoonListItem
            ---@return string
            encode = function(obj)
                local tablecopy = {}
                for k, v in pairs(obj) do
                    if k ~= "meta" then -- ignore meta
                        tablecopy[k] = v
                    end
                end
                return vim.json.encode(tablecopy)
            end,

            ---@param str string
            ---@return HarpoonListItem
            decode = function(str)
                return vim.json.decode(str)
            end,

            ---@param list_item HarpoonListItem
            display = function(list_item)
                return list_item.value
            end,

            --- the select function is called when a user selects an item from
            --- the corresponding list and can be nil if select_with_nil is true
            ---@param list_item? HarpoonListFileItem
            ---@param list HarpoonList
            ---@param options HarpoonListFileOptions
            select = function(list_item, list, options)
                options = options or {}

                Logger:log(
                    "config_default#select",
                    list_item,
                    list.name,
                    options
                )

                if not list_item then
                    return
                end

                local command = options.open_file_command or list.config.open_file_command
                local filename = list_item.value
                local bufnr = -1
                local set_position = false

                if list_item.meta then
                    bufnr = list_item.meta.bufnr or -1
                else
                    list_item.meta = {
                        bufnr = -1,
                    }
                end

                if bufnr ~= -1 then
                    local ok, is_listed = pcall(vim.api.nvim_get_option_value, "buflisted", { buf = bufnr })
                    if not ok then
                        bufnr = -1
                    elseif not is_listed then
                        vim.api.nvim_set_option_value("buflisted", true, {
                            buf = bufnr,
                        })
                    end
                end

                xpcall(function ()
                    if bufnr ~= -1 then -- edit buffer
                        edit_buffer(command, bufnr)
                    else -- edit file
                        -- check if we didn't pick a different buffer
                        -- prevents restarting lsp server
                        if vim.api.nvim_buf_get_name(0) ~= filename or command ~= "edit" then
                            edit_file(command, filename)
                            bufnr = vim.fn.bufnr(filename, false)
                            if vim.fn.bufexists(bufnr) then
                                set_position = true
                                list_item.meta.bufnr = bufnr
                            else
                                list_item.meta.bufnr = -1
                            end
                        end
                    end
                end, function()
                        bufnr = vim.fn.bufnr(filename, false)
                        if vim.fn.bufexists(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
                            set_position = true
                            list_item.meta.bufnr = bufnr
                        else
                            list_item.meta.bufnr = -1
                        end
                    end)

                if set_position then
                    -- HACK: fixes folding: https://github.com/nvim-telescope/telescope.nvim/issues/699
                    if vim.wo.foldmethod == "expr" then
                        vim.schedule(function()
                            vim.opt.foldmethod = "expr"
                        end)
                    end

                    if options.vsplit then
                        vim.cmd("vsplit")
                    elseif options.split then
                        vim.cmd("split")
                    elseif options.tabedit then
                        vim.cmd("tabedit")
                    end

                    local lines = vim.api.nvim_buf_line_count(bufnr)

                    local edited = false
                    if list_item.context.row > lines then
                        list_item.context.row = lines
                        edited = true
                    end

                    local row = list_item.context.row
                    local row_text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
                    local col = #row_text[1]

                    if list_item.context.col > col then
                        list_item.context.col = col
                        edited = true
                    end

                    vim.api.nvim_win_set_cursor(0, {
                        list_item.context.row or 1,
                        list_item.context.col or 0,
                    })

                    if edited then
                        Extensions.extensions:emit(
                            Extensions.event_names.POSITION_UPDATED,
                            {
                                list_item = list_item,
                            }
                        )
                    end
                end

                if list_item.meta.bufnr > -1 then
                    Extensions.extensions:emit(Extensions.event_names.NAVIGATE, {
                        buffer = list_item.meta.bufnr,
                    })
                end
            end,

            ---@param list_item_a HarpoonListItem
            ---@param list_item_b HarpoonListItem
            equals = function(list_item_a, list_item_b)
                if list_item_a == nil and list_item_b == nil then
                    return true
                elseif list_item_a == nil or list_item_b == nil then
                    return false
                end

                return list_item_a.value == list_item_b.value
            end,

            get_root_dir = function()
                return vim.loop.cwd()
            end,

            ---@param config HarpoonPartialConfigItem
            ---@param name? any
            ---@return HarpoonListItem
            create_list_item = function(config, name)
                name = name
                    or normalize_path(
                        vim.api.nvim_buf_get_name(
                            vim.api.nvim_get_current_buf()
                        ),
                        config.get_root_dir()
                    )

                Logger:log("config_default#create_list_item", name)

                local bufnr = vim.fn.bufnr(name, false)

                local pos = { 1, 0 }
                if bufnr ~= -1 then
                    pos = vim.api.nvim_win_get_cursor(0)
                end

                return {
                    value = name,
                    context = {
                        row = pos[1],
                        col = pos[2],
                    },
                    meta = {
                        bufnr = vim.fn.bufexists(bufnr) and bufnr or nil,
                    },
                }
            end,

            ---@param arg {buf: number}
            ---@param list HarpoonList
            BufLeave = function(arg, list)
                local bufnr = arg.buf
                local bufname = normalize_path(
                    vim.api.nvim_buf_get_name(bufnr),
                    list.config.get_root_dir()
                )
                local item = list:get_by_value(bufname)

                if item then
                    local pos = vim.api.nvim_win_get_cursor(0)

                    Logger:log(
                        "config_default#BufLeave updating position",
                        bufnr,
                        bufname,
                        item,
                        "to position",
                        pos
                    )

                    item.context.row = pos[1]
                    item.context.col = pos[2]

                    Extensions.extensions:emit(
                        Extensions.event_names.POSITION_UPDATED,
                        item
                    )
                end
            end,

            autocmds = { "BufLeave" },
        },
    }
end

---@param partial_config HarpoonPartialConfig?
---@param latest_config HarpoonConfig?
---@return HarpoonConfig
function M.merge_config(partial_config, latest_config)
    partial_config = partial_config or {}
    local config = latest_config or M.get_default_config()
    for k, v in pairs(partial_config) do
        if k == "settings" then
            config.settings = vim.tbl_extend("force", config.settings, v)
        elseif k == "default" then
            config.default = vim.tbl_extend("force", config.default, v)
        else
            config[k] = vim.tbl_extend("force", config[k] or {}, v)
        end
    end
    return config
end

---@param settings HarpoonPartialSettings
function M.create_config(settings)
    local config = M.get_default_config()
    for k, v in ipairs(settings) do
        config.settings[k] = v
    end
    return config
end

return M
