-- refinish-branch-probe.lua
-- ==========================================
-- BRANCH DATA PROBE, v2
-- ==========================================
-- v1 assumed the tree body was plane objects and read one bit of one
-- corner tile instead. The truth, from df.veg.xml (Bay12 original
-- names) and Lua_API.txt on two dimensional arrays:
--
--   tree_info.body is one pointer per z level, each pointing at a
--   flat dim_x * dim_y plane of uint16 tile flags. The documented
--   access idiom is  body:_displace(z).value:_displace(i)
--
-- Tile flag layout, from df.veg.xml (MULTI_TILE_FLAG_*):
--
--   bit  0  trunk
--   bits 1-4 directional branches, the heavy branch tiles
--   bit  5  branches, the light branch tiles   (caps: CAP_RAMP)
--   bit  6  leaves, the twig tier              (caps: CAP_FLOOR)
--   bit  7  blocked by other vegetation
--   bits 8-10 parent direction, topology only, not counted here
--   bit 11  trunk_is_thick, set on diameter 2 and 3 trunk tiles
--
-- Mushroom cap species overload bits 4-6, so their columns read
-- oddly. Expected, not a bug.
--
-- Usage:
--   refinish-branch-probe              full report
--   refinish-branch-probe raws         species table only
--   refinish-branch-probe census       skip the species table
--   refinish-branch-probe census 800   census with a higher tree cap
-- ==========================================

local args = {...}
local print_raws, print_census = true, true
local MAX_TREES = 300
for _, a in ipairs(args) do
    if a == 'raws' then print_census = false end
    if a == 'census' then print_raws = false end
    local n = tonumber(a)
    if n and n > 0 then MAX_TREES = math.floor(n) end
end

-- Bit masks per the layout above. Named here once so every count in
-- this file traces back to df.veg.xml and nowhere else.
local BIT_TRUNK   = 0x0001
local BIT_HEAVY   = 0x001E   -- any of the four directional branch bits
local BIT_LIGHT   = 0x0020
local BIT_TWIG    = 0x0040
local BIT_BLOCKED = 0x0080
local BIT_THICK   = 0x0800


-- ==========================================
-- SECTION 1: SPECIES RAW VALUES
-- ==========================================
-- Same table as v1. Built even when not printed, because the census
-- joins its densities in by species id.
-- ==========================================

local rows = {}
local ok_raws = pcall(function()
    local trees = df.global.world.raws.plants.trees
    for _, p in ipairs(trees) do
        local dens = nil
        pcall(function()
            for _, m in ipairs(p.material) do
                if m.id == 'WOOD' then dens = m.solid_density end
            end
        end)
        rows[#rows + 1] = {
            id = p.id,
            ld = p.light_branch_density,
            hd = p.heavy_branch_density,
            lr = p.light_branch_radius,
            hr = p.heavy_branch_radius,
            th = p.max_trunk_height,
            td = p.max_trunk_diameter,
            br = p.trunk_branching,
            pd = p.trunk_period,
            dens = dens,
        }
    end
end)

if not ok_raws or #rows == 0 then
    print('Could not read df.global.world.raws.plants.trees.')
    print('Is a world loaded?')
    return
end

