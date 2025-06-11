-- server_select.lua
local socket = require("socket")

-- Server configuration
local host = "127.0.0.1"
local port = 8080

-- Create a TCP server socket
local server = socket.bind(host, port)

print(string.format("Server listening on %s:%d", host, port))

while true do
    -- Try to accept a new connection
    local client, err = server:accept()

    if client then
        print("Client connected!")
        client:settimeout(0) -- set to nonblocking

        local run = true
        repeat
            local read_set = { client }
            local write_set = {}

            -- Wait for activity on any socket
            local ready_to_read, ready_to_write, err = socket.select(read_set, nil, nil) -- block

            if err then
                print(string.format("Error in select: %s", err))
                break
            end

            -- Process sockets ready for reading
            for _, sock in ipairs(ready_to_read) do
                -- Client socket is ready for reading (has data)
                local data, err_receive = sock:receive("*l")

                if data then
                    print(string.format("Received from client %s: %s", tostring(sock), data))
                    -- Echo back the received data, appending a newline
                    local send_ok, send_err = sock:send(data .. "\n")
                    if not send_ok then
                        print(string.format("Error echoing to client %s: %s", tostring(sock), send_err))
                        run = false
                    end
                    print(string.format("Echoed back to client %s: %s (with newline)", tostring(sock), data))
                elseif err_receive == "closed" then
                    print(string.format("Client %s disconnected.", tostring(sock)))
                    run = false
                elseif err_receive == "timeout" then
                    -- No data yet, but select indicated it was ready. This can happen
                    -- with non-blocking sockets if select indicated *some* activity
                    -- but not necessarily a full line yet. Can also happen if data
                    -- arrived between select and receive.
                    -- Do nothing, wait for more data.
                elseif err_receive then
                    print(string.format("Error receiving from client %s: %s", tostring(sock), err_receive))
                    run = false
                end
            end
        until not run

        print("close client")
        client:close()
    end
end

server:close()
print("Server stopped.")
