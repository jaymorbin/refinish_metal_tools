-- refinish-building-check.lua
-- ==========================================
-- CUSTOM BUILDING PERMISSION DIAGNOSTIC
-- ==========================================
-- A raw building can parse cleanly and still never appear in the
-- build menu, because appearing there is a separate thing: the
-- civilisation must list it in
--
--     entity_raw.workshops.permitted_building_id
--
-- That array holds building_def ids. It is the exact counterpart
-- of permitted_reaction_id, which refinish-index-entity already
-- injects. Nothing in RM currently injects the building side.
--
-- USAGE
--   refinish-building-check            report only, changes nothing
--   refinish-building-check inject     grant the missing permissions
--
-- The inject mode is a live test, not a fix. It writes into the
-- entity raw in RAM and is lost on unload. If it makes the
-- workshops appear, the diagnosis is confirmed and the permanent
-- version belongs in refinish-index-entity beside the reaction
-- permission pass.
--
-- SAFETY: injecting a permission is not the same as injecting a
-- building. The building lives in raws, so its id is fixed at
-- worldgen and never moves. This only adds a reference to an
-- index that is already stable, which is why it carries none of
-- the custom_type instability that injecting a building would.
-- ==========================================

local args = {...}
local do_inject = (args[1] == 'inject')

-- Prefix to look for. Every building this module owns starts here.
local PREFIX = "MAKING_FUEL_"


-- ==========================================
-- STEP 1: DID THE RAWS LOAD AT ALL
-- ==========================================
-- If a definition failed to parse it simply will not be in this
-- list, which distinguishes a raw syntax problem from a
-- permission problem.
print("")
print("=== CUSTOM WORKSHOPS PRESENT IN RAWS ===")

local ours = {}
local count = 0
for _, ws in ipairs(df.global.world.raws.buildings.workshops) do
    count = count + 1
    local mine = string.sub(ws.code, 1, #PREFIX) == PREFIX
    if mine then
        table.insert(ours, ws)
        print(string.format("  [%3d]  %-34s  <-- ours", ws.id, ws.code))
    end
end

-- Show a few others for contrast, so an empty "ours" list is
-- obviously a missing definition rather than an empty array.
local shown = 0
for _, ws in ipairs(df.global.world.raws.buildings.workshops) do
    if string.sub(ws.code, 1, #PREFIX) ~= PREFIX and shown < 5 then
        print(string.format("  [%3d]  %s", ws.id, ws.code))
        shown = shown + 1
    end
end
print(string.format("  %d custom workshops total, %d ours.", count, #ours))

if #ours == 0 then
    print("")
    print("  Our definitions are NOT in the raws list.")
    print("  That is a parse or file placement problem, not a")
    print("  permission problem. Stop here.")
    return
end


-- ==========================================
-- STEP 2: WHAT THE PLAYER CIV PERMITS
-- ==========================================
local civ = df.historical_entity.find(df.global.plotinfo.civ_id)
if not civ or not civ.entity_raw then
    print("")
    print("  No player civ resolved. Run this with a fort loaded.")
    return
end

local permitted = civ.entity_raw.workshops.permitted_building_id
local have = {}
for _, bid in ipairs(permitted) do have[bid] = true end

print("")
print(string.format("=== PERMISSIONS FOR [%s] ===", civ.entity_raw.code))
print(string.format("  %d buildings permitted.", #permitted))

local missing = {}
for _, ws in ipairs(ours) do
    local ok = have[ws.id] and "PERMITTED" or "MISSING"
    print(string.format("  %-34s  %s", ws.code, ok))
    if not have[ws.id] then table.insert(missing, ws) end
end

if #missing == 0 then
    print("")
    print("  Everything is already permitted, so an absent build")
    print("  menu entry has some other cause.")
    return
end


-- ==========================================
-- STEP 3: INJECT, ONLY IF ASKED
-- ==========================================
if not do_inject then
    print("")
    print(string.format("  %d building(s) load but are not permitted.", #missing))
    print("  That is why they do not appear in the build menu.")
    print("  Re-run as:  refinish-building-check inject")
    return
end

print("")
print("=== INJECTING ===")
for _, ws in ipairs(missing) do
    local ok, err = pcall(function()
        permitted:insert('#', ws.id)
    end)
    if ok then
        print(string.format("  granted  %s (id %d)", ws.code, ws.id))
    else
        print(string.format("  FAILED   %s -> %s", ws.code, tostring(err)))
    end
end

print("")
print("  Open the build menu and look under the workshop list.")
print("  This is RAM only and will not survive an unload.")
