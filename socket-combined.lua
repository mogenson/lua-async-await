-- server_select.lua
local socket = require("socket")

-- Server configuration
local host = "127.0.0.1"
local port = 8080

-- Create a TCP server socket
local server = socket.bind(host, port)

print("Server listening on ", host, port)

local sender_client = socket.tcp()

print("Attempting to connect to ", host, port)

local ok, err = sender_client:connect(host, port)
if not ok then
    print("Failed to connect ", err)
    os.exit(-1)
else
    print("Connected to server")
end

-- Try to accept a new connection
local echo_client, err = server:accept()

if not echo_client then
    print("Failed to accept connection ", err)
    os.exit(-1)
end

print("Client connected!")
local run = true

local callbacks = {}
callbacks[echo_client] = function(sock)
    local data, err = sock:receive(1)
    if data then
        print("Received from client ", sock, string.byte(data))
        local ok, err = sock:send(data)
        if not ok then
            print("Error echoing to client ", sock, err)
            run = false
        end
        print("Echoed back to client ", sock, string.byte(data))
    elseif err == "closed" then
        print("Client disconnected ", sock)
        run = false
    elseif err == "timeout" then
        -- wait for more data
    elseif err then
        print("Error receiving from client ", sock, err)
        run = false
    end
end
callbacks[sender_client] = function(sock)
    local data, err = sock:receive(1)
    if data then
        print("Received from server ", sock, string.byte(data))
        local number = assert(string.byte(data)) + 1
        if number > 100 then
            print("Done!")
            run = false
        else
            print("Sending to server ", sock, number)
            local ok, err = sock:send(string.char(number))
            if not ok then
                print("Error sending to server ", sock, err)
                run = false
            end
        end
    elseif err == "closed" then
        print("Server disconnected ", sock)
        run = false
    elseif err == "timeout" then
        -- wait for more data
    elseif err then
        print("Error receiving from server ", sock, err)
        run = false
    end
end


-- kick things off
print("Sending 1 to server")
local ok, err = sender_client:send(string.char(1))
if not ok then
    print("Error sending to server ", err)
    os.exit(-1)
end

-- set sockets to nonblocking
echo_client:settimeout(0)
sender_client:settimeout(0)

repeat
    local read_set = { echo_client, sender_client }
    local write_set = {}

    -- Wait for activity on any socket, block forever
    local ready_to_read, ready_to_write, err = socket.select(read_set, write_set, nil)

    if err then
        print("Error in select ", err)
        break
    end

    -- Process sockets ready for reading
    for _, sock in ipairs(ready_to_read) do
        (callbacks[sock] or function(_) print("no callback for ", sock) end)(sock)
    end
until not run

print("close echo client")
echo_client:close()

print("close sender client")
sender_client:close()

print("close server")
server:close()
