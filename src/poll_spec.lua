local a = require("src.lib")
local posix = require("posix")

describe("posix", function()
    it("echo", function()
        local callbacks = {}

        local read = a.wrap(function(fd, size, cb)
            callbacks[fd] = function()
                local val = posix.read(fd, size)
                callbacks[fd] = nil
                cb(val)
            end
        end)

        local reader = a.sync(function(fd)
            local message = a.wait(read(fd, 256))
            return message
        end)

        local r, w = posix.pipe()

        local message = "Hello, World"
        posix.write(w, message)

        local result = nil
        reader(r)(function(...) result = ... end)

        local fds = { [r] = { events = { IN = true } } }
        posix.poll(fds, -1)
        for fd in pairs(fds) do
            if fds[fd].revents.IN then
                callbacks[fd]()
            end
        end

        assert.are.equal(message, result)
    end)
end)
