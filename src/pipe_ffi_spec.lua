local a    = require("src.lib")
local loop = require("deps.libuv")

describe("pipe_ffi", function()
    it("echo", function()
        local name = "/tmp/test.sock"
        local count = 100

        local listen = a.wrap(function(pipe, backlog, cb)
            pipe:listen(backlog, cb)
        end)
        local connect = a.wrap(function(pipe, host, port, cb)
            pipe:connect(host, port, cb)
        end)
        local write = a.wrap(function(pipe, data, cb)
            pipe:write(data, cb)
        end)
        local read = a.wrap(function(pipe, cb)
            pipe:read_start(function(data)
                pipe:read_stop()
                return cb(data)
            end)
        end)

        local server = a.sync(function()
            local server_pipe = loop:new_pipe()
            server_pipe:bind(name)
            a.wait(listen(server_pipe, 1))
            local echo_pipe = loop:new_pipe()
            server_pipe:accept(echo_pipe)

            while true do
                local data = a.wait(read(echo_pipe))
                if data then
                    a.wait(write(echo_pipe, data))
                else
                    echo_pipe:close()
                    break
                end
            end
            server_pipe:close()
        end)

        local client = a.sync(function()
            local client_pipe = loop:new_pipe()
            a.wait(connect(client_pipe, name))

            local number = 1
            a.wait(write(client_pipe, string.char(number)))

            while true do
                number = assert(string.byte(a.wait(read(client_pipe))))
                if number == count then
                    break
                else
                    number = number + 1
                end
                a.wait(write(client_pipe, string.char(number)))
            end

            client_pipe:close()
            return number
        end)

        os.execute(string.format("rm -f %s", name))

        local main = a.sync(function()
            return a.wait_race(server(), client())
        end)

        local result = nil
        main()(function(...) result = ... end)
        loop:run()

        assert.are.equal(count, result[2])
    end)
end)
