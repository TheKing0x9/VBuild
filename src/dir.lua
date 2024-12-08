local lfs = require 'lfs'
local realpath = require 'posix.stdlib'.realpath

local dir = {}
dir.__index = dir

local home = os.getenv('HOME')
local seperator = '/'
local cwd = lfs.currentdir()

local function escape_path(path)
    if path:sub(-1) == seperator then
        return path
    end
    return path .. seperator
end

local function split(path)
    return path:match("^(.-)([^\\/]-)(%.[^\\/%.]-)%.?$")
end

local function isdir(t)
    return getmetatable(t) == dir
end

local function join(self, ...)
    for _, v in ipairs({ ... }) do
        local path = tostring(v)
        local isabs = path:sub(1, 1) == seperator
        if isabs then
            self.path = path
        else
            if not self.path then
                self.path = path
            else
                self.path = self.path .. seperator .. path
            end
        end
    end
end

dir.new = join

function dir:join(...)
    join(self, ...)
    return self
end

function dir:abs()
    if self:isabs() then return self end

    self.path = cwd .. seperator .. self.path
    return self
end

function dir:__tostring()
    return self.path
end

function dir:__concat(str)
    return self.path .. str
end

function dir:__add(path)
    assert(self:isdir(), "Current path is not a directory")
    return dir(self.path, path)
end

function dir:__div(path)
    assert(self:isdir(), "Current path is not a directory")
    return dir(self.path, path)
end

function dir:norm()
    self.path = realpath(self.path)
    return self
end

function dir:isabs()
    return self.path:sub(1, 1) == seperator or self.path:match("^(%a):\\") or false
end

function dir:isdir()
    return lfs.attributes(self.path, 'mode') == 'directory'
end

function dir:isfile()
    return lfs.attributes(self.path, 'mode') == 'file'
end

function dir:split()
    return split(self.path)
end

function dir:dirname()
    local path, _, _ = split(self.path)
    return path
end

function dir:basename()
    local _, name, _ = split(self.path)
    return name
end

function dir:extension()
    local _, _, ext = split(self.path)
    return ext
end

return setmetatable(dir, {
    __call = function(_, ...)
        local obj = setmetatable({}, dir)
        obj:new(...)
        return obj
    end
})
