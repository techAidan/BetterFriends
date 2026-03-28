-- Minimal test runner for BetterFriends addon
-- No external dependencies required, runs on plain Lua 5.1

local passed = 0
local failed = 0
local errors = {}
local currentSuite = ""

function describe(name, fn)
    currentSuite = name
    io.write("\n" .. name .. "\n")
    fn()
end

function it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        io.write("  PASS: " .. name .. "\n")
    else
        failed = failed + 1
        local msg = currentSuite .. " > " .. name .. ": " .. tostring(err)
        table.insert(errors, msg)
        io.write("  FAIL: " .. name .. "\n")
        io.write("        " .. tostring(err) .. "\n")
    end
end

function expect(value)
    local expectation = {}

    function expectation.toBe(expected)
        if value ~= expected then
            error("Expected " .. tostring(expected) .. " but got " .. tostring(value), 2)
        end
    end

    function expectation.toEqual(expected)
        -- Deep equality for tables
        if type(value) == "table" and type(expected) == "table" then
            local function deepEqual(a, b)
                if type(a) ~= type(b) then return false end
                if type(a) ~= "table" then return a == b end
                for k, v in pairs(a) do
                    if not deepEqual(v, b[k]) then return false end
                end
                for k, v in pairs(b) do
                    if not deepEqual(v, a[k]) then return false end
                end
                return true
            end
            if not deepEqual(value, expected) then
                error("Tables are not deeply equal", 2)
            end
        else
            if value ~= expected then
                error("Expected " .. tostring(expected) .. " but got " .. tostring(value), 2)
            end
        end
    end

    function expectation.toBeNil()
        if value ~= nil then
            error("Expected nil but got " .. tostring(value), 2)
        end
    end

    function expectation.toNotBeNil()
        if value == nil then
            error("Expected non-nil value but got nil", 2)
        end
    end

    function expectation.toBeTruthy()
        if not value then
            error("Expected truthy value but got " .. tostring(value), 2)
        end
    end

    function expectation.toBeFalsy()
        if value then
            error("Expected falsy value but got " .. tostring(value), 2)
        end
    end

    function expectation.toBeGreaterThan(expected)
        if not (value > expected) then
            error("Expected " .. tostring(value) .. " > " .. tostring(expected), 2)
        end
    end

    function expectation.toContain(expected)
        if type(value) == "string" then
            if not value:find(expected, 1, true) then
                error("Expected string to contain '" .. expected .. "' but got '" .. value .. "'", 2)
            end
        elseif type(value) == "table" then
            for _, v in ipairs(value) do
                if v == expected then return end
            end
            error("Expected table to contain " .. tostring(expected), 2)
        else
            error("toContain requires string or table, got " .. type(value), 2)
        end
    end

    function expectation.toBeType(expectedType)
        if type(value) ~= expectedType then
            error("Expected type " .. expectedType .. " but got " .. type(value), 2)
        end
    end

    return expectation
end

-- Run at end of script
function printResults()
    io.write("\n" .. string.rep("-", 40) .. "\n")
    io.write("Results: " .. passed .. " passed, " .. failed .. " failed\n")
    if #errors > 0 then
        io.write("\nFailures:\n")
        for _, err in ipairs(errors) do
            io.write("  " .. err .. "\n")
        end
    end
    io.write(string.rep("-", 40) .. "\n")
    return failed == 0
end

-- Exit with proper code
function exitWithResults()
    if printResults() then
        os.exit(0)
    else
        os.exit(1)
    end
end
