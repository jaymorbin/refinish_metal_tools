-- refinish-coal-key-test.lua
-- ==========================================
-- WHAT SATISFIES THE COAL CHECK
-- ==========================================
-- pressable() is a vmethod: engine code, recomputed every frame,
-- unreachable from Lua. Clearing objection and injecting a clean
-- clone both failed. So the button cannot be fixed; the WORLD
-- STATE it reads has to be satisfied instead.
--
-- The check scans for coal. This finds out exactly which coal it
-- accepts, by putting one bar into each state and letting you look
-- at the menu. If a coal bar that is HIDDEN, FORBIDDEN, ENCASED or
-- otherwise out of play still satisfies it, that bar is a permanent
-- key: it can never be hauled or burned, and because builtin coal
-- carries no reaction class it can never satisfy a widened filter
-- either. Menus stay white, peat does all the burning.
--
-- If only a fully available bar counts, the key must be real coal
-- and we know the true cost of this feature.
--
-- Usage:
--   refinish-coal-key-test list
--       Every coal item in the fort with its flags and position.
--
--   refinish-coal-key-test spawn
--       Create one coal bar at the cursor. Somewhere to experiment
--       without touching your stock.
--
--   refinish-coal-key-test set <id> <flag> <on|off>
--       Flip one flag on one item. Flags: forbid, hidden, dump,
--       melt, in_job, removed, garbage_collect, owned, trader,
--       artifact, on_ground.
--
--   refinish-coal-key-test only <id>
--       Forbid EVERY coal bar except this one. Isolates a single
--       candidate so the menu's answer is unambiguous.
--
--   refinish-coal-key-test allforbid / allfree
--
-- PROTOCOL
--   1. allforbid, open the smelter, confirm orange.
--   2. only <id> on one bar, reopen, confirm white.
--   3. From there set flags on that one bar one at a time,
--      reopening the menu after each, until it goes orange.
--      The flag that flips it is what the check reads.
-- ==========================================

local args = {...}

local FLAGS = {
    forbid = 'forbid', hidden = 'hidden', dump = 'dump',
    melt = 'melt', in_job = 'in_job', removed = 'removed',
    garbage_collect = 'garbage_collect', owned = 'owned',
    trader = 'trader', artifact = 'artifact',
    on_ground = 'on_ground', in_building = 'in_building',
}

local function is_coal(it)
    local hit = false
    pcall(function()
        if it:getType() == df.item_type.BAR
           and it.mat_type == df.builtin_mats.COAL then
            hit = true
        end
    end)
    return hit
end

local function coal_items()
    local out = {}
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if is_coal(it) then table.insert(out, it) end
        end
    end)
    return out
end

local function flagstr(it)
    local set = {}
    for name in pairs(FLAGS) do
        local v = false
        pcall(function() v = it.flags[name] end)
        if v then table.insert(set, name) end
    end
    table.sort(set)
    return #set > 0 and table.concat(set, ',') or '-'
end

local function describe(it)
    local d, x, y, z = '?', -1, -1, -1
    pcall(function() d = dfhack.items.getDescription(it, 0) end)
    pcall(function() x, y, z = it.pos.x, it.pos.y, it.pos.z end)
    return string.format('  id=%-7d %-22s at %d,%d,%d  mat=%s/%s  [%s]',
        it.id, d, x, y, z, tostring(it.mat_type),
        tostring(it.mat_index), flagstr(it))
end

local cmd = args[1]

if cmd == 'list' then
    local c = coal_items()
    print(string.format('COAL KEY: %d coal item(s)', #c))
    for _, it in ipairs(c) do print(describe(it)) end
    if #c == 0 then
        print('  none. spawn one, or the check has nothing to find.')
    end

elseif cmd == 'spawn' then
    local pos = nil
    pcall(function() pos = copyall(df.global.cursor) end)
    if not pos or pos.x < 0 then
        print('COAL KEY: put the cursor somewhere first.')
        return
    end
    local ok, err = pcall(function()
        local u = df.global.world.units.active[0]
        local made = dfhack.items.createItem(
            u, df.item_type.BAR, -1,
            df.builtin_mats.COAL, -1)
        local it = made and made[1]
        if not it then error('createItem returned nothing') end
        dfhack.items.moveToGround(it, pos)
        print('COAL KEY: spawned coal bar id=' .. it.id
            .. ' at ' .. pos.x .. ',' .. pos.y .. ',' .. pos.z)
    end)
    if not ok then print('COAL KEY: spawn failed: ' .. tostring(err)) end

elseif cmd == 'set' and args[2] and args[3] and args[4] then
    local id = tonumber(args[2])
    local fl = FLAGS[args[3]]
    local on = (args[4] == 'on' or args[4] == 'true')
    if not fl then
        print('COAL KEY: unknown flag ' .. tostring(args[3]))
        return
    end
    local it = df.item.find(id)
    if not it then print('COAL KEY: no item ' .. tostring(id)) return end
    local ok = pcall(function() it.flags[fl] = on end)
    print(ok and string.format('COAL KEY: item %d %s = %s  -> [%s]',
            id, fl, tostring(on), flagstr(it))
        or 'COAL KEY: could not set that flag')
    print('  Reopen the workshop menu and look.')

elseif cmd == 'only' and args[2] then
    local keep = tonumber(args[2])
    local n = 0
    for _, it in ipairs(coal_items()) do
        local want = (it.id ~= keep)
        pcall(function() it.flags.forbid = want end)
        if want then n = n + 1 end
    end
    print(string.format(
        'COAL KEY: forbade %d coal bar(s), left id=%d free.', n, keep))
    print('  Reopen the workshop menu and look.')

elseif cmd == 'allforbid' then
    local n = 0
    for _, it in ipairs(coal_items()) do
        pcall(function() it.flags.forbid = true end)
        n = n + 1
    end
    print('COAL KEY: forbade ' .. n .. ' coal bar(s).')

elseif cmd == 'allfree' then
    local n = 0
    for _, it in ipairs(coal_items()) do
        pcall(function() it.flags.forbid = false end)
        n = n + 1
    end
    print('COAL KEY: unforbade ' .. n .. ' coal bar(s).')

else
    print('usage: refinish-coal-key-test'
        .. ' list | spawn | set <id> <flag> <on|off>'
        .. ' | only <id> | allforbid | allfree')
end
