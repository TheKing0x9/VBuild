local lfs = require 'lfs'

local dir = {}
dir.__index = dir

local function escape_path(path)
    if path:sub(-1) == '/' then
        return path
    end
    return path .. '/'
end

local function isdir(t)
    return getmetatable(t) == dir
end

local home = escape_path(os.getenv('HOME'))

function dir:new(path, relative)
    if isdir(path) then
        self.path = path.path
        return self.path
    end

    if relative then
        self.path = escape_path(lfs.currentdir()) .. path
    else
        self.path = home .. path
    end
    return self.path
end

function dir:join(path)
    self.path = escape_path(self.path) .. path
    return self
end

function dir:join_dir(path)
    self.path = self.path .. escape_path(path)
    return self
end

function dir:__tostring()
    return self.path
end

return setmetatable(dir, {
    __call = function(_, ...)
        local obj = setmetatable({}, dir)
        obj:new(...)
        return obj
    end
})
