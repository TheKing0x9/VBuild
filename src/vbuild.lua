#! /usr/bin/luajit

-- version definition
local vbuild   = {
    __version = "0.1.0"
}

-- luajit standard library
local bit      = require 'bit'
local ffi      = require 'ffi'

--luarocks dependencies
local lfs      = require 'lfs'
local readline = require 'readline'
local argparse = require 'argparse'
local signal   = require 'posix.signal'
local poll     = require 'posix.poll'.poll

-- locally installed modules
local toml     = require 'modules.toml'
local inspect  = require 'modules.inspect'

local utils    = require 'src.utils'
local dir      = require 'src.dir'
local config   = require 'src.config'
local inotify  = require 'src.inotify'
local command  = require 'src.command'

-- strict mode
require 'src.strict'

local list_dir            = lfs.dir
local attributes          = lfs.attributes
local is_file_readable    = utils.is_file_readable

local exit_loop           = false
toml.strict               = true

local files               = {}
local print_queue         = {}
local watched_dirs        = {}
local testbenches         = {}
local parsed_config       = {}
local watched_testbenches = {}

local fd                  = inotify.init()

do
    local file = dir('vbuild.config', true)
    file = io.open(file.path, 'r')
    if not file then
        print('Error reading vbuild.config, Does the file exists?')
        print('Reverting to default configuration..')
    else
        parsed_config = toml.parse(file:read('*a'))
        file:close()
    end
end

local function add_default_config(header, defaults)
    assert(header, "A header is required")
    assert(defaults, "A default configuration is required")
    assert(config[header] == nil, "A default configuration with same header is already registered")

    config[header] = defaults
end


global({
    vbuild = {
        argparse = argparse,
        inspect = inspect,
        config = config,
        files = files,
        testbenches = testbenches,
        watched_testbenches = watched_testbenches,
        watched_dirs = watched_dirs,
        add_default_config = add_default_config,
        utils = utils,
        dir = dir,
    },
    command = command,
})

local function get_testbench(name)
    local testbench = nil
    local exists = false

    for _, v in pairs(config.Sources.testbench_dirs) do
        testbench = './' .. v .. '/' .. name .. "_tb.v"
        exists = is_file_readable(testbench)

        if exists then
            break
        end
    end

    return exists and testbench or nil
end

local function scan(directory, watched, files, max_depth, depth)
    print("Adding watch to " .. directory)
    if max_depth and
        depth > max_depth then
        return
    end

    local wd = inotify.add_watch(fd, directory, bit.bor(inotify.IN_CREATE, inotify.IN_DELETE, inotify.IN_MODIFY))
    assert(wd > 0, "Inotify add watch failed. Does the directory " .. directory .. " exist?")
    watched[wd] = directory

    for file in list_dir(directory) do
        if file ~= "." and file ~= ".." then
            local path = directory .. file
            local mode = attributes(path, "mode")
            if mode == "directory" then
                scan(path .. "/", watched, files, max_depth, depth and depth + 1)
            else
                local _, name, _ = utils.split_path(path)
                files[name] = path
            end
        end
    end
end

local function printd(...)
    for k, v in ipairs({ ... }) do
        table.insert(print_queue, v)
    end
    table.insert(print_queue, '\n')
end

readline.set_options({ histfile = lfs.currentdir() .. '/.vbuild_history', ignoredups = true })
readline.set_readline_name("watcher")

command.register('clear', function()
    io.stdout:write('\27[2J', '\27[H')
    io.stdout:flush()
end)

command.register('exit', function()
    exit_loop = true
    readline.handler_remove()
end)

-- import plugins
local autoload = config.Plugins.autoload
local path = config.Plugins.path

if parsed_config.Plugins then
    autoload = (parsed_config.Plugins.autoload == nil) and autoload or parsed_config.Plugins.autoload
    path = parsed_config.Plugins.path == nil and path or parsed_config.Plugins.path
end

print(autoload, parsed_config.Plugins.autoload, path)

