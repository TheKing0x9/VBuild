local ffi = require("ffi")

local format = string.format
local char = string.char

local term = {}

ffi.cdef [[
    int isatty(int fildes);
    int fileno(void *stream);
]]

local function maketermfunc(fmt)
    fmt = '\027[' .. fmt
    local func = nil

    return function(...)
        return io.stdout:write(format(fmt, ...))
    end
end

----------------------------------------------------------------
-- $$$$$$\  $$\   $$\ $$$$$$$\   $$$$$$\   $$$$$$\  $$$$$$$\
-- $$  __$$\ $$ |  $$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  __$$\
-- $$ /  \__|$$ |  $$ |$$ |  $$ |$$ /  \__|$$ /  $$ |$$ |  $$ |
-- $$ |      $$ |  $$ |$$$$$$$  |\$$$$$$\  $$ |  $$ |$$$$$$$  |
-- $$ |      $$ |  $$ |$$  __$$<  \____$$\ $$ |  $$ |$$  __$$<
-- $$ |  $$\ $$ |  $$ |$$ |  $$ |$$\   $$ |$$ |  $$ |$$ |  $$ |
-- \$$$$$$  |\$$$$$$  |$$ |  $$ |\$$$$$$  | $$$$$$  |$$ |  $$ |
-- \______/  \______/ \__|  \__| \______/  \______/ \__|  \__|
----------------------------------------------------------------

term.cursor = {
    jump = maketermfunc '%d;%dH',
    up = maketermfunc '%dA',
    down = maketermfunc '%dB',
    right = maketermfunc '%dC',
    left = maketermfunc '%dD',
    save = maketermfunc 's',
    restore = maketermfunc 'u',
}

----------------------------------------------------------------
-- $$$$$$\   $$$$$$\  $$\       $$$$$$\  $$$$$$$\   $$$$$$\
-- $$  __$$\ $$  __$$\ $$ |     $$  __$$\ $$  __$$\ $$  __$$\
-- $$ /  \__|$$ /  $$ |$$ |     $$ /  $$ |$$ |  $$ |$$ /  \__|
-- $$ |      $$ |  $$ |$$ |     $$ |  $$ |$$$$$$$  |\$$$$$$\
-- $$ |      $$ |  $$ |$$ |     $$ |  $$ |$$  __$$<  \____$$\
-- $$ |  $$\ $$ |  $$ |$$ |     $$ |  $$ |$$ |  $$ |$$\   $$ |
-- \$$$$$$  | $$$$$$  |$$$$$$$$\ $$$$$$  |$$ |  $$ |\$$$$$$  |
-- \______/  \______/ \________|\______/ \__|  \__| \______/
----------------------------------------------------------------

term.colors = {}

local colormt = {}

function colormt:__tostring()
    return self.value
end

function colormt:__concat(other)
    return tostring(self) .. tostring(other)
end

function colormt:__call(s)
    return self .. s .. term.colors.reset
end

local function makecolor(value)
    return setmetatable({ value = '\27[' .. tostring(value) .. 'm' }, colormt)
end

local colorvalues = {
    -- attributes
    reset      = 0,
    clear      = 0,
    default    = 0,
    bright     = 1,
    dim        = 2,
    underscore = 4,
    blink      = 5,
    reverse    = 7,
    hidden     = 8,

    -- foreground
    black      = 30,
    red        = 31,
    green      = 32,
    yellow     = 33,
    blue       = 34,
    magenta    = 35,
    cyan       = 36,
    white      = 37,

    -- background
    onblack    = 40,
    onred      = 41,
    ongreen    = 42,
    onyellow   = 43,
    onblue     = 44,
    onmagenta  = 45,
    oncyan     = 46,
    onwhite    = 47,
}

for c, v in pairs(colorvalues) do
    term.colors[c] = makecolor(v)
end

term.clear = maketermfunc '2J'
term.clearline = maketermfunc '2K'
term.cleareol = maketermfunc 'K'
term.clearend = maketermfunc 'J'

function term.isatty(file)
    return ffi.C.isatty(ffi.C.fileno(file))
end

return term;
