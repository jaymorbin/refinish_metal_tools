-- refinish-fuel-trace.lua
-- ==========================================
-- FUEL CHAIN TRACER
-- ==========================================
-- Read only. Walks every link of the fuel access chain in the LIVE
-- game and prints a verdict at each, so a red menu localises to one
-- named link instead of a guess. Run it, paste the output.
--
--   1. Is RM active, is the tuning loaded, what do the tiers say
--   2. What classes builtin COAL actually carries, read correctly
--   3. Census of every item carrying a FUEL* class, with the flags
--      that would disqualify it from the availability scan
--   4. Per furnace: the tier it resolves to, and whether the scan
--      would find fuel for it, with the reason
--   5. Key census: every coal bar with artifact or hidden set
--   6. What building panel is open right now
--
-- The scan logic here is a verbatim copy of fuel-access's, on
-- purpose: if this says WHITE and the menu says red, the break is
-- between the scan and the key, not in the scan.
-- ==========================================

local out = {}
local function p(s) table.insert(out, s) end

-- ---- 1. MODULE STATE ----
p('==========================================')
p(' 1. MODULE STATE')
p('==========================================')
p('  _G.refinish_active     : ' .. tostring(_G.refinish_active))

local T = {}
local ok_t = pcall(function()
    T = reqscript('making-fuel-tuning').T
end)
p('  tuning loaded          : ' .. tostring(ok_t))
p('  FUEL_ACCESS_ENABLED    : ' .. tostring(T.FUEL_ACCESS_ENABLED))
p('  FUEL_CLASS             : ' .. tostring(T.FUEL_CLASS))
p('  FUEL_SMITH_CLASS       : ' .. tostring(T.FUEL_SMITH_CLASS))
p('  FUEL_VECTOR            : ' .. tostring(T.FUEL_VECTOR))
local tiers = T.FUEL_TIERS or {}
for k, v in pairs(tiers) do
    p(string.format('  tier %-18s : class %s, item %s',
        '"' .. k .. '"', tostring(v.class),
        tostring(v.item_type or 'any')))
end

-- ---- helpers, verbatim logic ----
local function rc_value(s)
    local v = nil
    pcall(function() v = tostring(s.value) end)
    return v
end

local function classes_of(mat)
    local t = {}
    pcall(function()
        for _, s in ipairs(mat.reaction_class) do
            table.insert(t, rc_value(s) or '?')
        end
    end)
    return t
end

local function item_classes(it)
    local t = {}
    pcall(function()
        local mi = dfhack.matinfo.decode(it)
        if mi and mi.material then t = classes_of(mi.material) end
    end)
    return t
end

local function has(list, cls)
    for _, c in ipairs(list) do if c == cls then return true end end
    return false
end

local function blocking_flags(it)
    local bad = {}
    pcall(function()
        local f = it.flags
        for _, name in ipairs({ 'hidden', 'forbid', 'dump',
            'garbage_collect', 'in_job', 'removed', 'owned' }) do
            if f[name] then table.insert(bad, name) end
        end
    end)
    return bad
end

-- ---- 2. BUILTIN COAL ----
p('')
p('==========================================')
p(' 2. BUILTIN COAL CLASSES (read via .value)')
p('==========================================')
local coal_classes = {}
pcall(function()
    local m = df.global.world.raws.mat_table
        .builtin[df.builtin_mats.COAL]
    coal_classes = classes_of(m)
end)
p('  [' .. table.concat(coal_classes, ', ') .. ']')
p('  FUEL present          : '
    .. tostring(has(coal_classes, tostring(T.FUEL_CLASS))))
p('  smith class present   : '
    .. tostring(has(coal_classes, tostring(T.FUEL_SMITH_CLASS))))

-- ---- 3. FUEL ITEM CENSUS ----
p('')
p('==========================================')
p(' 3. FUEL ITEM CENSUS (IN_PLAY)')
p('==========================================')
local vec = nil
pcall(function() vec = df.global.world.items.other.IN_PLAY end)
if not vec then
    p('  IN_PLAY vector MISSING, falling back to items.all')
    vec = df.global.world.items.all
