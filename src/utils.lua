local lfs = require 'lfs'

local utils = {}

local find = string.find
local fmt = string.format
local cut = string.sub
local error = error
local match = string.match

utils.is_main = function()
    if pcall(debug.getlocal, 5, 1) then
        return false
    end
    return true
end

utils.is_file_readable = function(file)
    local f = io.open(file, 'r')
    if f == nil then
        return false
    end
    f:close()
    return true
end

utils.split_path = function(path)
    return match(path, "^(.-)([^\\/]-)(%.[^\\/%.]-)%.?$")
end

utils.deep_copy = function(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[utils.deep_copy(k, s)] = utils.deep_copy(v, s) end
    return res
end

utils.directory_exists = function(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == 'directory'
end

utils.replace = function(source, target)
    for k, v in pairs(source) do
        if target[k] == nil then
            target[k] = v
        elseif type(source[k]) == 'table' then
            utils.replace(source[k], target[k])
        else
            target[k] = v
        end
    end
end

utils.split = function(str, delimiter)
    -- Handle an edge case concerning the str parameter. Immediately return an
    -- empty table if str == ''.
    if str == '' then return {} end

    -- Handle special cases concerning the delimiter parameter.
    -- 1. If the pattern is nil, split on contiguous whitespace.
    -- 2. If the pattern is an empty string, explode the string.
    -- 3. Protect against patterns that match too much. Such patterns would hang
    --    the caller.
    delimiter = delimiter or '%s+'
    if find('', delimiter, 1) then
        local msg = fmt('The delimiter (%s) would match the empty string.',
            delimiter)
        error(msg)
    end

    -- The table `t` will store the found items. `s` and `e` will keep
    -- track of the start and end of a match for the delimiter. Finally,
    -- `position` tracks where to start grabbing the next match.
    local t = {}
    local s, e
    local position = 1
    s, e = find(str, delimiter, position)

    while s do
        t[#t + 1] = cut(str, position, s - 1)
        position = e + 1
        s, e = find(str, delimiter, position)
    end

    -- To get the (potential) last item, check if the final position is
    -- still within the string. If it is, grab the rest of the string into
    -- a final element.
    if position <= #str then
        t[#t + 1] = cut(str, position)
    end

    -- Special handling for a (potential) final trailing delimiter. If the
    -- last found end position is identical to the end of the whole string,
    -- then add a trailing empty field.
    if position > #str then
        t[#t + 1] = ''
    end

    return t
end

return utils
