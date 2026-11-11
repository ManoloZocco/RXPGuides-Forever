local T = {}

function T.test_harness_works()
    assert_eq({a = {1, 2}}, {a = {1, 2}})
    local ok = pcall(assert_eq, 1, 2)
    assert(ok == false, "assert_eq(1, 2) must raise")
    local ok2 = pcall(assert_eq, {a = {1}}, {a = {2}})
    assert(ok2 == false, "deep mismatch must raise")
end

return T
