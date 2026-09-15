-- refinish-steel-audit.lua
-- ==========================================
-- READ ONLY AUDIT: STRANDED MATERIALS + STEEL REACTIONS
-- ==========================================
-- Answers two questions the forge probe could not:
--
--   Q1  Do saved objects reference steel material IDs that no
--       longer exist in the live array? A stranded ID is an item
--       that neither the payload restore nor the ledger can place,
--       so it keeps a stale mat_index and silently renders as some
--       other material. This is the regression test.
--
--   Q2  What are the three "blue steel" menu entries, mechanically?
--       We dump every reaction that produces or consumes a matching
--       steel material, showing each reagent's demanded material (or
--       reaction_class) and each product. This is why bars get
--       rejected: a reagent bound to one MV variant will refuse the
--       bars of another, even though both read "blue steel".
--
-- Changes nothing. Safe on a loaded fort.
--
-- USAGE:
--   refinish-steel-audit                 audit + reactions for "blue steel"
--   refinish-steel-audit maroon steel    reactions for a different name
-- ==========================================

local json = require('json')

local world = df.global.world
local raws = world.raws.inorganics.all
-- The reactions vector lives inside a handler struct; the vector
-- itself is one level down (same path refinish-clear-reaction uses)
local reactions = world.raws.reactions.reactions

-- The two persistent keys RM uses. Both live in site data.
local PAYLOAD_KEY = "REFINISH_STEEL_PAYLOAD"
local LEDGER_KEY  = "REFINISH_STEEL_LEDGER"

