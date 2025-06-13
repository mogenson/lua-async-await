local uv = require('luv')
local curl = require("cURL")

local multi = nil
local timer = nil
local polls = {}

local function clear_timer(timer)
    if uv.is_closing(timer) then return end
    uv.timer_stop(timer)
    uv.close(timer)
end

local function set_timeout(delay, callback)
    local timer = uv.new_timer()
    uv.timer_start(timer, delay, 0, function()
        uv.timer_stop(timer)
        uv.close(timer)
        callback()
    end)
    return timer
end

local function data_function(data)
    print("data function ", data)
end

local function socket_function(handle, fd, action)
    print("socket function ", handle, fd, action)
    clear_timer(timer)

    local function perform(err, events)
        print("perform ", err, events)
        local flag = 0
        if events == "r" then
            flag = curl.CSELECT_IN
        elseif events == "w" then
            flag = curl.CSELECT_OUT
        end

        multi:socket_action(fd, flag)

        while true do
            local handle, ok, err = multi:info_read(true) -- remove handle when done
            if handle == 0 then break end                 -- no more tasks
            if ok then                                    -- success
                print(handle:getinfo_effective_url(), handle:getinfo_response_code())
            else                                          -- failure
                print(handle:getinfo_effective_url(), err)
            end
            handle:close()
        end
    end

    local poll = polls[fd]
    if not poll then
        poll = uv.new_poll(fd)
        polls[fd] = poll
    end

    if action == curl.POLL_IN then
        uv.poll_start(poll, "r", perform)
    elseif action == curl.POLL_OUT then
        uv.poll_start(poll, "w", perform)
    elseif action == curl.POLL_REMOVE then
        uv.poll_stop(poll)
        uv.close(poll)
        polls[fd] = nil
    end
end

local function timer_function(ms)
    print("timer function ", ms)
    if ms < 0 then ms = 1 end
    if timer then clear_timer(timer) end
    local function action()
        print("socket timeout")
        multi:socket_action(curl.SOCKET_TIMEOUT, 0)
    end
    timer = set_timeout(ms, action)
end

multi = curl.multi({
    socketfunction = socket_function,
    timerfunction = timer_function,
})

local request1 = curl.easy()
    :setopt_url("http://www.lua.org/")
    :setopt_writefunction(data_function)

local request2 = curl.easy()
    :setopt_url("http://luajit.org/")
    :setopt_writefunction(data_function)

multi:add_handle(request1)
multi:add_handle(request2)

uv.run()
