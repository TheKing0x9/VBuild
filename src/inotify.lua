local ffi = require 'ffi'
local bit = require 'bit'

local C = ffi.C

ffi.cdef([[
struct inotify_event {
    int wd;
    uint32_t mask;
    uint32_t cookie;
    uint32_t len;
    char name[0];
};

int inotify_init(void);
int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
int inotify_rm_watch(int fd, int wd);
int read(int fd, void *buf, size_t count);
int close(int fd);
]])

local inotify            = {}

inotify.IN_ACCESS        = 0x00000001
inotify.IN_MODIFY        = 0x00000002
inotify.IN_ATTRIB        = 0x00000004
inotify.IN_CLOSE_WRITE   = 0x00000008
inotify.IN_CLOSE_NOWRITE = 0x00000010
inotify.IN_CLOSE         = bit.bor(inotify.IN_CLOSE_WRITE, inotify.IN_CLOSE_NOWRITE)
inotify.IN_OPEN          = 0x00000020
inotify.IN_MOVED_FROM    = 0x00000040
inotify.IN_MOVED_TO      = 0x00000080
inotify.IN_MOVE          = bit.bor(inotify.IN_MOVED_FROM, inotify.IN_MOVED_TO)
inotify.IN_CREATE        = 0x00000100
inotify.IN_DELETE        = 0x00000200
inotify.IN_DELETE_SELF   = 0x00000400
inotify.IN_MOVE_SELF     = 0x00000800
inotify.IN_IGNORED       = 0x00008000
inotify.IN_ISDIR         = 0x40000000

function inotify.init()
    local fd = C.inotify_init()
    assert(fd > 0, "inotify_init failed")
    return fd
end

function inotify.add_watch(fd, path, mask)
    return C.inotify_add_watch(fd, path, mask)
end

function inotify.rm_watch(fd, wd)
    return C.inotify_rm_watch(fd, wd)
end

function inotify.read(fd, buf, count)
    return C.read(fd, buf, count)
end

function inotify.close(fd)
    return C.close(fd)
end

return inotify
