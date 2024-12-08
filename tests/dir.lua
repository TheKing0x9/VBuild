local luaunit = require("tests.luaunit")
local dir = require 'src.dir'
local lfs = require 'lfs'

return {
    test_basename = function()
        local d = dir('.', 'dir.lua')
        luaunit.assertEquals(d:basename(), 'dir')
    end,
    test_dirname = function()
        local d = dir('dir.lua')
        luaunit.assertEquals(d:abs():dirname(), lfs.currentdir() .. "/")
        d = dir(lfs.currentdir() .. '/src/log.lua')
        luaunit.assertEquals(d:dirname(), lfs.currentdir() .. '/src/')
    end,
    test_isabs = function()
        local d = dir('/etc')
        luaunit.assertTrue(d:isabs())
        d = dir('src')
        luaunit.assertFalse(d:isabs())
    end,
    test_abs = function()
        local d = dir('src')
        luaunit.assertEquals(d:abs().path, lfs.currentdir() .. '/src')
        luaunit.assertEquals(d:abs():abs().path, lfs.currentdir() .. '/src')
    end,
    test_isdir = function()
        local d = dir('/etc')
        luaunit.assertTrue(d:isdir())
        d = dir('/etc/passwd')
        luaunit.assertFalse(d:isdir())
        d = dir('./src')
        luaunit.assertTrue(d:isdir())
    end,
    test_diradd = function()
        local d = dir(lfs.currentdir())
        local d2 = d / 'src'
        luaunit.assertEquals(d2.path, lfs.currentdir() .. '/src')
    end,
    test_normpath = function()
        local d = dir('./../vbuild/test/../src')
        luaunit.assertEquals(d:norm().path, lfs.currentdir() .. '/src')
    end,
}
