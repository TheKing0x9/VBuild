local inspect = require 'modules.inspect'
local colors = require 'src.term'.colors
local command = require 'src.command'

local format = string.format

local modes = {
    { name = "trace", color = colors.blue, },
    { name = "debug", color = colors.cyan, },
    { name = "info",  color = colors.green, },
    { name = "warn",  color = colors.yellow, },
    { name = "error", color = colors.red, },
    { name = "fatal", color = colors.magenta, },
}

local levels = {}
for i, v in ipairs(modes) do
    levels[string.upper(v.name)] = i
end

local log = {}
log.__index = log

function log:new()
    self.msgs = {}
    self.files = {}
end

function log:addfile(handle, severity, fmt)
    handle = (type(handle) == "string") and io.open(handle, 'w') or handle
    if handle == nil then return end
    fmt = fmt or "$LEVEL $MSG"

    table.insert(self.files, {
        handle = handle,
        level = levels[modes[severity].name:upper()],
        fmt = fmt
    })
end

function log:deinit()
    for i = 1, #self.files do
        if self.files[i].handle ~= io.stdout then self.files[i].handle:close() end
    end
end

local function incolor(str, color)
    if not color then return '[ ' .. str .. ' ]' end
    return color .. '[ ' .. str .. ' ]' .. colors.reset
end

-- logging functions
for l, x in ipairs(modes) do
    local name = x.name
    local nameupper = string.upper(name)

    log[name] = function(self, ...)
        local msg = tostring(...)
        local info = debug.getinfo(2, "Sl")
        local lineinfo = info.short_src .. ":" .. info.currentline
        local date = os.date("%Y-%m-%d %H:%M:%S")
        local filename = info.short_src
        local level = nameupper

        for i = 1, #self.files do
            local file = self.files[i]
            if levels[nameupper] >= file.level then
                local fmt = file.fmt

                local str = fmt:gsub("%$DATE", date)
                str = str:gsub("%$FILENAME", filename)
                str = str:gsub("%$LEVEL", incolor(format("%-5s", level), file.handle == io.stdout and x.color or false))
                str = str:gsub("%$MSG", msg)
                str = str:gsub("%$LINEINFO", lineinfo)

                file.handle:write(str .. "\n")
                file.handle:flush()
            end
        end
    end
end

log.levels = levels
log.logger = setmetatable({}, log)
log.logger:new()

return setmetatable(log, {
    __call = function(self, ...)
        local obj = setmetatable({}, log)
        obj:new(...)
        return obj
    end
});