if print_raws then
    print('')
    print('==========================================')
    print(' SECTION 1: TREE SPECIES RAW VALUES')
    print('==========================================')
    table.sort(rows, function(a, b)
        return (a.ld + a.hd) > (b.ld + b.hd)
    end)
    print(string.format('%-28s %5s %5s %4s %4s %4s %4s %5s %5s %6s',
        'species', 'lt_d', 'hv_d', 'lt_r', 'hv_r', 'trkH', 'trkD',
        'brnch', 'perd', 'wood'))
    print(string.rep('-', 78))
    for _, r in ipairs(rows) do
        print(string.format(
            '%-28s %5d %5d %4d %4d %4d %4d %5d %5d %6s',
            r.id, r.ld, r.hd, r.lr, r.hr, r.th, r.td, r.br, r.pd,
            r.dens and tostring(r.dens) or '-'))
    end
    print(string.format('%d tree species total', #rows))
end

if not print_census then return end


-- ==========================================
-- BODY ACCESS
-- ==========================================
-- The only three functions that touch tree memory. Everything else
-- is arithmetic on what these return.
-- ==========================================

-- First tile of level z, or nil when the level pointer is null or
-- the walk fails. body is exactly what tree_info.body hands back.
local function plane_first(body, z)
    local ok, first = pcall(function()
        return body:_displace(z).value
    end)
    if ok then return first end
    return nil
end

-- Tile i of a plane whose first tile is known. Step is the natural
-- object size, two bytes for a uint16 bitfield.
local function tile_at(first, i)
    if i == 0 then return first end
    local ok, t = pcall(function() return first:_displace(i) end)
    if ok then return t end
    return nil
end

-- Raw uint16 of a tile. whole is the standard DFHack bitfield read;
-- the fallback assembles the same number from named flags so the
-- probe still works if whole is unavailable in this build.
local function tile_whole(t)
    local ok, w = pcall(function() return t.whole end)
    if ok and type(w) == 'number' then return w end
    local v = 0
    ok = pcall(function()
        if t.trunk then v = v + BIT_TRUNK end
        if t.branch_w then v = v + 0x0002 end
        if t.branch_n then v = v + 0x0004 end
        if t.branch_e then v = v + 0x0008 end
        if t.branch_s then v = v + 0x0010 end
        if t.branches then v = v + BIT_LIGHT end
        if t.leaves then v = v + BIT_TWIG end
        if t.blocked then v = v + BIT_BLOCKED end
        if t.trunk_is_thick then v = v + BIT_THICK end
    end)
    if ok then return v end
    return nil
end

-- Counts one whole tree. Returns a table of category counts, or nil
-- with an error string when a read fails partway.
local function count_tree(ti)
    local c = { trunk = 0, thick = 0, heavy = 0, light = 0,
                twig = 0, blocked = 0, tiles = 0 }
    local per_plane = ti.dim_x * ti.dim_y
    for z = 0, ti.body_height - 1 do
        local first = plane_first(ti.body, z)
        if first ~= nil then
            for i = 0, per_plane - 1 do
                local t = tile_at(first, i)
                if t == nil then return nil, 'tile walk failed' end
                local w = tile_whole(t)
                if w == nil then return nil, 'tile read failed' end
                if w ~= 0 then
                    c.tiles = c.tiles + 1
                    local band = w % 0x20            -- bits 0-4
                    if band % 2 == 1 then c.trunk = c.trunk + 1 end
                    if band >= 2 then c.heavy = c.heavy + 1 end
                    if math.floor(w / BIT_LIGHT) % 2 == 1 then
                        c.light = c.light + 1
                    end
                    if math.floor(w / BIT_TWIG) % 2 == 1 then
                        c.twig = c.twig + 1
                    end
                    if math.floor(w / BIT_BLOCKED) % 2 == 1 then
                        c.blocked = c.blocked + 1
                    end
                    if math.floor(w / BIT_THICK) % 2 == 1 then
                        c.thick = c.thick + 1
                    end
                end
            end
        end
    end
    return c
end


-- ==========================================
-- SECTION 2: SMOKE TEST, ONE TREE
-- ==========================================
-- Proves the access path on a single tree with visible numbers
-- before the census runs on hundreds.
-- ==========================================

print('')
print('==========================================')
print(' SECTION 2: SMOKE TEST, ONE TREE')
print('==========================================')

local plants = nil
pcall(function() plants = df.global.world.plants.all end)
if not plants then
    pcall(function() plants = df.global.world.plants end)
end
if not plants then
    print('No map plants vector found. Load a fort map.')
    return
end

local sample, sample_sid = nil, '?'
pcall(function()
    for _, pl in ipairs(plants) do
        if pl.tree_info ~= nil then
            sample = pl
            pcall(function()
                sample_sid =
                    df.global.world.raws.plants.all[pl.material].id
            end)
            break
        end
    end
end)

if not sample then
    print('No standing tree with tree_info on this map.')
    return
end

local ti = sample.tree_info
print(string.format('%s  body %dx%dx%d', sample_sid,
    ti.dim_x, ti.dim_y, ti.body_height))
local c, err = count_tree(ti)
if not c then
    print('Read failed: ' .. tostring(err))
    print('Paste this back; the access idiom needs another pass.')
    return
end
print(string.format(
    'tiles %d  trunk %d (thick %d)  heavy %d  light %d  twig %d'
    .. '  blocked %d',
    c.tiles, c.trunk, c.thick, c.heavy, c.light, c.twig, c.blocked))


-- ==========================================
-- SECTION 3: STANDING TREE CENSUS
-- ==========================================
-- Averages per species beside that species' raw densities, plus the
-- canopy spread between the smallest and largest individual, which
-- is the part that shows trees are individuals rather than copies
-- of their raws.
-- ==========================================

print('')
print('==========================================')
print(' SECTION 3: STANDING TREE CENSUS')
print('==========================================')

local species = {}
local scanned, errored = 0, 0

pcall(function()
    for _, pl in ipairs(plants) do
        if scanned >= MAX_TREES then break end
        if pl.tree_info ~= nil then
            local sid = '?'
            pcall(function()
                sid = df.global.world.raws.plants.all[pl.material].id
            end)
            local cc = select(1, count_tree(pl.tree_info))
            if cc then
                local b = species[sid]
                if not b then
                    b = { n = 0, trunk = 0, thick = 0, heavy = 0,
                          light = 0, twig = 0, blocked = 0,
                          cmin = nil, cmax = nil }
                    species[sid] = b
                end
                b.n = b.n + 1
                b.trunk = b.trunk + cc.trunk
                b.thick = b.thick + cc.thick
                b.heavy = b.heavy + cc.heavy
                b.light = b.light + cc.light
                b.twig = b.twig + cc.twig
                b.blocked = b.blocked + cc.blocked
                local canopy = cc.heavy + cc.light + cc.twig
                if not b.cmin or canopy < b.cmin then
                    b.cmin = canopy
                end
                if not b.cmax or canopy > b.cmax then
                    b.cmax = canopy
                end
                scanned = scanned + 1
            else
                errored = errored + 1
            end
        end
    end
end)

if scanned == 0 then
    print(string.format('No trees counted, %d failed.', errored))
    return
end

local raw_by_id = {}
for _, r in ipairs(rows) do raw_by_id[r.id] = r end

print(string.format(
    '%-22s %4s %4s %4s %7s %6s %6s %6s %6s %5s %11s',
    'species', 'n', 'lt_d', 'hv_d', 'trunk', 'thick', 'heavy',
    'light', 'twig', 'blkd', 'canopy m-M'))
print(string.rep('-', 92))

local sids = {}
for sid in pairs(species) do sids[#sids + 1] = sid end
table.sort(sids)

for _, sid in ipairs(sids) do
    local b = species[sid]
    local raw = raw_by_id[sid]
    print(string.format(
        '%-22s %4d %4s %4s %7.1f %6.1f %6.1f %6.1f %6.1f %5.1f'
        .. ' %5d-%-5d',
        sid, b.n,
        raw and tostring(raw.ld) or '-',
        raw and tostring(raw.hd) or '-',
        b.trunk / b.n, b.thick / b.n, b.heavy / b.n,
        b.light / b.n, b.twig / b.n, b.blocked / b.n,
        b.cmin or 0, b.cmax or 0))
end

print(string.rep('-', 92))
print(string.format(
    '%d trees scanned, %d failed, cap %d. Columns are average tiles'
    .. ' per tree.', scanned, errored, MAX_TREES))
print('canopy m-M is the smallest and largest individual by heavy')
print('plus light plus twig tiles, the spread between real trees of')
print('the same species.')