end
local census = {}
local totals = {}
pcall(function()
    for _, it in ipairs(vec) do
        local cl = item_classes(it)
        local fuelish = {}
        for _, c in ipairs(cl) do
            if c:find('FUEL', 1, true) == 1 then
                table.insert(fuelish, c)
            end
        end
        if #fuelish > 0 then
            local d, ty = '?', '?'
            pcall(function()
                d = dfhack.items.getDescription(it, 0)
            end)
            pcall(function()
                ty = tostring(df.item_type[it:getType()])
            end)
            local bad = blocking_flags(it)
            table.insert(census, string.format(
                '  id=%-6d %-24s %-8s [%s]%s',
                it.id, d, ty, table.concat(fuelish, ','),
                #bad > 0 and ('  BLOCKED: ' ..
                    table.concat(bad, ',')) or ''))
            for _, c in ipairs(fuelish) do
                totals[c] = (totals[c] or 0) + (#bad == 0 and 1 or 0)
            end
        end
    end
end)
if #census == 0 then
    p('  NO items carry any FUEL* class. Every menu SHOULD be red.')
else
    for i, line in ipairs(census) do
        if i <= 25 then p(line) end
    end
    if #census > 25 then
        p('  ... ' .. (#census - 25) .. ' more')
    end
    p('  usable totals:')
    for c, n in pairs(totals) do
        p(string.format('    %-16s %d', c, n))
    end
end

-- ---- 4. PER FURNACE VERDICTS ----
p('')
p('==========================================')
p(' 4. PER BUILDING VERDICTS')
p('==========================================')
local function spec_for_building(b)
    local spec = { class = T.FUEL_CLASS }
    local map = tiers
    if not map or not next(map) or not b then return spec, '?' end
    local name = '?'
    pcall(function()
        local cls = b:getType()
        if cls == df.building_type.Furnace then
            name = tostring(df.furnace_type[b.type])
        elseif cls == df.building_type.Workshop then
            name = tostring(df.workshop_type[b.type])
        end
    end)
    local hit = map[name]
    if hit then
        if hit.class then spec.class = hit.class end
        spec.item_type = hit.item_type
    end
    return spec, name
end

local function scan(spec)
    local cls = spec.class
    local want = spec.item_type and df.item_type[spec.item_type]
    local n = 0
    pcall(function()
        for _, it in ipairs(vec) do
            local usable = #blocking_flags(it) == 0
            if usable and want then
                local t = nil
                pcall(function() t = it:getType() end)
                if t ~= want then usable = false end
            end
            if usable and has(item_classes(it), cls) then
                n = n + 1
            end
        end
    end)
    return n
end

pcall(function()
    for _, b in ipairs(df.global.world.buildings.all) do
        local bt = b:getType()
        if bt == df.building_type.Furnace
           or bt == df.building_type.Workshop then
            local spec, name = spec_for_building(b)
            if name == 'Smelter' or name == 'Kiln'
               or name == 'GlassFurnace' or name == 'WoodFurnace'
               or name == 'MetalsmithsForge'
               or tiers[name] then
                local n = scan(spec)
                p(string.format(
                    '  id=%-3d %-18s tier: %s/%s  usable fuel: %d'
                    .. '  -> should be %s',
                    b.id, name, tostring(spec.class),
                    tostring(spec.item_type or 'any'), n,
                    n > 0 and 'WHITE' or 'RED'))
            end
        end
    end
end)

-- ---- 5. KEY CENSUS ----
p('')
p('==========================================')
p(' 5. KEY CENSUS (all coal bars)')
p('==========================================')
local found_key = 0
pcall(function()
    for _, it in ipairs(df.global.world.items.all) do
        local isc = false
        pcall(function()
            isc = it:getType() == df.item_type.BAR
                and it.mat_type == df.builtin_mats.COAL
        end)
        if isc then
            found_key = found_key + 1
            local f = it.flags
            p(string.format(
                '  id=%-6d artifact=%s hidden=%s forbid=%s'
                .. ' in_job=%s pos=%d,%d,%d',
                it.id, tostring(f.artifact), tostring(f.hidden),
                tostring(f.forbid), tostring(f.in_job),
                it.pos.x, it.pos.y, it.pos.z))
        end
    end
end)
if found_key == 0 then
    p('  NO coal bars exist. pressable() has nothing to count:')
    p('  every fuel menu is red REGARDLESS of the scan above.')
    p('  If section 4 says WHITE, the break is key minting.')
end

-- ---- 6. VIEW STATE ----
p('')
p('==========================================')
p(' 6. VIEW STATE')
p('==========================================')
pcall(function()
    local vs = df.global.game.main_interface.view_sheets
    p('  view_sheets.open       : ' .. tostring(vs.open))
    p('  viewing_bldid          : ' .. tostring(vs.viewing_bldid))
end)

print(table.concat(out, '\n'))
