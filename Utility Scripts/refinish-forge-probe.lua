-- refinish-forge-probe.lua
-- ==========================================
-- READ ONLY DIAGNOSTIC: DUPLICATE FORGE METALS
-- ==========================================
-- Measures the live state behind the duplicate blue steel bug.
-- Changes nothing. Safe to run any time a fort is loaded.
--
-- WHAT IT REPORTS, IN ORDER:
--   S1  Inorganic census: totals, and every id that appears more
--       than once, or display name shared by more than one id
--   S2  Duplicate detail: per copy, its index, id, names, flags,
--       color channels with the descriptor resolved to its word
--   S3  Steel family listing: every REFINISH_STEEL_ material
--   S4  Module family counts: materials grouped by id prefix
--   S5  Bar census: which mat_index real bars actually carry
--   S6  Color descriptor tail: count plus the last ten entries
--   S7  Forge jobs: queued jobs at every forge with the exact
--       mat_type and mat_index their job_items demand
--
-- USAGE:
--   refinish-forge-probe              full report, dups auto detected
--   refinish-forge-probe blue steel   S2 also details any material
--                                     whose name contains the words
-- ==========================================

local world = df.global.world
local raws = world.raws.inorganics.all
local colors = world.raws.descriptors.colors

-- Optional name filter from the command line, lowercased
local args = {...}
local name_filter = nil
if #args > 0 then
    name_filter = string.lower(table.concat(args, " "))
end

-- ==========================================
-- HELPERS
-- ==========================================

