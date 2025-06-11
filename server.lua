-- server.lua
local socket = require("socket")

-- Server configuration
local host = "127.0.0.1" -- Localhost
local port = 8080        -- Port to listen on

-- Create a TCP server socket
local server = socket.bind(host, port)

print(string.format("Server listening on %s:%d", host, port))

while true do
    -- Try to accept a new connection
    local client, err = server:accept()

    if client then
        print("Client connected!")

        while true do
            -- Receive data from the client
            local data, err = client:receive('*l')

            if data then
                print(string.format("Received from client: %s", data))
                -- Echo back the received data
                client:send(data .. '\n')
                print(string.format("Echoed back: %s", data))
            elseif err == "closed" then
                print("Client disconnected.")
                break
            elseif err then
                -- Handle other errors (e.g., timeout)
                -- print(string.format("Error receiving from client: %s", err))
            end
        end
        client:close() -- Close the client socket
    elseif err == "timeout" then
        -- No incoming connections within the timeout period
        -- print("Waiting for connections...")
    elseif err then
        print(string.format("Error accepting connection: %s", err))
        break
    end
end

server:close() -- Close the server socket when done
print("Server stopped.")
