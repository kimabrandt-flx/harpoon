local Logger = require("harpoon.logger")
local Path = require("plenary.path")
local utils = require("harpoon.utils")
local Extensions = require("harpoon.extensions")

local function guess_length(arr)
    local last_known = #arr
    for i = 1, 20 do
        if arr[i] ~= nil and last_known < i then
            last_known = i
        end
    end

    return last_known
end

local function determine_length(arr, previous_length)
    local idx = previous_length
    for i = previous_length, 1, -1 do
        if arr[i] ~= nil then
            idx = i
            break
        end
    end
    return idx
end

--- @class HarpoonNavOptions
--- @field ui_nav_wrap? boolean

---@param items any[]
---@param element any
---@param config HarpoonPartialConfigItem?
local function index_of(items, length, element, config)
    local equals = config and config.equals
        or function(a, b)
            return a == b
        end
    local index = -1
    for i = 1, length do
        local item = items[i]
        if equals(element, item) then
            index = i
            break
        end
    end

    return index
end

---@param arr any[]
---@param value any
---@return number
local function prepend_to_array(arr, value)
    local idx = 1
    local prev = value
    while true do
        local curr = arr[idx]
        arr[idx] = prev
        if curr == nil then
            break
        end
        prev = curr
        idx = idx + 1
    end
    return idx
end

--- @class HarpoonItem
--- @field value string
--- @field context any

--- @class HarpoonList
--- @field config HarpoonPartialConfigItem
--- @field name string
--- @field _length number
--- @field _index number
--- @field items HarpoonItem[]
local HarpoonList = {}

---@param list HarpoonList
---@param options any
local sync_index = function(list, options)
    local bufnr = options.bufnr
    local filename = options.filename
    local index = options.index
    if bufnr ~= nil and filename ~= nil then
        local config = list.config
        local relname = Path:new(filename):make_relative(config.get_root_dir())
        if bufnr == vim.fn.bufnr(relname, false) then
            local element = config.create_list_item(config, relname)
            local index_found =
                index_of(list.items, list._length, element, config)
            if index_found > -1 then
                list._index = index_found
            end
        elseif index ~= nil then
            list._index = index
        end
    elseif index ~= nil then
        list._index = index
    end
end

HarpoonList.__index = HarpoonList
function HarpoonList:new(config, name, items)
    items = items or {}
    local list = setmetatable({
        items = items,
        config = config,
        name = name,
        _length = guess_length(items),
        _index = 0,
    }, self)
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        pattern = { "*" },
        callback = function(args)
            sync_index(list, {
                bufnr = args.buf,
                filename = args.file,
            })
        end,
    })
    return list
end

---@return number
function HarpoonList:length()
    return self._length
end

function HarpoonList:clear()
    self.items = {}
    self._length = 0
end

---@param item? HarpoonListItem
---@return HarpoonList
function HarpoonList:append(item)
    print("APPEND IS DEPRECATED -- PLEASE USE `add`")
    return self:add(item)
end

---@param idx number
---@param item? HarpoonListItem
function HarpoonList:replace_at(idx, item)
    item = item or self.config.create_list_item(self.config)
    local current_idx = index_of(self.items, self._length, item, self.config)

    self.items[idx] = item

    if current_idx ~= idx then
        self.items[current_idx] = nil
    end

    if idx > self._length then
        self._length = idx
    else
        self._length = determine_length(self.items, self._length)
    end

    Extensions.extensions:emit(
        Extensions.event_names.REPLACE,
        { list = self, item = item, idx = idx }
    )
end

---@param item? HarpoonListItem
function HarpoonList:add(item)
    item = item or self.config.create_list_item(self.config)

    local index = index_of(self.items, self._length, item, self.config)
    Logger:log("HarpoonList:add", { item = item, index = index })

    if index == -1 then
        local idx = self._length + 1
        for i = 1, self._length + 1 do
            if self.items[i] == nil then
                idx = i
                break
            end
        end

        self.items[idx] = item
        if idx > self._length then
            self._length = idx
        end

        sync_index(self, { index = idx })

        Extensions.extensions:emit(
            Extensions.event_names.ADD,
            { list = self, item = item, idx = idx }
        )
    end

    return self
end

---@return HarpoonList
function HarpoonList:prepend(item)
    item = item or self.config.create_list_item(self.config)
    local index = index_of(self.items, self._length, item, self.config)
    Logger:log("HarpoonList:prepend", { item = item, index = index })
    if index == -1 then
        local stop_idx = prepend_to_array(self.items, item)
        if stop_idx > self._length then
            self._length = stop_idx
        end

        sync_index(self, { index = 1 })

        Extensions.extensions:emit(
            Extensions.event_names.ADD,
            { list = self, item = item, idx = 1 }
        )
    end

    return self
end

