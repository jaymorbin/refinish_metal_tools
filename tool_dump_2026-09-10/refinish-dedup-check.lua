--@ module = true
-- refinish-dedup-check.lua
-- ==========================================
-- ENTITY_RAW DEDUP CHECK
-- ==========================================
-- Read only. Changes nothing.
--
-- Two files dedupe the civ loop differently:
--
--   refinish-boot.lua:610                 keyed on entity_raw.code
--   refinish-module-evaluate-permissions  keyed on the entity_raw
--                                         object itself
--
-- Boot reports 6 unique raws. The evaluator emits six identical
-- rejection lines for one reaction and one civ code, which is what
-- you would see if its dedup never matched.
--
-- The suspicion is that DFHack hands back a fresh Lua wrapper on each
-- access to civ.entity_raw, so using it as a table key compares
-- wrappers rather than the underlying pointer.
--
-- This counts the same civ list three ways. If the object count is
-- higher than the code count, the evaluator's dedup does not work.
-- ==========================================

print("")
print("ENTITY_RAW DEDUP CHECK")
print(string.rep("=", 62))

local total_civs   = 0
local by_object    = {}
local by_code      = {}
local n_object     = 0
local n_code       = 0

for _, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
        total_civs = total_civs + 1

        -- Strategy A: key on the entity_raw object, as the evaluator does.
        if not by_object[civ.entity_raw] then
            by_object[civ.entity_raw] = true
            n_object = n_object + 1
        end

        -- Strategy B: key on the code string, as boot does.
        local code = civ.entity_raw.code
        if not by_code[code] then
            by_code[code] = true
            n_code = n_code + 1
        end
    end
end

print("")
print(string.format("  civilizations scanned      : %d", total_civs))
print(string.format("  unique by entity_raw object: %d   (evaluator)", n_object))
print(string.format("  unique by entity_raw.code  : %d   (boot)", n_code))

-- Direct identity test. Find two civs sharing a code and compare their
-- entity_raw both by == and as table keys.
print("")
print("DIRECT IDENTITY TEST")
print(string.rep("-", 62))
local first_of = {}
local done = false
for _, civ in ipairs(df.global.world.entities.all) do
    if not done and civ.type == df.historical_entity_type.Civilization
       and civ.entity_raw then
        local code = civ.entity_raw.code
        if first_of[code] then
            local a, b = first_of[code], civ.entity_raw
            print(string.format("  two civs both coded [%s]", code))
            print(string.format("    a == b                 : %s", tostring(a == b)))
            local t = {}
            t[a] = true
            print(string.format("    t[a]=true then t[b]    : %s", tostring(t[b])))
            done = true
        else
            first_of[code] = civ.entity_raw
        end
    end
end
if not done then
    print("  no two civs share a code in this world; test inconclusive")
end

print("")
print("VERDICT")
print(string.rep("=", 62))
print("  If the object count exceeds the code count, or t[b] comes back")
print("  nil, the evaluator's dedup never fires and it is doing the whole")
print("  gate evaluation once per civ instead of once per raw.")
print("")
print("  Injection stays correct either way: the 'already permitted'")
print("  check further down catches the repeat. The cost is duplicated")
print("  work and rejection counts multiplied by the number of civs")
print("  sharing each raw.")
print("")
