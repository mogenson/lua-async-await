local a = require("src.lib")
local uv = require("luv")

describe("uv", function()
    it("pipe", function()
        local write = a.wrap(uv.write)
        local read = a.wrap(function(pipe, cb)
            pipe:read_start(function(err, data)
                assert(not err, err)
                pipe:read_stop()
                cb(data or false)
            end)
        end)

        local reader = a.sync(function(pipe)
            local vals, val = {}, nil
            repeat
                val = a.wait(read(pipe))
                -- print("pipe read ", val)
                table.insert(vals, val or nil)
            until not val
            pipe:close()
            return table.concat(vals)
        end)

        local writer = a.sync(function(pipe)
            for char in string.gmatch("Hello, World", ".") do
                -- print("pipe write ", char)
                a.wait(write(pipe, char))
            end
            pipe:close()
            return true
        end)

        local fds = uv.pipe({ nonblock = true }, { nonblock = true })

        local read_pipe = uv.new_pipe()
        read_pipe:open(fds.read)

        local write_pipe = uv.new_pipe()
        write_pipe:open(fds.write)

        local main = a.sync(function()
            return a.wait_all(reader(read_pipe), writer(write_pipe))
        end)

        local rx_vals, tx_vals = nil, nil
        main()(function(...) rx_vals, tx_vals = ... end)
        uv.run()

        assert.is_true(tx_vals)
        assert.are.same("Hello, World", rx_vals)
    end)

    it("timer", function()
        local sleep = a.wrap(function(ms, cb)
            local timer = uv.new_timer()
            uv.timer_start(timer, ms, 0, function()
                uv.timer_stop(timer)
                uv.close(timer)
                cb(ms)
            end)
        end)

        local result = nil
        sleep(123)(function(val) result = val end)
        uv.run()
        assert.are.equal(result, 123)

        local main = a.sync(function()
            local start = uv.now()
            a.wait(sleep(1000))
            return uv.now() - start
        end)

        result = nil
        main()(function(val) result = val end)
        uv.run()
        assert(result >= 1000)
    end)

    it("socket", function()
        local host = "127.0.0.1"
        local port = 8080

        local listen = a.wrap(uv.listen)
        local connect = a.wrap(uv.tcp_connect)
        local write = a.wrap(uv.write)
        local read = a.wrap(function(socket, cb)
            socket:read_start(function(err, data)
                assert(not err, err)
                socket:read_stop()
                cb(data or false)
            end)
        end)

        local server = a.sync(function()
            local server_socket = uv.new_tcp()
            server_socket:bind(host, port)
            a.wait(listen(server_socket, 1))
            local echo_socket = uv.new_tcp()
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
            local client_socket = uv.new_tcp()
            a.wait(connect(client_socket, host, port))

            local number = 1
            a.wait(write(client_socket, string.char(number)))

            while true do
                number = assert(string.byte(a.wait(read(client_socket))))
                if number == 100 then
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
        uv.run()

        assert.are.equal(100, result[2])
    end)
end)
