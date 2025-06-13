local a = require("src.lib")
local curl = require("cURL")
local uv = require("luv")

describe("curl", function()
    it("get", function()
        local q = a.queue()

        local request = curl.easy({
            url = "http://httpbin.org/get",
            writefunction = function(str) q:put(str) end
        })

        local collector = a.sync(function(q)
            local vals, val = {}, nil
            repeat
                val = a.wait(q:get())
                table.insert(vals, val or nil)
            until not val
            return table.concat(vals)
        end)

        local response = nil
        collector(q)(function(...) response = ... end)

        request:perform()
        q:put(false) -- end collector
        request:close()

        local expected = '"url": "http://httpbin.org/get"\n}\n'
        assert.are.same("string", type(response))
        assert.are.same(expected, response:sub(- #expected))
    end)

    it("multi", function()
        local q1 = a.queue()
        local q2 = a.queue()

        local request1 = curl.easy({
            url = "http://httpbin.org/get",
            writefunction = function(str) q1:put(str) end
        })

        local request2 = curl.easy({
            url = "http://httpbin.org/get",
            writefunction = function(str) q2:put(str) end,
        })

        request1.queue = q1
        request2.queue = q2

        local collector = a.sync(function(q)
            local vals, val = {}, nil
            repeat
                val = a.wait(q:get())
                table.insert(vals, val or nil)
            until not val
            return table.concat(vals)
        end)

        local main = a.sync(function()
            return a.wait_all(collector(q1), collector(q2))
        end)

        local multi = curl.multi()
        local timer = uv.new_timer()
        local polls = {}

        multi:setopt_socketfunction(function(handle, fd, action)
            timer:stop()

            local function perform(err, events)
                assert(not err, err)

                if events == "r" then
                    multi:socket_action(fd, curl.CSELECT_IN)
                elseif events == "w" then
                    multi:socket_action(fd, curl.CSELECT_OUT)
                end

                while true do
                    local handle, ok, err = multi:info_read()
                    if handle == 0 then break end
                    assert(ok, err)
                    handle.queue:put(false)
                    handle:close()
                end
            end

            local poll = polls[fd]
            if not poll then
                poll = uv.new_poll(fd)
                polls[fd] = poll
            end

            if action == curl.POLL_IN then
                poll:start("r", perform)
            elseif action == curl.POLL_OUT then
                poll:start("w", perform)
            elseif action == curl.POLL_REMOVE then
                poll:stop()
                polls[fd] = nil
            end
        end)

        multi:setopt_timerfunction(function(ms)
            timer:stop()
            if ms < 0 then return end
            timer:start(ms, 0, function() multi:socket_action() end)
        end)

        multi:add_handle(request1)
        multi:add_handle(request2)

        local response1, response2 = nil, nil
        main()(function(...) response1, response2 = ... end)
        uv:run()
        multi:close()

        local expected = '"url": "http://httpbin.org/get"\n}\n'
        assert.are.same("string", type(response1))
        assert.are.same(expected, response1:sub(- #expected))

        assert.are.same("string", type(response2))
        assert.are.same(expected, response2:sub(- #expected))
    end)
end)
