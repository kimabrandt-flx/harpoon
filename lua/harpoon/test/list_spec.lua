local List = require("harpoon.list")
local Config = require("harpoon.config")
local eq = assert.are.same

describe("list", function()
    it("decode", function()
        local config = Config.merge_config({
            foo = {
                decode = function(item)
                    -- split item on :
                    local parts = vim.split(item, ":")
                    return {
                        value = parts,
                        context = nil,
                    }
                end,

                display = function(item)
                    return table.concat(item.value, "---")
                end,
            },
        })
        local list_config = Config.get_config(config, "foo")

        local list = List.decode(list_config, "foo", { "foo:bar", "baz:qux" })
        local displayed = list:display()

        eq(displayed, {
            "foo---bar",
            "baz---qux",
        })
    end)

    it("select_with_nil", function()
        local foo_selected = nil
        local bar_selected = nil

        local config = Config.merge_config({
            foo = {
                select_with_nil = true,
                select = function(list_item, _, options)
                    foo_selected = { list_item, options }
                end,
            },
            bar = {
                select = function(list_item, options)
                    bar_selected = { list_item, options }
                end,
            },
        })
        local fooc = Config.get_config(config, "foo")
        local barc = Config.get_config(config, "bar")

        local foo = List.decode(fooc, "foo", {})
        local bar = List.decode(barc, "bar", {})

        foo:select(4, {})
        bar:select(4, {})

        eq({ nil, {} }, foo_selected)
        eq(nil, bar_selected)
    end)

    it("add", function()
        local config = Config.merge_config({
            foo = {
                equals = function(a, b)
                    return a == b
                end,
            },
        })

        local c = Config.get_config(config, "foo")
        local list = List:new(c, "foo", {
            nil,
            nil,
            { three = true },
            { four = true },
        })

        eq(list.items, {
            nil,
            nil,
            { three = true },
            { four = true },
        })
        eq(list:length(), 4)

        local one = { one = true }
        list:add(one)
        eq(list.items, {
            { one = true },
            nil,
            { three = true },
            { four = true },
        })
        eq(list:length(), 4)

        local two = { two = true }
        list:add(two)
        eq(list.items, {
            { one = true },
            { two = true },
            { three = true },
            { four = true },
        })
        eq(list:length(), 4)

        list:add({ five = true })
        eq(list.items, {
            { one = true },
            { two = true },
            { three = true },
            { four = true },
            { five = true },
        })
        eq(list:length(), 5)
    end)

    it("prepend", function()
        local config = Config.merge_config({
            foo = {
                equals = function(a, b)
                    return a == b
                end,
            },
        })

        local c = Config.get_config(config, "foo")
        local list = List:new(c, "foo", {
            { three = true },
            nil,
            nil,
            { four = true },
        })

        eq(list.items, {
            { three = true },
            nil,
            nil,
            { four = true },
        })
        eq(list:length(), 4)

        local one = { one = true }
        list:prepend(one)
        eq(list.items, {
            { one = true },
            { three = true },
            nil,
            { four = true },
        })
        eq(list:length(), 4)

        local two = { two = true }
        list:prepend(two)
        eq(list.items, {
            { two = true },
            { one = true },
            { three = true },
            { four = true },
        })
        eq(list:length(), 4)

        list:prepend({ five = true })
        eq(list.items, {
            { five = true },
            { two = true },
            { one = true },
            { three = true },
            { four = true },
        })
        eq(list:length(), 5)
    end)

    it("remove", function()
        local config = Config.merge_config()
        local c = Config.get_config(config, "foo")
        local list = List:new(c, "foo", {
            { value = "one" },
            nil,
            { value = "three" },
            { value = "four" },
        })

        eq(4, list:length())
        list:remove({ value = "three" })
        eq(4, list:length())
        list:remove({ value = "four" })
        eq(1, list:length())
        eq({
            { value = "one" },
        }, list.items)
    end)

    it("remove_at", function()
        local config = Config.merge_config()
        local c = Config.get_config(config, "foo")
        local list = List:new(c, "foo", {
            { value = "one" },
            nil,
            { value = "three" },
            { value = "four" },
        })

        eq(4, list:length())
        list:remove_at(3)

        eq(4, list:length())
        eq({
            { value = "one" },
            nil,
            nil,
            { value = "four" },
        }, list.items)

        list:remove_at(4)
        eq(1, list:length())
        eq({
            { value = "one" },
        }, list.items)
    end)

    it("replace_at", function()
        local config = Config.merge_config()
        local c = Config.get_config(config, "foo")
        local list = List:new(c, "foo")

        list:replace_at(3, { value = "threethree" })
        eq(3, list:length())
        eq({
            nil,
            nil,
            { value = "threethree" },
        }, list.items)

        list:replace_at(4, { value = "four" })
        eq(4, list:length())
        eq({
            nil,
            nil,
            { value = "threethree" },
            { value = "four" },
        }, list.items)

        list:replace_at(1, { value = "one" })
        eq(4, list:length())
        eq({
            { value = "one" },
            nil,
            { value = "threethree" },
            { value = "four" },
        }, list.items)

        list:replace_at(2, { value = "one" })
        eq(4, list:length())
        eq({
            nil,
            { value = "one" },
            { value = "threethree" },
            { value = "four" },
        }, list.items)

        list:replace_at(5, { value = "one" })
        eq(5, list:length())
        eq({
            nil,
            nil,
            { value = "threethree" },
            { value = "four" },
            { value = "one" },
        }, list.items)
    end)

    it("resolve_displayed", function()
        local config = Config.merge_config()
        local c = Config.get_config(config, "foo")
        local list = List:new(c, "foo", {
            nil,
            nil,
            { value = "threethree" },
        })

        eq(3, list:length())

        list:resolve_displayed({
            "",
            "",
            "",
            "threethree",
        }, 4)

        eq(4, list:length())
        eq({
            nil,
            nil,
            nil,
            { value = "threethree" },
        }, list.items)

        list:resolve_displayed({
            "oneone",
            "",
            "",
            "threethree",
        }, 4)

        eq(4, list:length())
        eq({
            { value = "oneone", context = { row = 1, col = 0 } },
            nil,
            nil,
            { value = "threethree" },
        }, list.items)
    end)
end)
