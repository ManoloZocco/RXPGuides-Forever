-- Test runner for the fork's pure-Lua modules. Run from the repo root:
--   luajit tests/run.lua            (all tests/test_*.lua)
--   luajit tests/run.lua build      (only files whose name contains "build")
-- Each test file returns { test_name = function() ... end }.
-- Globals created or changed by a test are rolled back after it runs.

package.path = "./?.lua;./tests/?.lua;" .. package.path

local function describe(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

local function deep_compare(a, b, path)
    if type(a) ~= type(b) then
        return false, string.format("%s: type %s ~= %s (%s vs %s)", path, type(a), type(b), describe(a), describe(b))
    end
    if type(a) ~= "table" then
        if a == b then return true end
        return false, string.format("%s: %s ~= %s", path, describe(a), describe(b))
    end
    for k, v in pairs(a) do
        local ok, err = deep_compare(v, b[k], path .. "." .. tostring(k))
        if not ok then return false, err end
    end
    for k, v in pairs(b) do
        if a[k] == nil then
            return false, string.format("%s.%s: missing (expected %s)", path, tostring(k), describe(v))
        end
    end
    return true
end

function assert_eq(actual, expected, msg)
    local ok, err = deep_compare(actual, expected, "value")
    if not ok then error((msg and (msg .. ": ") or "") .. err, 2) end
end

local function snapshot_globals()
    local snap = {}
    for k, v in pairs(_G) do snap[k] = v end
    return snap
end

local function restore_globals(snap)
    for k in pairs(_G) do
        if snap[k] == nil then _G[k] = nil end
    end
    for k, v in pairs(snap) do
        if _G[k] ~= v then _G[k] = v end
    end
end

local filter = arg and arg[1]
local files = {}
local p = io.popen("ls tests/test_*.lua 2>/dev/null")
for line in p:lines() do
    if not filter or line:find(filter, 1, true) then files[#files + 1] = line end
end
p:close()
table.sort(files)

local passed, failed, failures = 0, 0, {}
for _, file in ipairs(files) do
    local fsnap = snapshot_globals()
    local chunk, loadErr = loadfile(file)
    local ok, tests = false, nil
    if chunk then ok, tests = pcall(chunk) else tests = loadErr end
    if not ok or type(tests) ~= "table" then
        failed = failed + 1
        failures[#failures + 1] = file .. " (load): " .. tostring(tests)
    else
        local names = {}
        for name in pairs(tests) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local snap = snapshot_globals()
            local tok, terr = xpcall(tests[name], debug.traceback)
            restore_globals(snap)
            if tok then
                passed = passed + 1
            else
                failed = failed + 1
                failures[#failures + 1] = file .. " :: " .. name .. "\n    " .. tostring(terr):gsub("\n", "\n    ")
            end
        end
    end
    restore_globals(fsnap)
end

for _, f in ipairs(failures) do print("FAIL " .. f) end
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed > 0 and 1 or 0)
