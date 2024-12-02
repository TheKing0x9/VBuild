#! /usr/bin/luajit

-- version definition
local vbuild   = {
    __version = "0.1.0"
}

--------------------------------------------------------------------------------
-- $$\      $$\  $$$$$$\  $$$$$$$\  $$\   $$\ $$\       $$$$$$$$\  $$$$$$\
-- $$$\    $$$ |$$  __$$\ $$  __$$\ $$ |  $$ |$$ |      $$  _____|$$  __$$\
-- $$$$\  $$$$ |$$ /  $$ |$$ |  $$ |$$ |  $$ |$$ |      $$ |      $$ /  \__|
-- $$\$$\$$ $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |      $$$$$\    \$$$$$$\
-- $$ \$$$  $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |      $$  __|    \____$$\
-- $$ |\$  /$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |      $$ |      $$\   $$ |
-- $$ | \_/ $$ | $$$$$$  |$$$$$$$  |\$$$$$$  |$$$$$$$$\ $$$$$$$$\ \$$$$$$  |
-- \__|     \__| \______/ \_______/  \______/ \________|\________| \______/
--------------------------------------------------------------------------------

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
local
_queue                    = {}
local watched_dirs        = {}
local testbenches         = {}
local parsed_config       = {}
local watched_testbenches = {}

--------------------------------------------------------------------------------
-- $$$$$$\  $$$$$$$\ $$$$$$\
-- $$  __$$\ $$  __$$\\_$$  _|
-- $$ /  $$ |$$ |  $$ | $$ |
-- $$$$$$$$ |$$$$$$$  | $$ |
-- $$  __$$ |$$  ____/  $$ |
-- $$ |  $$ |$$ |       $$ |
-- $$ |  $$ |$$ |     $$$$$$\
-- \__|  \__|\__|     \______|
--------------------------------------------------------------------------------

local function add_default_config(header, defaults)
    assert(header, "A header is required")
    assert(defaults, "A default configuration is required")
    assert(config[header] == nil, "A default configuration with same header is already registered")

    config[header] = defaults
end

-- declare the global API
global({
    vbuild = {
        config = config,
        files = files,
        testbenches = testbenches,
        watched_testbenches = watched_testbenches,
        watched_dirs = watched_dirs,
        add_default_config = add_default_config,
        command = command,
        utils = utils,
    },
    modules = {
        argparse = argparse,
        inspect = inspect,
        lfs = lfs,
        dir = dir,
    }
})

--------------------------------------------------------------------------------
-- $$$$$$$\  $$\      $$\   $$\  $$$$$$\  $$$$$$\ $$\   $$\  $$$$$$\
-- $$  __$$\ $$ |     $$ |  $$ |$$  __$$\ \_$$  _|$$$\  $$ |$$  __$$\
-- $$ |  $$ |$$ |     $$ |  $$ |$$ /  \__|  $$ |  $$$$\ $$ |$$ /  \__|
-- $$$$$$$  |$$ |     $$ |  $$ |$$ |$$$$\   $$ |  $$ $$\$$ |\$$$$$$\
-- $$  ____/ $$ |     $$ |  $$ |$$ |\_$$ |  $$ |  $$ \$$$$ | \____$$\
-- $$ |      $$ |     $$ |  $$ |$$ |  $$ |  $$ |  $$ |\$$$ |$$\   $$ |
-- $$ |      $$$$$$$$\\$$$$$$  |\$$$$$$  |$$$$$$\ $$ | \$$ |\$$$$$$  |
-- \__|      \________|\______/  \______/ \______|\__|  \__| \______/
--------------------------------------------------------------------------------

local function load_plugins()
    local autoload = config.Plugins.autoload
    local path = config.Plugins.path
    local plugins = {}

    if parsed_config and parsed_config.Plugins then
        autoload = (parsed_config.Plugins.autoload == nil) and autoload or parsed_config.Plugins.autoload
        path = parsed_config.Plugins.path == nil and path or parsed_config.Plugins.path
    end

    package.path = './' .. path .. '/?/init.lua;' .. package.path .. "\n"

    if not autoload then return plugins end

    for file in list_dir(path) do
        if file ~= "." and file ~= ".." then
            local _, stem, _ = utils.split_path(file)
            local module = string.gsub(path, '[/]+', '.') .. '.' .. stem
            table.insert(plugins, require(module))
        end
    end

    return plugins
end

local function read_config_file(file)
    file = io.open(file.path, 'r')
    if not file then
        print('Error reading vbuild.config, Does the file exists?')
        print('Reverting to default configuration..')
    else
        local config = toml.parse(file:read('*a'))
        file:close()
        return config
    end
end

