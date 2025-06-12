local posix = require 'posix'

print("--- Lua Pipe and poll Example ---")

-- 1. Create a pipe
-- r is the file object for reading, w is for writing
local r, w = posix.pipe()
if not r then
    error("Failed to create pipe")
end

print("Pipe created successfully.")
print("Forking process...")

-- 2. Fork the process
local pid = posix.fork()

if pid == -1 then
    error("Failed to fork")
elseif pid == 0 then
    -- ### 3. CHILD PROCESS (Writer) ###
    print("[Child]  Process started. PID: " .. posix.getpid()["pid"])

    -- The child will only write, so close the read end of the pipe
    posix.close(r)

    -- Wait a moment to ensure the parent is waiting in poll()
    print("[Child]  Sleeping for 1 second...")
    posix.sleep(1)

    local message = "Hello from the child process! Timestamp: " .. os.time()
    print("[Child]  Writing to pipe: '" .. message .. "'")

    -- Write the message to the pipe
    posix.write(w, message)

    -- Close the write end. This sends an EOF to the reader.
    posix.close(w)
    print("[Child]  Pipe closed. Exiting.")
    os.exit()
else
    -- ### 4. PARENT PROCESS (Reader) ###
    print("[Parent] Process started. PID: " .. posix.getpid()["pid"] .. ", Child PID: " .. pid)

    -- The parent will only read, so close the write end of the pipe
    posix.close(w)

    -- Create a fd set for poll(). The keys are the file objects.
    local fds = { [r] = { events = { IN = true } } }

    print("[Parent] Waiting for data using poll()...")

    -- 5. Use poll to wait until the read file descriptor is ready
    -- The call blocks here until the child writes data.
    posix.poll(fds)

    -- 6. Check if our file descriptor is in the returned ready set
    if fds[r].revents.IN then
        print("[Parent] poll() returned. Pipe is ready for reading.")

        -- 7. Read the data from the pipe
        local data = posix.read(r, 256) -- Read up to 256 bytes
        print("[Parent] Read from pipe: '" .. data .. "'")
    else
        print("[Parent] poll() returned, but our pipe was not ready. (This shouldn't happen)")
    end

    -- 8. Clean up
    print("[Parent] Closing pipe and waiting for child to exit.")
    posix.close(r)
    posix.wait(pid) -- Wait for the child to prevent a zombie process

    print("--- Example Finished ---")
end