-- Resolve a state_color descriptor index to its word, with
-- bounds checking. An out of range index is itself a finding.
local function color_word(idx)
    if idx == nil then return "nil" end
    if idx < 0 or idx >= #colors then
        return string.format("%d OUT OF RANGE (table has %d)", idx, #colors)
    end
    return string.format("%d %s", idx, colors[idx].id)
end

-- Read the six state name slots defensively. Index order in the
-- struct: 0 Solid, 1 Liquid, 2 Gas, 3 Powder, 4 Paste, 5 Pressed.
local function state_names(mat)
    local out = {}
    for i = 0, 5 do
        local ok, v = pcall(function() return mat.state_name[i] end)
        out[i] = ok and v or "?"
    end
    return out
end

-- Id prefix family: first two underscore separated segments,
-- e.g. MAKING_FUEL, REFINISH_STEEL. Used for the S4 counts.
local function id_family(id)
    local a, b = string.match(id, "^([^_]+)_([^_]+)")
    if a and b then return a .. "_" .. b end
    return "(vanilla or other)"
end

-- ==========================================
-- S1: INORGANIC CENSUS
-- ==========================================
print("==========================================")
print("S1: INORGANIC CENSUS")
print("==========================================")
print(string.format("Total inorganics in raws: %d", #raws))

-- Group every material by id and by lowercased solid display name.
-- Either kind of collision can put duplicate rows in the forge menu.
local by_id = {}
local by_name = {}
for i = 0, #raws - 1 do
    local m = raws[i]
    local id = m.id
    local nm = string.lower(m.material.state_name.Solid or "")

    by_id[id] = by_id[id] or {}
    table.insert(by_id[id], i)

    if nm ~= "" then
        by_name[nm] = by_name[nm] or {}
        table.insert(by_name[nm], i)
    end
end

-- Collect the set of indices that belong to any collision group
local dup_indices = {}
local dup_found = false
for id, list in pairs(by_id) do
    if #list > 1 then
        dup_found = true
        print(string.format("DUP ID: %s appears %d times at indices %s",
            id, #list, table.concat(list, ", ")))
        for _, i in ipairs(list) do dup_indices[i] = true end
    end
end
for nm, list in pairs(by_name) do
    if #list > 1 then
        dup_found = true
        print(string.format("DUP NAME: '%s' shared by %d materials at indices %s",
            nm, #list, table.concat(list, ", ")))
        for _, i in ipairs(list) do dup_indices[i] = true end
    end
end
if not dup_found then
    print("No duplicate ids or display names found in raws.")
    print("If the forge menu still shows repeats, the duplication")
    print("lives in a cached menu list, not in the inorganics array.")
end

-- Fold the optional name filter into the detail set
if name_filter then
    for i = 0, #raws - 1 do
        local nm = string.lower(raws[i].material.state_name.Solid or "")
        if string.find(nm, name_filter, 1, true) then
            dup_indices[i] = true
        end
    end
end

-- ==========================================
-- S2: DUPLICATE DETAIL
-- ==========================================
print("")
print("==========================================")
print("S2: DUPLICATE AND FILTERED MATERIAL DETAIL")
print("==========================================")

-- Sort the detail set so the report reads in index order
local detail = {}
for i in pairs(dup_indices) do table.insert(detail, i) end
table.sort(detail)

if #detail == 0 then
    print("Nothing to detail.")
end

for _, i in ipairs(detail) do
    local m = raws[i]
    local mat = m.material
    local sn = state_names(mat)
    print(string.format("---- index %d ----", i))
    print(string.format("  id: %s", m.id))
    print(string.format("  names 0..5: [%s] [%s] [%s] [%s] [%s] [%s]",
        sn[0], sn[1], sn[2], sn[3], sn[4], sn[5]))
    print(string.format("  flags: IS_METAL=%s ITEMS_WEAPON=%s ITEMS_ARMOR=%s ITEMS_ANVIL=%s",
        tostring(mat.flags.IS_METAL), tostring(mat.flags.ITEMS_WEAPON),
        tostring(mat.flags.ITEMS_ARMOR), tostring(mat.flags.ITEMS_ANVIL)))
    print(string.format("  state_color Solid: %s", color_word(mat.state_color.Solid)))
    print(string.format("  basic_color: {%d,%d}  build_color: {%d,%d,%d}  tile_color: {%d,%d,%d}",
        mat.basic_color[0], mat.basic_color[1],
        mat.build_color[0], mat.build_color[1], mat.build_color[2],
        mat.tile_color[0], mat.tile_color[1], mat.tile_color[2]))
    print(string.format("  material_value: %d  tile: %d  item_symbol: %d",
        mat.material_value, mat.tile, mat.item_symbol))
end

-- ==========================================
-- S3: STEEL FAMILY LISTING
-- ==========================================
print("")
print("==========================================")
print("S3: EVERY REFINISH_STEEL_ MATERIAL")
print("==========================================")
local steel_count = 0
for i = 0, #raws - 1 do
    local m = raws[i]
    if string.find(m.id, "REFINISH_STEEL_", 1, true) then
        steel_count = steel_count + 1
        print(string.format("  index %d  id %s  name '%s'  state_color %s",
            i, m.id, m.material.state_name.Solid,
            color_word(m.material.state_color.Solid)))
    end
end
print(string.format("Steel family total: %d", steel_count))

-- ==========================================
-- S4: MODULE FAMILY COUNTS
-- ==========================================
print("")
print("==========================================")
print("S4: MATERIAL COUNTS BY ID PREFIX FAMILY")
print("==========================================")
local fam = {}
for i = 0, #raws - 1 do
    local f = id_family(raws[i].id)
    fam[f] = (fam[f] or 0) + 1
end
local fam_sorted = {}
for f, c in pairs(fam) do table.insert(fam_sorted, { f = f, c = c }) end
table.sort(fam_sorted, function(a, b) return a.f < b.f end)
for _, e in ipairs(fam_sorted) do
    print(string.format("  %-24s %d", e.f, e.c))
end

-- ==========================================
-- S5: BAR CENSUS
-- ==========================================
-- Counts inorganic bars by mat_index, but only for indices that
-- are in the detail set or in the steel family. This shows which
-- copy the physical bars actually belong to.
print("")
print("==========================================")
print("S5: BAR CENSUS FOR DETAILED AND STEEL INDICES")
print("==========================================")
local interesting = {}
for i in pairs(dup_indices) do interesting[i] = true end
for i = 0, #raws - 1 do
    if string.find(raws[i].id, "REFINISH_STEEL_", 1, true) then
        interesting[i] = true
    end
end

local bar_counts = {}
local orphan_bars = 0
local ok_bars, err_bars = pcall(function()
    for _, item in ipairs(world.items.other.BAR) do
        if item.mat_type == 0 then
            local mi = item.mat_index
            if interesting[mi] then
                bar_counts[mi] = (bar_counts[mi] or 0) + 1
            elseif mi < 0 or mi >= #raws then
                -- A bar pointing outside the array entirely is a
                -- serious finding on its own
                orphan_bars = orphan_bars + 1
            end
        end
    end
end)
if not ok_bars then
    print("  BAR scan failed: " .. tostring(err_bars))
else
    local any = false
    for mi, c in pairs(bar_counts) do
        any = true
        print(string.format("  mat_index %d (%s): %d bars",
            mi, raws[mi].id, c))
    end
    if not any then print("  No bars found on the tracked indices.") end
    if orphan_bars > 0 then
        print(string.format("  WARNING: %d bars point outside the inorganics array", orphan_bars))
    end
end

-- ==========================================
-- S6: COLOR DESCRIPTOR TAIL
-- ==========================================
-- If a module injected color descriptors this session, they sit at
-- the tail. Any insertion earlier than the tail would shift every
-- index after it, which corrupts cached color_idx values.
print("")
print("==========================================")
print("S6: COLOR DESCRIPTOR TABLE")
print("==========================================")
print(string.format("Total color descriptors: %d", #colors))
local tail_start = math.max(0, #colors - 10)
for i = tail_start, #colors - 1 do
    print(string.format("  %d %s", i, colors[i].id))
end

-- ==========================================
-- S7: FORGE JOBS
-- ==========================================
-- Walks every metalsmith and magma forge, printing each queued job
-- and the exact material demands on its job_items. A job whose
-- job_item mat_index has no matching bars is the rejection case.
print("")
print("==========================================")
print("S7: FORGE JOBS AND THEIR MATERIAL DEMANDS")
print("==========================================")
local forge_seen = 0
local ok_forge, err_forge = pcall(function()
    for _, bld in ipairs(world.buildings.all) do
        local is_forge = false
        if bld:getType() == df.building_type.Workshop then
            local st = bld:getSubtype()
            if st == df.workshop_type.MetalsmithsForge
            or st == df.workshop_type.MagmaForge then
                is_forge = true
            end
        end
        if is_forge then
            forge_seen = forge_seen + 1
            print(string.format("Forge #%d at (%d,%d,%d): %d jobs",
                forge_seen, bld.centerx, bld.centery, bld.z, #bld.jobs))
            for _, job in ipairs(bld.jobs) do
                local jt = df.job_type[job.job_type] or tostring(job.job_type)
                print(string.format("  job %d  type %s  mat_type %d  mat_index %d",
                    job.id, jt, job.mat_type, job.mat_index))
                -- The job level mat fields drive the menu label; the
                -- job_items drive what hauling will actually accept
                for k = 0, #job.job_items.elements - 1 do
                    local ji = job.job_items.elements[k]
                    local resolved = "n/a"
                    if ji.mat_type == 0 and ji.mat_index >= 0 and ji.mat_index < #raws then
                        resolved = raws[ji.mat_index].id
                    end
                    print(string.format("    job_item %d  item_type %s  mat_type %d  mat_index %d  (%s)",
                        k, df.item_type[ji.item_type] or tostring(ji.item_type),
                        ji.mat_type, ji.mat_index, resolved))
                end
            end
        end
    end
end)
if not ok_forge then
    print("  Forge scan failed: " .. tostring(err_forge))
elseif forge_seen == 0 then
    print("  No forges found on this map.")
end

print("")
print("Probe complete. Nothing was modified.")
