-- refinish-building-probe.lua
-- ==========================================
-- BUILDING DEF PERSISTENCE PROBE
-- ==========================================
-- WHAT THIS ANSWERS
--
-- A placed custom building stores custom_type, which is the def's
-- id field (confirmed: getCustomType() returns 2 for the retort,
-- matching buildings.all[2].id).
--
-- Building defs are NOT serialised into the save. They are rebuilt
-- from raws on every load. So an INJECTED building def does not
-- exist at the moment DF loads the save's placed buildings, because
-- RM does not run until SC_MAP_LOADED, which is later.
--
-- The question is whether DF survives that window. This probe puts a
-- placed building into exactly that state by pointing its custom_type
-- at an id no def owns, which is what an injected def looks like
-- before RM arrives.
--
-- USE A THROWAWAY SAVE. If the answer is "does not survive," the
-- placed building in that save is gone.
--
-- COMMANDS
--   status              list defs and placed custom buildings
--   orphan <id>         point the selected building at a dead id
--   restore <id>        put it back
--   unlink <CODE>       remove a def from the arrays without deleting
--
-- Select the building in game before orphan or restore.
-- ==========================================

local args = {...}
local cmd = args[1]


-- ==========================================
-- HELPERS
-- ==========================================

-- Placed buildings live in world.buildings.all. The DEFINITIONS live
-- in world.raws.buildings.all. Two different vectors, one word apart.
local function placed_customs()
    local out = {}
    for _, b in ipairs(df.global.world.buildings.all) do
        -- getCustomType returns -1 on anything that is not a custom
        -- building, which is how vanilla furniture gets filtered out.
        local ok, ct = pcall(function() return b:getCustomType() end)
        if ok and ct and ct >= 0 then
            table.insert(out, { bld = b, custom_type = ct })
        end
    end
    return out
end

-- Every def id currently present, so we can pick one that is free.
local function live_ids()
    local ids = {}
    for _, d in ipairs(df.global.world.raws.buildings.all) do
        ids[d.id] = d.code
    end
    return ids
end


-- ==========================================
-- STATUS
-- ==========================================
-- Prints both sides: what defs exist, and what placed buildings
-- point at. A placed custom_type with no matching def id is the
-- broken state this probe creates on purpose.
-- ==========================================
local function cmd_status()
    print("---- DEFINITIONS (world.raws.buildings.all) ----")
    for i, d in ipairs(df.global.world.raws.buildings.all) do
        print(string.format("  pos %d  id %d  type %d  subtype %d  %s",
            i, d.id, d.building_type, d.building_subtype, d.code))
    end
    print(string.format("  next_id = %d", df.global.world.raws.buildings.next_id))

    local ids = live_ids()
    print("---- PLACED CUSTOM BUILDINGS (world.buildings.all) ----")
    local found = placed_customs()
    if #found == 0 then
        print("  none")
    end
    for _, entry in ipairs(found) do
        local owner = ids[entry.custom_type]
        print(string.format("  building id %d  custom_type %d  -> %s",
            entry.bld.id, entry.custom_type, owner or "*** NO DEF ***"))
    end
end


-- ==========================================
-- ORPHAN
-- ==========================================
-- Writes a dead id onto the selected building. This is the whole
-- test: it is the state an injected building is in during load,
-- before RM injects its def.
-- ==========================================
local function cmd_orphan(target)
    local b = dfhack.gui.getSelectedBuilding()
    if not b then
        print("Select the building in game first.")
        return
    end

    local ids = live_ids()
    if ids[target] then
        print(string.format(
            "id %d belongs to %s. Pick one nothing owns.", target, ids[target]))
        return
    end

    -- custom_type is a plain int32 field on the placed building.
    -- pcall so a field name mismatch reports instead of throwing.
    local ok, err = pcall(function()
        print(string.format("  was custom_type = %d", b.custom_type))
        b.custom_type = target
        print(string.format("  now custom_type = %d", b.custom_type))
    end)
    if not ok then
        print("Could not write custom_type: " .. tostring(err))
        return
    end

    print("Now: quicksave, quit fully, relaunch, load, run 'status'.")
end


-- ==========================================
-- RESTORE
-- ==========================================
-- Points the building back at a real def. If the building survived
-- the reload, this proves RM can repair it after injecting, which
-- is the difference between "needs a repair pass" and "fatal."
-- ==========================================
local function cmd_restore(target)
    local b = dfhack.gui.getSelectedBuilding()
    if not b then
        print("Select the building in game first.")
        return
    end

    local ok, err = pcall(function()
        b.custom_type = target
        print(string.format("  custom_type set to %d", target))
    end)
    if not ok then
        print("Could not write custom_type: " .. tostring(err))
    end
end


-- ==========================================
-- UNLINK
-- ==========================================
-- Removes a def from both vectors it lives in, WITHOUT calling
-- delete(). Same conservative move clear_tools makes: the memory
-- stays valid for the rest of the session, so nothing dereferences
-- freed memory. Only useful for testing the save-WRITE path, since
-- raws rebuild the def on the next load anyway.
-- ==========================================
local function cmd_unlink(code)
    local raws = df.global.world.raws.buildings
    local removed = 0

    -- LIFO, matching every sweep in RM: erasing from the end keeps
    -- earlier positions valid while the loop is still running.
    for _, vec in ipairs({ raws.all, raws.workshops, raws.furnaces }) do
        for i = #vec - 1, 0, -1 do
            if vec[i].code == code then
                vec:erase(i)
                removed = removed + 1
            end
        end
    end

    print(string.format("Unlinked %s from %d vector slots (not deleted).",
        code, removed))
end


-- ==========================================
-- DISPATCH
-- ==========================================

if cmd == 'status' then
    cmd_status()
elseif cmd == 'orphan' then
    cmd_orphan(tonumber(args[2]) or 99)
elseif cmd == 'restore' then
    cmd_restore(tonumber(args[2]) or 2)
elseif cmd == 'unlink' then
    cmd_unlink(args[2])
else
    print("refinish-building-probe status | orphan <id> | restore <id> | unlink <CODE>")
end