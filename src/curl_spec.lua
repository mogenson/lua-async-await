local a = require("src.lib")
local curl = require("cURL")

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

        assert.are.same("string", type(response))
        assert.is_true(#response > 34)
        assert.are.same('"url": "http://httpbin.org/get"\n}\n', response:sub(-34))
    end)
end)