---@return HarpoonList
function HarpoonList:remove(item)
    item = item or self.config.create_list_item(self.config)
    for i = 1, self._length do
        local v = self.items[i]
        if self.config.equals(v, item) then
            Logger:log("HarpoonList:remove", { item = item, index = i })
            self.items[i] = nil
            if i == self._length then
                self._length = determine_length(self.items, self._length)
            end

            local current_buffer = vim.api.nvim_get_current_buf()
            sync_index(self, {
                bufnr = current_buffer,
                filename = vim.api.nvim_buf_get_name(current_buffer),
            })

            Extensions.extensions:emit(
                Extensions.event_names.REMOVE,
                { list = self, item = item, idx = i }
            )
            break
        end
    end
    return self
end

---@return HarpoonList
function HarpoonList:remove_at(index)
    if self.items[index] then
        Logger:log(
            "HarpoonList:remove_at",
            { item = self.items[index], index = index }
        )
        self.items[index] = nil
        if index == self._length then
            self._length = determine_length(self.items, self._length)
        end

        local current_buffer = vim.api.nvim_get_current_buf()
        sync_index(self, {
            bufnr = current_buffer,
            filename = vim.api.nvim_buf_get_name(current_buffer),
        })

        Extensions.extensions:emit(
            Extensions.event_names.REMOVE,
            { list = self, item = self.items[index], idx = index }
        )
    end
    return self
end

function HarpoonList:get(index)
    return self.items[index]
end

-- function HarpoonList:get_by_display(name)
--     local displayed = self:display()
--     local index = index_of(displayed, #displayed, name)
--     if index == -1 then
--         return nil
--     end
--     return self.items[index], index
-- end
local equals = function(element, item)
    if item == nil then
        return false
    end
    return element == item.value
end
function HarpoonList:get_by_value(value)
    local index = index_of(self.items, self._length, value, {
        -- equals = equals,
        -- equals = function(element, item)
        --     if item == nil then
        --         return false
        --     end
        --     return element == item.value
        -- end,
    })
    if index == -1 then
        return nil
    end
    return self.items[index], index
end

--- much inefficiencies.  dun care
---@param displayed string[]
---@param length number
---@param options any
function HarpoonList:resolve_displayed(displayed, length, options)
    options = options or {}

    local new_list = {}

    local list_displayed = self:display()

    local change = 0
    for i = 1, self._length do
        local v = self.items[i]
        local index = index_of(displayed, self._length, v)
        if index == -1 then
            change = change + 1
        end
    end

    for i = 1, length do
        local v = displayed[i]
        local index = index_of(list_displayed, self._length, v)
        if utils.is_white_space(v) then
            new_list[i] = nil
        elseif index == -1 then
            new_list[i] = self.config.create_list_item(self.config, v)
            change = change + 1
        else
            local index_in_new_list =
                index_of(new_list, length, self.items[index], self.config)

            if index_in_new_list == -1 then
                new_list[i] = self.items[index]
            end

            if index ~= i then
                change = change + 1
            end
        end
    end

    local win_id = options.win_id
    if win_id then
        local pos = vim.api.nvim_win_get_cursor(win_id)
        self._index = pos[1]
    end

    self.items = new_list
    self._length = length
    if change > 0 then
        Extensions.extensions:emit(Extensions.event_names.LIST_CHANGE)
    end
end

function HarpoonList:select(index, options)
    local item = self.items[index]
    if item or self.config.select_with_nil then
        sync_index(self, { index = index })

        Extensions.extensions:emit(
            Extensions.event_names.SELECT,
            { list = self, item = item, idx = index }
        )
        self.config.select(item, self, options)
    end
end

---
--- @param opts? HarpoonNavOptions
function HarpoonList:next(opts)
    opts = opts or {}

    self._index = self._index + 1
    if self._index > self._length then
        if opts.ui_nav_wrap then
            self._index = 1
        else
            self._index = self._length
        end
    end

    self:select(self._index)
end

---
--- @param opts? HarpoonNavOptions
function HarpoonList:prev(opts)
    opts = opts or {}

    self._index = self._index - 1
    if self._index < 1 then
        if opts.ui_nav_wrap then
            self._index = #self.items
        else
            self._index = 1
        end
    end

    self:select(self._index)
end

--- @return string[]
function HarpoonList:display()
    local out = {}
    for i = 1, self._length do
        local v = self.items[i]
        out[i] = v == nil and "" or self.config.display(v)
    end

    return out
end

--- @return string[]
function HarpoonList:encode()
    local out = {}
    local items = self.items
    for i = 1, self._length do
        local item = items[i]
        if item then
            out[i] = self.config.encode(item)
        end
    end

    return out
end

--- @return HarpoonList
--- @param list_config HarpoonPartialConfigItem
--- @param name string
--- @param items string[]
function HarpoonList.decode(list_config, name, items)
    local list_items = {}

    for i = 1, #items do
        local item = items[i]
        if item == vim.NIL then
            list_items[i] = nil -- allow nil-values
        else
            list_items[i] = list_config.decode(item)
        end
    end

    return HarpoonList:new(list_config, name, list_items)
end

return HarpoonList
