local toml = require("modules.toml")
local inspect = require "modules.inspect"

local config = {
    Plugins = {
        autoload = true,
        path = "plugins"
    },
    Sources = {
        iterative_scan = true,
        source_dirs = { "src" },
        testbench_dirs = { "testbenches" }
    },
}

return config
