local runner = require("tests.luaunit").LuaUnit:new()
runner:setOutputType("text")

local function testall(suites)
    local instances = {}
    for _, suite in ipairs(suites) do
        local suite = require("tests." .. suite)
        for name, testfn in pairs(suite) do
            table.insert(instances, { name, testfn })
        end
    end
    return runner:runSuiteByInstances(instances)
end

testall({ 'dir' })

os.exit(runner.result.notSuccessCount == 0 and 0 or 1)
