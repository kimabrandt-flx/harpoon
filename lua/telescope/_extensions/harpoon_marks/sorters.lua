local conf = require("telescope.config").values

local M = {}

M.file_mark_sorter = function(opts)
    local sorter = conf.generic_sorter(opts)
    local generic_scoring = sorter.scoring_function
    sorter.scoring_function = function(self, prompt, line, entry)
        local score = generic_scoring(self, prompt, line, entry)
        local multiplier = 1

        -- set the multiplier, when matching an index
        local index = entry.index
        local index_str = tostring(index)
        for value in string.gmatch(prompt, "%S+") do
            local num = tonumber(value)
            if num ~= nil then
                if num == index then
                    multiplier = 0.25
                    break -- found an exact match
                elseif index_str:match(value) then
                    multiplier = 0.5
                    -- continue looking for a better match
                end
            end
        end

        if score ~= -1 then -- generic_sorter found a match
            score = score * multiplier -- make the score better
        elseif multiplier ~= 1 then -- has matched an index
            score = multiplier -- make the score slightly better
        end

        return score
    end
    return sorter
end

return M