--------------------------------------------------------------------------------
-- $$$$$$$\  $$$$$$$$\  $$$$$$\  $$$$$$$\  $$\       $$$$$$\ $$\   $$\ $$$$$$$$\
-- $$  __$$\ $$  _____|$$  __$$\ $$  __$$\ $$ |      \_$$  _|$$$\  $$ |$$  _____|
-- $$ |  $$ |$$ |      $$ /  $$ |$$ |  $$ |$$ |        $$ |  $$$$\ $$ |$$ |
-- $$$$$$$  |$$$$$\    $$$$$$$$ |$$ |  $$ |$$ |        $$ |  $$ $$\$$ |$$$$$\
-- $$  __$$< $$  __|   $$  __$$ |$$ |  $$ |$$ |        $$ |  $$ \$$$$ |$$  __|
-- $$ |  $$ |$$ |      $$ |  $$ |$$ |  $$ |$$ |        $$ |  $$ |\$$$ |$$ |
-- $$ |  $$ |$$$$$$$$\ $$ |  $$ |$$$$$$$  |$$$$$$$$\ $$$$$$\ $$ | \$$ |$$$$$$$$\
-- \__|  \__|\________|\__|  \__|\_______/ \________|\______|\__|  \__|\________|
--------------------------------------------------------------------------------

local function execute_command(str)
    if str == nil or str == '' then
        return
    end

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

local function linehandler(str)
    if str == nil or str == '' then
        return
    end

    readline.add_history(str)
    execute_command(str)
end

--------------------------------------------------------------------------------
-- $$$$$$\ $$\   $$\  $$$$$$\ $$$$$$$$\ $$$$$$\ $$$$$$$$\ $$\     $$\
-- \_$$  _|$$$\  $$ |$$  __$$\\__$$  __|\_$$  _|$$  _____|\$$\   $$  |
--   $$ |  $$$$\ $$ |$$ /  $$ |  $$ |     $$ |  $$ |       \$$\ $$  /
--   $$ |  $$ $$\$$ |$$ |  $$ |  $$ |     $$ |  $$$$$\      \$$$$  /
--   $$ |  $$ \$$$$ |$$ |  $$ |  $$ |     $$ |  $$  __|      \$$  /
--   $$ |  $$ |\$$$ |$$ |  $$ |  $$ |     $$ |  $$ |          $$ |
-- $$$$$$\ $$ | \$$ | $$$$$$  |  $$ |   $$$$$$\ $$ |          $$ |
-- \______|\__|  \__| \______/   \__|   \______|\__|          \__|
--------------------------------------------------------------------------------

local function scan(fd, path, watched, files, max_depth, depth)
    if max_depth and depth > max_depth then
        return
    end

    local wd = inotify.add_watch(fd, path.path, bit.bor(inotify.IN_CREATE, inotify.IN_DELETE, inotify.IN_MODIFY))
    assert(wd > 0, "Inotify add watch failed. Does the directory " .. path.path .. " exist?")
    watched[wd] = path.path

    for file in list_dir(path.path) do
        if file ~= "." and file ~= ".." then
            local path = dir(path):join(file)
            local mode = attributes(path.path, "mode")
            if mode == "directory" then
                scan(dir(path), watched, files, max_depth, depth and depth + 1)
            else
                local _, name, _ = utils.split_path(path.path)
                files[name] = path.path
            end
        end
    end
    print('Adding watch to ' .. path.path)
end

--------------------------------------------------------------------------------
-- $$\      $$\  $$$$$$\  $$$$$$\ $$\   $$\
-- $$$\    $$$ |$$  __$$\ \_$$  _|$$$\  $$ |
-- $$$$\  $$$$ |$$ /  $$ |  $$ |  $$$$\ $$ |
-- $$\$$\$$ $$ |$$$$$$$$ |  $$ |  $$ $$\$$ |
-- $$ \$$$  $$ |$$  __$$ |  $$ |  $$ \$$$$ |
-- $$ |\$  /$$ |$$ |  $$ |  $$ |  $$ |\$$$ |
-- $$ | \_/ $$ |$$ |  $$ |$$$$$$\ $$ | \$$ |
-- \__|     \__|\__|  \__|\______|\__|  \__|
--------------------------------------------------------------------------------