if autoload then
    for file in list_dir(path) do
        if file ~= "." and file ~= ".." then
            local _, stem, _ = utils.split_path(file)
            local path = string.gsub(path, '[/]+', '.') .. '.' .. stem
            local ok, err = pcall(require, path)
            if not ok then
                print("Error loading plugin: " .. path)
                print(err)
            end
        end
    end

    if parsed_config then
        utils.replace(parsed_config, config)
    end
end

local reserved_words = command.get_keys()
readline.set_complete_list(reserved_words)

-- stop SIGINT from killing the process
signal.signal(signal.SIGINT, function()
    io.stdout:write("Ctrl-C (SIGINT) quit is disabled. Use exit command to exit.")
    io.stdout:flush()
end)

local buffer_size = 1024 * (ffi.sizeof("struct inotify_event") + 16)
local buffer = ffi.new("char[?]", buffer_size)

local line = nil
local fds = {
    [0] = { events = { IN = true } },
    [fd] = { events = { IN = true } }
}

local function dump(queue)
    if next(queue) == nil then return end

    if queue[#print_queue] == '\n' then queue[#print_queue] = nil end
    print(unpack(queue))
    for i = 1, #queue do queue[i] = nil end
end

local linehandler = function(str)
    dump(print_queue)
    if str == nil or str == '' then
        return
    end

    readline.add_history(str)

    local commands = utils.split(str, '&&')
    for _, v in ipairs(commands) do
        v = v:gsub("^%s*(.-)%s*$", "%1")
        local s = utils.split(v)
        local cmd = s[1]
        cmd = cmd:lower()

        table.remove(s, 1)
        local err = command.execute(cmd, s)
        if err then
            print(err); break;
        end
    end
end

for _, v in ipairs(config.Sources.source_dirs) do
    scan("./" .. v .. "/", watched_dirs, files)
end

for _, v in ipairs(config.Sources.testbench_dirs) do
    scan("./" .. v .. '/', watched_testbenches, testbenches)
end

readline.handler_install("vbuild> ", linehandler)
while exit_loop == false do
    poll(fds, -1)
    if fds[0].revents and fds[0].revents.IN then
        readline.read_char() -- only if there's something to be read
    elseif fds[fd].revents and fds[fd].revents.IN then
        local len = inotify.read(fd, buffer, buffer_size)
        local i = 0
        while i < len do
            local event = ffi.cast("struct inotify_event *", buffer + i)
            printd(event.wd, string.format("0x%x", event.mask), event.cookie, ffi.string(event.name))
            i = i + ffi.sizeof("struct inotify_event") + event.len

            local from_tb = watched_dirs[event.wd] == nil
            local watched = from_tb and watched_testbenches or watched_dirs
            local files = from_tb and testbenches or files

            local filename = ffi.string(event.name)
            local path = watched[event.wd] .. filename
            local _, stem, ext = utils.split_path(filename)
            local is_directory = bit.band(event.mask, inotify.IN_ISDIR) == inotify.IN_ISDIR

            if bit.band(event.mask, inotify.IN_CREATE) == inotify.IN_CREATE then
                printd("File created " .. filename)

                if is_directory then
                    scan(path .. "/")
                elseif ext == ".v" then
                    files[stem] = path
                end
            elseif bit.band(event.mask, inotify.IN_DELETE) == inotify.IN_DELETE then
                if is_directory then
                    -- watch already removed as the directory is deleted
                elseif ext == ".v" then
                    files[stem] = nil
                end
            elseif bit.band(event.mask, inotify.IN_IGNORED) == inotify.IN_IGNORED then
                printd("Watch removed " .. filename)
                watched[event.wd] = nil
            end
        end
    else
        -- do some useful background task
    end
end

readline.save_history()

for k, _ in pairs(watched_dirs) do
    inotify.rm_watch(fd, k)
end

for k, _ in pairs(watched_testbenches) do
    inotify.rm_watch(fd, k)
end

inotify.close(fd)

-- no silly % symbol at the end of the prompt
io.stdout:write()
