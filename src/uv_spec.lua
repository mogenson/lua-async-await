local a = require("src.lib")
local uv = require("luv")

describe("uv", function()
    it("pipe", function()
        local async_read = a.wrap(function(pipe, cb)
            pipe:read_start(function(err, data)
                assert(not err, err)
                pipe:read_stop()
                cb(data or false)
            end)
        end)

        local async_write = a.wrap(function(pipe, data, cb)
            pipe:write(data, function(err)
                assert(not err, err)
                cb()
            end)
        end)

        local reader = a.sync(function(pipe)
            local vals, val = {}, nil
            repeat
                val = a.wait(async_read(pipe))
                -- print("pipe read ", val)
                table.insert(vals, val or nil)
            until not val
            pipe:close()
            return table.concat(vals)
        end)

        local writer = a.sync(function(pipe)
            for char in string.gmatch("Hello, World", ".") do
                -- print("pipe write ", char)
                a.wait(async_write(pipe, char))
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
end)