-- Optional target display name from the command line. Defaults to
-- the reported case: "blue steel".
local args = {...}
local target = (#args > 0) and string.lower(table.concat(args, " ")) or "blue steel"

-- ==========================================
-- SHARED: LIVE ID -> INDEX MAP
-- ==========================================
-- Built once. Every audit below asks "does this recorded ID still
-- exist, and if so where" against this map.
local live_by_id = {}
for i = 0, #raws - 1 do
    live_by_id[raws[i].id] = i
end

-- Small helper: safely decode a site data string into a table.
-- Returns the table, or nil plus a reason.
local function load_site_json(key)
    local raw = dfhack.persistent.getSiteData(key)
    if not raw or raw == "" then
        return nil, "not present on this save"
    end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= "table" then
        return nil, "present but could not be decoded"
    end
    return decoded
end

-- ==========================================
-- P1: PERSISTED PAYLOAD AUDIT
-- ==========================================
-- The payload (written by refinish-save, restored by refinish-load)
-- records every RM object as { id, mat } where mat is the material
-- ID string. We gather the DISTINCT material IDs it references and
-- test each against the live array. Any ID missing from the live
-- array will strand its objects on load.
print("==========================================")
print("P1: PERSISTED PAYLOAD AUDIT")
print("==========================================")

local payload, p_err = load_site_json(PAYLOAD_KEY)
if not payload then
    print("Payload " .. p_err .. ".")
else
    print(string.format("Payload site_id: %s   (current: %s)",
        tostring(payload.site_id), tostring(df.global.plotinfo.site_id)))

    -- Collect distinct material IDs across all three object kinds,
    -- counting how many objects reference each.
    local refs = {}   -- mat_id -> count of objects referencing it
    local function gather(list_name)
        local list = payload[list_name]
        if type(list) ~= "table" then return end
        for _, obj in ipairs(list) do
            local m = obj.mat
            if m then refs[m] = (refs[m] or 0) + 1 end
        end
    end
    gather("items")
    gather("buildings")
    gather("constructions")

    -- Split into present vs stranded, and note whether the recorded
    -- IDs carry the _MV suffix (the scheme-change tell).
    local present, stranded = {}, {}
    local mv_seen, non_mv_seen = 0, 0
    for mat_id, count in pairs(refs) do
        if string.find(mat_id, "_MV%d") then mv_seen = mv_seen + 1
        elseif string.find(mat_id, "REFINISH_STEEL_MAT_COLOUR_", 1, true) then
            -- A COLOUR material with no _MV is the old scheme
            non_mv_seen = non_mv_seen + 1
        end
        if live_by_id[mat_id] then
            table.insert(present, { id = mat_id, count = count })
        else
            table.insert(stranded, { id = mat_id, count = count })
        end
    end

    print(string.format("Distinct material IDs referenced: %d", #present + #stranded))
    print(string.format("  present in live array: %d", #present))
    print(string.format("  STRANDED (missing):    %d", #stranded))
    print(string.format("COLOUR ID scheme: %d carry _MV, %d are suffix-less COLOUR ids",
        mv_seen, non_mv_seen))

    if #stranded > 0 then
        print("---- stranded IDs (objects that will mis-render on load) ----")
        table.sort(stranded, function(a, b) return a.count > b.count end)
        for _, e in ipairs(stranded) do
            print(string.format("  %5d obj  %s", e.count, e.id))
        end
    end
end

-- ==========================================
-- P2: PERSISTED LEDGER AUDIT
-- ==========================================
-- The ledger records id -> index from last session. We test every
-- recorded ID against the live array. A missing ID is one the remap
-- must skip (its objects keep a stale index). For present IDs we
-- report how far each moved, which tells us how much the array
-- actually shifted between sessions.
print("")
print("==========================================")
print("P2: PERSISTED LEDGER AUDIT")
print("==========================================")

local ledger, l_err = load_site_json(LEDGER_KEY)
if not ledger then
    print("Ledger " .. l_err .. ".")
elseif type(ledger.mats) ~= "table" then
    print("Ledger present but has no 'mats' table.")
else
    print(string.format("Ledger site_id: %s   (current: %s)",
        tostring(ledger.site_id), tostring(df.global.plotinfo.site_id)))

    local recorded, present, missing = 0, 0, 0
    local moved, max_drift = 0, 0
    local missing_list = {}
    for mat_id, old_idx in pairs(ledger.mats) do
        recorded = recorded + 1
        local new_idx = live_by_id[mat_id]
        if new_idx == nil then
            missing = missing + 1
            table.insert(missing_list, mat_id)
        else
            present = present + 1
            if new_idx ~= old_idx then
                moved = moved + 1
                local drift = math.abs(new_idx - old_idx)
                if drift > max_drift then max_drift = drift end
            end
        end
    end

    print(string.format("Recorded IDs: %d", recorded))
    print(string.format("  present in live array: %d", present))
    print(string.format("  MISSING (remap skips): %d", missing))
    print(string.format("  moved since record:    %d  (largest drift: %d indices)",
        moved, max_drift))

    if missing > 0 then
        print("---- IDs the ledger can no longer place ----")
        table.sort(missing_list)
        for _, id in ipairs(missing_list) do
            print("  " .. id)
        end
    end
end

-- ==========================================
-- P3: STEEL REACTION DUMP (TARGET NAME)
-- ==========================================
-- Builds the set of inorganic indices whose Solid name matches the
-- target, then prints every reaction that produces or consumes one
-- of them, plus any reaction whose code or name contains the target
-- words (to catch reaction_class matches that carry no direct index).
--
-- For each reaction we print, per reagent: the reagent label, the
-- item type, and the demanded material (resolved to an inorganic ID
-- when the reagent pins mat_type 0 + a specific mat_index) or the
-- reaction_class it matches instead. Products print the same way.
-- This is the direct read on why one entry accepts your bars and the
-- others reject them.
print("")
print("==========================================")
print("P3: REACTIONS FOR '" .. target .. "'")
print("==========================================")

-- Target material index set, and a printable id per index.
local target_idx = {}
for i = 0, #raws - 1 do
    local nm = string.lower(raws[i].material.state_name.Solid or "")
    if nm == target or string.find(nm, target, 1, true) then
        target_idx[i] = raws[i].id
    end
end

-- Resolve a (mat_type, mat_index) pair to a readable material label.
local function mat_label(mat_type, mat_index)
    if mat_type == 0 and mat_index ~= nil and mat_index >= 0 and mat_index < #raws then
        return string.format("INORGANIC:%d %s", mat_index, raws[mat_index].id)
    end
    return string.format("mat_type=%s mat_index=%s", tostring(mat_type), tostring(mat_index))
end

-- Defensive field read: returns value or a placeholder.
local function field(obj, name)
    local ok, v = pcall(function() return obj[name] end)
    if ok then return v end
    return nil
end

local matched = 0
for r = 0, #reactions - 1 do
    local rx = reactions[r]
    local code = rx.code or ""
    local name = rx.name or ""

    -- Decide whether this reaction is relevant.
    local hit = false

    -- Text match on code or name.
    if string.find(string.lower(code), target, 1, true)
    or string.find(string.lower(name), target, 1, true) then
        hit = true
    end

    -- Reagent or product bound to a target material index.
    if not hit then
        for i = 0, #rx.reagents - 1 do
            local rg = rx.reagents[i]
            local mt, mi = field(rg, "mat_type"), field(rg, "mat_index")
            if mt == 0 and mi ~= nil and target_idx[mi] then hit = true break end
        end
    end
    if not hit then
        for i = 0, #rx.products - 1 do
            local pr = rx.products[i]
            local mt, mi = field(pr, "mat_type"), field(pr, "mat_index")
            if mt == 0 and mi ~= nil and target_idx[mi] then hit = true break end
        end
    end

    if hit then
        matched = matched + 1
        print(string.format("---- reaction %d ----", r))
        print("  code: " .. code)
        print("  name: " .. name)

        -- Reagents: what the reaction demands.
        for i = 0, #rx.reagents - 1 do
            local rg = rx.reagents[i]
            local rcode = field(rg, "code") or "?"
            local it    = field(rg, "item_type")
            local mt    = field(rg, "mat_type")
            local mi    = field(rg, "mat_index")
            local rcls  = field(rg, "reaction_class")
            local itname = it and (df.item_type[it] or tostring(it)) or "n/a"
            local extra = ""
            if rcls ~= nil and rcls ~= "" then extra = "  reaction_class=" .. tostring(rcls) end
            print(string.format("    reagent [%s] item=%s  %s%s",
                tostring(rcode), itname, mat_label(mt, mi), extra))
        end

        -- Products: what the reaction makes.
        for i = 0, #rx.products - 1 do
            local pr = rx.products[i]
            local it = field(pr, "item_type")
            local mt = field(pr, "mat_type")
            local mi = field(pr, "mat_index")
            local cnt = field(pr, "count")
            local itname = it and (df.item_type[it] or tostring(it)) or "n/a"
            print(string.format("    product count=%s item=%s  %s",
                tostring(cnt), itname, mat_label(mt, mi)))
        end
    end
end

if matched == 0 then
    print("No reactions reference '" .. target .. "'.")
    print("If the forge entries are vanilla weapon/armor forging, they")
    print("are the hardcoded material picker, not custom reactions, and")
    print("would list one entry per material you hold bars of.")
else
    print(string.format("Matched %d reactions.", matched))
end

-- ==========================================
-- P4: BAR STOCK FOR TARGET MATERIALS
-- ==========================================
-- For each target material index, count inorganic bars in the world
-- carrying it. This shows which single variant you actually have
-- bars of, and therefore which of the identically-named menu entries
-- can be fulfilled.
print("")
print("==========================================")
print("P4: BAR STOCK FOR '" .. target .. "' MATERIALS")
print("==========================================")

-- Sorted list of target indices for stable output.
local tlist = {}
for i in pairs(target_idx) do table.insert(tlist, i) end
table.sort(tlist)

if #tlist == 0 then
    print("No live materials match '" .. target .. "'.")
else
    local counts = {}
    local ok_bars, err_bars = pcall(function()
        for _, item in ipairs(world.items.other.BAR) do
            if item.mat_type == 0 and target_idx[item.mat_index] then
                counts[item.mat_index] = (counts[item.mat_index] or 0) + 1
            end
        end
    end)
    if not ok_bars then
        print("  BAR scan failed: " .. tostring(err_bars))
    else
        for _, i in ipairs(tlist) do
            print(string.format("  index %d  %s  ->  %d bars",
                i, raws[i].id, counts[i] or 0))
        end
    end
end

print("")
print("Audit complete. Nothing was modified.")
