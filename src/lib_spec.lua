local a = require("src.lib")
local uv = require("luv")

describe("a", function()
  it("luv-pipe", function()
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

  it("queue", function()
    local q = a.queue()

    local putter = a.sync(function(queue)
      for i = 1, 10 do
        -- print("queue put ", i)
        queue:put(i)
      end
      queue:put(false)
      return true
    end)

    local getter = a.sync(function(queue)
      local vals, val = {}, nil
      repeat
        val = a.wait(queue:get())
        -- print("queue get ", val)
        table.insert(vals, val or nil)
      until not val
      return vals
    end)

    local main = a.sync(function()
      return a.wait_all(getter(q), putter(q))
    end)

    local getter_vals, putter_vals = a.block(main())
    assert.are.same({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, getter_vals)
    assert.is_true(putter_vals)
  end)

  it("channel", function()
    local tx, rx = a.channel()

    local sender = a.sync(function(tx)
      for i = 1, 10 do
        -- print("channelA send ", i)
        a.wait(tx:send(i))
      end
      a.wait(tx:send(false))
      return true
    end)

    local receiver = a.sync(function(rx)
      local vals, val = {}, nil
      repeat
        val = a.wait(rx:recv())
        -- print("channelA recv ", val)
        table.insert(vals, val or nil)
      until not val
      return vals
    end)

    local main = a.sync(function()
      return a.wait_all(sender(tx), receiver(rx))
    end)

    local tx_vals, rx_vals = a.block(main())
    assert.is_true(tx_vals)
    assert.are.same({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, rx_vals)
  end)

  it("channel-reverse", function()
    local tx, rx = a.channel()

    local sender = a.sync(function(tx)
      for i = 1, 10 do
        -- print("channelB send ", i)
        a.wait(tx:send(i))
      end
      a.wait(tx:send(false))
      return true
    end)

    local receiver = a.sync(function(rx)
      local vals, val = {}, nil
      repeat
        val = a.wait(rx:recv())
        -- print("channelB recv ", val)
        table.insert(vals, val or nil)
      until not val
      return vals
    end)

    local main = a.sync(function()
      return a.wait_all(receiver(rx), sender(tx))
    end)

    local rx_vals, tx_vals = a.block(main())
    assert.are.same({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, rx_vals)
    assert.is_true(tx_vals)
  end)

  it("example from the readme", function()
    local greet = a.sync(function()
      return "Hello"
    end)

    local separator = a.wrap(function(cb)
      cb(", ")
    end)

    local main = a.sync(function(name)
      local g = a.wait(greet())
      local s = a.wait(separator())
      return g .. s .. name
    end)

    local result = a.block(main("World"))
    assert.are.equal("Hello, World", result)
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
