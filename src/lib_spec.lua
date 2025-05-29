local a = require("src.lib")
local uv = require("luv")

describe("a", function()
    it("queue", function()
        local q = a.queue()

        local putter = a.sync(function(queue)
            for i = 1, 10 do
                print("queue put ", i)
                queue:put(i)
            end
            queue:put(false)
            return true
        end)

        local getter = a.sync(function(queue)
            local vals, val = {}, nil
            repeat
                val = a.wait(queue:get())
                print("queue get ", val)
                table.insert(vals, val or nil)
            until not val
            return vals
        end)

        local main = a.sync(function()
            return a.wait_all(getter(q), putter(q))
        end)

        local results = nil
        main()(function(...)
            results = { ... }
        end)
        assert.are.same({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, results[1])
        assert.is_true(results[2])
    end)

    it("channel", function()
        local tx, rx = a.channel()

        local sender = a.sync(function(tx)
            for i = 1, 10 do
                print("channel send ", i)
                a.wait(tx:send(i))
            end
            a.wait(tx:send(false))
            return true
        end)

        local receiver = a.sync(function(rx)
            local vals, val = {}, nil
            repeat
                val = a.wait(rx:recv())
                print("channel recv ", val)
                table.insert(vals, val or nil)
            until not val
            return vals
        end)

        local main = a.sync(function()
            return a.wait_all(sender(tx), receiver(rx))
        end)

        local results = nil
        main()(function(...)
            results = { ... }
        end)
        assert.is_true(results[1])
        assert.are.same({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, results[2])
    end)

    it("example from the readme", function()
        local greet = a.sync(function()
            return "Hello"
        end)

        -- You can also use wrap to use nodejs style callbacks.
        local separator = a.wrap(function(cb)
            cb(", ")
        end)

        local main = a.sync(function(name)
            local g = a.wait(greet())
            local s = a.wait(separator())
            return g .. s .. name
        end)

        local calledWith = nil
        main("World")(function(result) calledWith = result end)
        assert.are.equal("Hello, World", calledWith)
    end)

    it("wrap a timer callback to complete a coroutine", function()
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

    it("calls the callback with the return of the function", function()
        local f = a.sync(function()
            return 42
        end)

        local calledWith = nil
        f()(function(n)
            calledWith = n
        end)

        assert.are.equal(42, calledWith)
    end)

    it("passes argument to the function", function()
        local f = a.sync(function(n)
            return n + 1
        end)

        local calledWith = nil
        f(41)(function(n)
            calledWith = n
        end)

        assert.are.equal(42, calledWith)
    end)

    it("wrap provides callback to function", function()
        local f = a.wrap(function(n, cb)
            cb(n + 1)
        end)

        local calledWith = nil
        f(41)(function(n)
            calledWith = n
        end)

        assert.are.equal(42, calledWith)
    end)

    it("await returns result of function", function()
        local foo = a.sync(function(n)
            return n + 1
        end)

        local bar = a.sync(function()
            local from_foo = a.wait(foo(41))
            return from_foo + 1
        end)

        local calledWith = nil
        bar(41)(function(n)
            calledWith = n
        end)

        assert.are.equal(43, calledWith)
    end)

    it("does not call immediately", function()
        local continue = nil
        local foo = a.wrap(function(cb)
            continue = cb
        end)

        local bar = a.sync(function()
            return a.wait(foo())
        end)

        local calledWith = nil
        bar()(function(n)
            calledWith = n
        end)

        assert.are.equal(nil, calledWith)

        continue(42)

        assert.are.equal(42, calledWith)
    end)

    it("joins multiple results", function()
        local continueFoo = nil
        local foo = a.wrap(function(cb)
            continueFoo = cb
        end)

        local continueBar = nil
        local bar = a.wrap(function(cb)
            continueBar = cb
        end)

        local baz = a.sync(function()
            return a.wait_all(foo(), bar())
        end)

        local calledWith = nil
        baz()(function(...)
            calledWith = { ... }
        end)

        assert.are.same(nil, calledWith)

        continueFoo(42)
        assert.are.same(nil, calledWith)

        continueBar(43)
        assert.are.same({ 42, 43 }, calledWith)
    end)

    it("joins multiple results in another order", function()
        local continueFoo = nil
        local foo = a.wrap(function(cb)
            continueFoo = cb
        end)

        local continueBar = nil
        local bar = a.wrap(function(cb)
            continueBar = cb
        end)

        local baz = a.sync(function()
            return a.wait_all(foo(), bar())
        end)

        local calledWith = nil
        baz()(function(...)
            calledWith = { ... }
        end)

        assert.are.same(nil, calledWith)

        continueBar(43)
        assert.are.same(nil, calledWith)

        continueFoo(42)
        assert.are.same({ 42, 43 }, calledWith)
    end)

    it("races two futures", function()
        local continueFoo = nil
        local foo = a.wrap(function(cb)
            continueFoo = cb
        end)

        local continueBar = nil
        local bar = a.wrap(function(cb)
            continueBar = cb
        end)

        local baz = a.sync(function()
            return a.wait_race(foo(), bar())
        end)

        local calledWith = nil
        baz()(function(...)
            calledWith = ...
        end)

        assert.are.same(nil, calledWith)

        continueBar(43)
        assert.are.same({ nil, 43 }, calledWith)
    end)
end)
