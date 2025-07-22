local a    = require("src.lib")
local loop = require("deps.libuv")

describe("socket_ffi", function()
    it("echo", function()
        local host = "127.0.0.1"
        local port = 8080
        local count = 100

        local listen = a.wrap(function(socket, backlog, cb)
            socket:listen(backlog, cb)
        end)
        local connect = a.wrap(function(socket, host, port, cb)
            socket:connect(host, port, cb)
        end)
        local write = a.wrap(function(socket, data, cb)
            socket:write(data, cb)
        end)
        local read = a.wrap(function(socket, cb)
            socket:read_start(function(data)
                socket:read_stop()
                return cb(data or false)
            end)
        end)

        local server = a.sync(function()
            local server_socket = loop:new_tcp()
            server_socket:bind(host, port)
            a.wait(listen(server_socket, 1))
            local echo_socket = loop:new_tcp()
            server_socket:accept(echo_socket)

            while true do
                local data = a.wait(read(echo_socket))
                if data then
                    a.wait(write(echo_socket, data))
                else
                    echo_socket:close()
                    break
                end
            end
            server_socket:close()
        end)

        local client = a.sync(function()
            local client_socket = loop:new_tcp()
            a.wait(connect(client_socket, host, port))

            local number = 1
            a.wait(write(client_socket, string.char(number)))

            while true do
                number = assert(string.byte(a.wait(read(client_socket))))
                if number == count then
                    break
                else
                    number = number + 1
                end
                a.wait(write(client_socket, string.char(number)))
            end

            client_socket:close()
            return number
        end)

        local main = a.sync(function()
            return a.wait_race(server(), client())
        end)

        local result = nil
        main()(function(...) result = ... end)
        loop:run()

        assert.are.equal(count, result[2])
    end)
end)