-- entry point
local function main()
    local parser = argparse()

    parser:flag('--version', 'Print version')
    parser:flag('-v --verbose', 'Verbose output', false)

    parser:option('-c --config', 'Configuration file', 'vbuild.config')
    parser:option('-f --file', 'File containing list of commands to run')
    parser:flag('-q --quit', 'Quit after running the commands', false)

    local args = parser:parse()

    if args.version then
        print(vbuild.__version)
        os.exit(0)
    end

    if args.quit and not args.file then
        print("Error: --quit flag requires --file flag")
        os.exit(1)
    end

    -- read configuration file
    local config_file = dir(args.config, true)
    parsed_config = read_config_file(config_file)

    -- initialize plugins
    local ok, plugins = pcall(load_plugins)
    if not ok then
        -- in this case plugins is the error message
        print("Error loading plugins ... ")
        print(plugins)
        -- reset plugins to nil so that checking plugins == nil actually tells
        -- if there was an error loading plugins
        plugins = nil
    end

    -- merge configurations
    if parsed_config then
        utils.replace(parsed_config, config)
    end

    -- stop SIGINT from killing the process.
    signal.signal(signal.SIGINT, function()
        io.stdout:write("Ctrl-C (SIGINT) quit is disabled. Use exit command to exit.")
        io.stdout:flush()
        os.exit()
    end)

    if plugins then
        for i = 1, #plugins do
            local plugin = plugins[i]
            if type(plugin) == "table" and plugin.init then
                plugin.init()
            end
        end
    end

    -- register important commands
    command.register('clear', function()
        io.stdout:write('\27[2J', '\27[H')
        io.stdout:flush()
    end)

    command.register('exit', function()
        exit_loop = true
        readline.handler_remove()
    end)

    -- initialize inotify
    local fd = inotify.init()

    -- scan directories
    for _, v in ipairs(config.Sources.source_dirs) do
        local ok, err = pcall(scan, fd, dir(v, true), watched_dirs, files)
        if err then print(err) end
    end

    for _, v in ipairs(config.Sources.testbench_dirs) do
        local ok, err = pcall(scan, fd, dir(v, true), watched_testbenches, testbenches)
        if err then print(err) end
    end

    -- commands file
    if args.file then
        local file, err = io.open(dir(args.file, true).path, 'r')
        if file == nil then
            print("Error: File " .. args.file .. " not found")
            os.exit(1)
        end

        for line in file:lines() do
            execute_command(line)
            print()
        end
    end

    local fds = {
        [0] = { events = { IN = true } },
        [fd] = { events = { IN = true } }
    }

    local buffer_size = 1024 * (ffi.sizeof("struct inotify_event") + 16)
    local buffer = ffi.new("char[?]", buffer_size)
    local i = 0
    local reserved_words = command.get_keys()
    if args.file and args.quit then
        goto cleanup
    end

    -- initialize readline library
    readline.set_options({ histfile = lfs.currentdir() .. '/.vbuild_history', ignoredups = true })
    readline.set_readline_name("vbuild")

    readline.set_complete_list(reserved_words)
    readline.handler_install("vbuild> ", linehandler)
    while exit_loop == false do
        local events = poll(fds, -1)
        if fds[0].revents and fds[0].revents.IN then
            readline.read_char() -- only if there's something to be read
        elseif fds[fd].revents and fds[fd].revents.IN then
            local len = inotify.read(fd, buffer, buffer_size)
            local i = 0
            while i < len do
                local event = ffi.cast("struct inotify_event *", buffer + i)
                i = i + ffi.sizeof("struct inotify_event") + event.len

                local from_tb = watched_dirs[event.wd] == nil
                local watched = from_tb and watched_testbenches or watched_dirs
                local files = from_tb and testbenches or files

                local filename = ffi.string(event.name)
                local path = dir(watched[event.wd]):join(filename)
                local _, stem, ext = utils.split_path(filename)
                local is_directory = bit.band(event.mask, inotify.IN_ISDIR) == inotify.IN_ISDIR

                if bit.band(event.mask, inotify.IN_CREATE) == inotify.IN_CREATE then
                    if is_directory then
                        scan(fd, dir(path, true), watched, files)
                    elseif ext == ".v" then
                        files[stem] = path.path
                    end
                elseif bit.band(event.mask, inotify.IN_DELETE) == inotify.IN_DELETE then
                    if is_directory then
                        -- watch already removed as the directory is deleted
                    elseif ext == ".v" then
                        files[stem] = nil
                    end
                elseif bit.band(event.mask, inotify.IN_IGNORED) == inotify.IN_IGNORED then
                    watched[event.wd] = nil
                end
            end
        end
    end

    ::cleanup::

    -- cleanup
    readline.save_history()

    -- close inotify
    inotify.close(fd)

    -- remove watches
    for k, _ in pairs(watched_dirs) do
        inotify.rm_watch(fd, k)
    end

    for k, _ in pairs(watched_testbenches) do
        inotify.rm_watch(fd, k)
    end

    -- no silly % symbol at the end of the prompt
    io.stdout:write()
end

-- run the entry point
main()
