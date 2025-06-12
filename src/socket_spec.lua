local a = require("src.lib")
local socket = require("socket")

describe("socket", function()
    it("echo", function()
        local host = "127.0.0.1"
        local port = 8080

        local server_socket = socket.bind(host, port)
        local client_socket = socket.tcp()

        local ok, err = client_socket:connect(host, port)
        assert(ok, err)

        local echo_socket, err = server_socket:accept()
        assert(echo_socket, err)

        client_socket:settimeout(0)
        echo_socket:settimeout(0)

        local callbacks = {}

        local async_recv = a.wrap(function(sock, cb)
            callbacks[sock] = function()
                local byte, err = sock:receive(1)
                assert(byte, err)
                callbacks[sock] = nil
                cb(byte)
            end
        end)

        local client = a.sync(function(sock)
            local number = 1

            local ok, err = sock:send(string.char(number))
            assert(ok, err)

            while true do
                number = assert(string.byte(a.wait(async_recv(sock))))

                if number == 100 then
                    break
                else
                    number = number + 1
                end

                local ok, err = sock:send(string.char(number))
                assert(ok, err)
            end

            return number
        end)

        local server = a.sync(function(sock)
            while true do
                local val, err = a.wait(async_recv(sock))
                assert(val, err)
                local ok, err = sock:send(val)
                assert(ok, err)
            end
        end)

        local main = a.sync(function()
            return a.wait_race(client(client_socket), server(echo_socket))
        end)

        local result = nil
        main()(function(...) result = ... end)

        repeat
            local read_set = {}
            for sock, _ in pairs(callbacks) do
                table.insert(read_set, sock)
            end

            local read_ready, _, err = socket.select(read_set)
            assert(read_ready, err)

            for _, sock in ipairs(read_ready) do
                callbacks[sock]()
            end
        until result

        client_socket:close()
        echo_socket:close()
        server_socket:close()

        assert.are.equal(100, result[1])
    end)
end)
