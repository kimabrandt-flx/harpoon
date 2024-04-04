local Logger = require("harpoon.logger")
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
local function index_of(items, element, config)
    local equals = config and config.equals
        or function(a, b)
            return a == b
        end
    local index = -1
    for i, item in ipairs(items) do
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

HarpoonList.__index = HarpoonList
function HarpoonList:new(config, name, items)
    items = items or {}
    return setmetatable({
        items = items,
        config = config,
        _length = guess_length(items),
        name = name,
        _index = 1,
    }, self)
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
    print("APPEND IS DEPRICATED -- PLEASE USE `add`")
    return self:add(item)
end

---@param idx number
---@param item? HarpoonListItem
function HarpoonList:replace_at(idx, item)
    item = item or self.config.create_list_item(self.config)
    Extensions.extensions:emit(
        Extensions.event_names.REPLACE,
        { list = self, item = item, idx = idx }
    )
    self.items[idx] = item
    if idx > self._length then
        self._length = idx
    end
end

---@param item? HarpoonListItem
function HarpoonList:add(item)
    item = item or self.config.create_list_item(self.config)

    local index = index_of(self.items, item, self.config)
    Logger:log("HarpoonList:add", { item = item, index = index })

    if index == -1 then
        local idx = self._length + 1
        for i = 1, self._length + 1 do
            if self.items[i] == nil then
                idx = i
                break
            end
        end

        Extensions.extensions:emit(
            Extensions.event_names.ADD,
            { list = self, item = item, idx = idx }
        )

        self.items[idx] = item
        if idx > self._length then
            self._length = idx
        end
    end

    return self
end

---@return HarpoonList
function HarpoonList:prepend(item)
    item = item or self.config.create_list_item(self.config)
    local index = index_of(self.items, item, self.config)
    Logger:log("HarpoonList:prepend", { item = item, index = index })
    if index == -1 then
        Extensions.extensions:emit(
            Extensions.event_names.ADD,
            { list = self, item = item, idx = 1 }
        )
        local stop_idx = prepend_to_array(self.items, item)
        if stop_idx > self._length then
            self._length = stop_idx
        end
    end

    return self
end

---@return HarpoonList
function HarpoonList:remove(item)
    item = item or self.config.create_list_item(self.config)
    for i = 1, self._length do
        local v = self.items[i]
        if self.config.equals(v, item) then
            Extensions.extensions:emit(
                Extensions.event_names.REMOVE,
                { list = self, item = item, idx = i }
            )
            Logger:log("HarpoonList:remove", { item = item, index = i })
            self.items[i] = nil
            if i == self._length then
                self._length = determine_length(self.items, self._length)
            end
            break
        end
    end
    return self
end

---@return HarpoonList
function HarpoonList:remove_at(index)
    if self.items[index] then
        Logger:log(
            "HarpoonList:removeAt",
            { item = self.items[index], index = index }
        )
        Extensions.extensions:emit(
            Extensions.event_names.REMOVE,
            { list = self, item = self.items[index], idx = index }
        )
        self.items[index] = nil
        if index == self._length then
            self._length = determine_length(self.items, self._length)
        end
    end
    return self
end

function HarpoonList:get(index)
    return self.items[index]
end

function HarpoonList:get_by_display(name)
    local displayed = self:display()
    local index = index_of(displayed, name, self.config)
    if index == -1 then
        return nil
    end
    return self.items[index]
end

--- much inefficiencies.  dun care
---@param displayed string[]
---@param length number
function HarpoonList:resolve_displayed(displayed, length)
    local new_list = {}

    local list_displayed = self:display()

    for i = 1, self._length do
        local v = self.items[i]
        local index = index_of(displayed, v)
        if index == -1 then
            Extensions.extensions:emit(
                Extensions.event_names.REMOVE,
                { list = self, item = self.items[i], idx = i }
            )
        end
    end

    for i = 1, length do
        local v = displayed[i]
        local index = index_of(list_displayed, v)
        if v == "" then
            new_list[i] = nil
        elseif index == -1 then
            new_list[i] = self.config.create_list_item(self.config, v)
            Extensions.extensions:emit(
                Extensions.event_names.ADD,
                { list = self, item = new_list[i], idx = i }
            )
        else
            if index ~= i then
                Extensions.extensions:emit(
                    Extensions.event_names.REORDER,
                    { list = self, item = self.items[index], idx = i }
                )
            end
            local index_in_new_list =
                index_of(new_list, self.items[index], self.config)

            if index_in_new_list == -1 then
                new_list[i] = self.items[index]
            end
        end
    end

    self.items = new_list
    self._length = length
end

function HarpoonList:select(index, options)
    local item = self.items[index]
    if item or self.config.select_with_nil then
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
    for _, v in ipairs(self.items) do
        table.insert(out, self.config.encode(v))
    end

    return out
end

--- @return HarpoonList
--- @param list_config HarpoonPartialConfigItem
--- @param name string
--- @param items string[]
function HarpoonList.decode(list_config, name, items)
    local list_items = {}

    for _, item in ipairs(items) do
        table.insert(list_items, list_config.decode(item))
    end

    return HarpoonList:new(list_config, name, list_items)
end

return HarpoonList
