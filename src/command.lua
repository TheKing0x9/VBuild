local command = {}

command.map = {}

function command.get_keys()
    local keys = {}
    for k, _ in pairs(command.map) do
        table.insert(keys, k)
    end
    return keys
end

function command.register(name, func)
    if command.map[name] then
        error("Command already exists: " .. name)
        return
    end
    assert(type(func) == "function", "Command must be a function")

    command.map[name] = func
end

local function execute(name, ...)
    local cmd = command.map[name]
    if cmd then
        cmd(...)
    else
        error('Command not found ' .. name, 0)
    end
end

function command.execute(name, ...)
    local ok, res = pcall(execute, name, ...)
    return not ok and res
end

return command
