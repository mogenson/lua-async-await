-- client.lua
local socket = require("socket")

-- Server configuration (should match the server's host and port)
local host = "127.0.0.1"
local port = 8080

-- Create a TCP client socket
local client = socket.tcp()

print(string.format("Attempting to connect to %s:%d", host, port))

local ok, err = client:connect(host, port)

if not ok then
    print(string.format("Failed to connect: %s", err))
else
    print("Connected to server.")

    local numbers_sent = {}
    local numbers_received = {}

    -- Send nummbers 1 to 100
    for i = 1, 100 do
        local number_to_send = tostring(i)
        local send_ok, send_err = client:send(number_to_send .. "\n") -- Add newline for easier reading

        if send_ok then
            numbers_sent[i] = number_to_send
            -- print(string.format("Sent: %s", number_to_send))

            -- Receive the echoed data
            local received_data, recv_err = client:receive("*l") -- Read until newline

            if received_data then
                numbers_received[i] = received_data:gsub("%s+", "") -- Remove any trailing whitespace
                -- print(string.format("Received back: %s", received_data:gsub("%s+", "")))
            elseif recv_err then
                print(string.format("Error receiving for %d: %s", i, recv_err))
                break
            end
        else
            print(string.format("Error sending %s: %s", number_to_send, send_err))
            break
        end
    end

    -- Validate that the same numbers were received back
    local validation_successful = true
    for i = 1, 100 do
        if numbers_sent[i] ~= numbers_received[i] then
            print(string.format("Validation failed for number %d: Sent '%s', Received '%s'",
                i, numbers_sent[i], numbers_received[i]))
            validation_successful = false
        end
    end

    if validation_successful then
        print("Validation successful: All numbers echoed back correctly.")
    else
        print("Validation failed: Mismatch in echoed numbers.")
    end

    client:close()
    print("Client disconnected.")
end
