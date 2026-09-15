-- refinish-size-probe.lua
-- ==========================================
-- ITEM SIZE PROBE
-- ==========================================
-- Finds out where a runtime size (volume in cm3) can actually be read
-- from, for every class of item the yield evaluator will need to
-- measure. Nothing here is assumed. Every accessor is called inside a
-- pcall and reported as either a value or the reason it failed, so the
-- output is evidence rather than a guess.
--
-- WHY THIS EXISTS
--   The DF wiki publishes a table of item volumes, but most of them are
--   hardcoded in the executable rather than declared in raws. There is
--   no file to scrape. Corpses and body parts are listed only as
--   "special, based on the size of the corpse and what it is made of",
--   which says the number exists without saying where. This script
--   locates it.
--
-- WHAT IT PRODUCES
--   Section 1  Which item methods exist at all, tested on one item.
--   Section 2  A per item type census with sampled real objects, every
--              accessor tried on each, plus the wiki's published volume
--              alongside for comparison.
--   Section 3  The creature path for corpse class items: race, caste,
--              and every caste field whose name mentions size, listed
--              by enumeration rather than by guessing field names.
--
-- USAGE, from the DFHack console
--     refinish-size-probe
--     refinish-size-probe 12          sample up to 12 items per type
--
-- Writes refinish_size_probe.txt to the DF root folder. Written to a
-- file rather than printed because this is a table to read carefully,
-- and the console cannot be read while the game runs.
-- ==========================================

local args = {...}


-- ==========================================
-- CONFIGURATION
-- ==========================================

-- How many real items to sample per item type. More samples catch
-- variation within a type, which is exactly the thing we care about
-- for corpses. Costs nothing but output length.
local SAMPLES_PER_TYPE = tonumber(args[1]) or 6

local OUTFILE = "refinish_size_probe.txt"

-- Candidate accessors, tried in order on every sampled item.
--
-- This is a guess list on purpose. The point of the probe is to find
-- out which of these exist, so a name that does not resolve is a
-- result, not an error. Add to this list freely; nothing downstream
-- depends on its contents.
local ITEM_METHODS = {
    "getVolume",
    "getWeight",
    "getTotalDimension",
    "getStackSize",
    "getQuality",
    "getMaterial",
    "getMaterialIndex",
    "getSubtype",
}

-- Volumes the wiki publishes, in cm3, keyed by df.item_type name.
--
-- Printed beside whatever the accessors return so a wrong accessor is
-- obvious at a glance. "Special" entries are the ones this probe was
-- built to resolve, so they are deliberately absent here.
local WIKI_VOLUME = {
    BAR = 6000,          BLOCKS = 6000,       BOULDER = 100000,
    WOOD = 50000,        DOOR = 30000,        FLOODGATE = 30000,
    BED = 30000,         CHAIR = 30000,       TABLE = 30000,
    COFFIN = 30000,      CABINET = 30000,     STATUE = 60000,
    SLAB = 60000,        WINDOW = 20000,      BARREL = 20000,
    BOX = 20000,         BIN = 15000,         BUCKET = 3000,
    ANIMALTRAP = 3000,   ARMORSTAND = 10000,  WEAPONRACK = 10000,
    CHAIN = 5000,        ANVIL = 10000,       FLASK = 1000,
    GOBLET = 1000,       TOY = 1000,          FIGURINE = 1000,
    CROWN = 1000,        BOOK = 1000,         CHEESE = 1000,
    FOOD = 1000,         PLANT = 1000,        BAG = 1000,
    INSTRUMENT = 4000,   SCEPTER = 3000,      QUIVER = 3000,
    BACKPACK = 5000,     TOTEM = 5000,        SKIN_TANNED = 5000,
    AMULET = 500,        BRACELET = 200,      RING = 50,
    EARRING = 30,        ROUGH = 2500,        SMALLGEM = 200,
    REMAINS = 2000,      MEAT = 2000,         FISH = 2000,
    FISH_RAW = 2000,     SPLINT = 2000,       CRUTCH = 2000,
    ORTHOPEDIC_CAST = 2000,
    SEEDS = 100,         PLANT_GROWTH = 50,   COIN = 10,
    DRINK = 600,         POWDER_MISC = 600,   LIQUID_MISC = 600,
    GLOB = 600,          MECHANISMS = 20000,  PIPE_SECTION = 30000,
    HATCH_COVER = 10000, GRATE = 10000,       QUERN = 30000,
    MILLSTONE = 30000,   TRACTION_BENCH = 30000,
    CAGE = 30000,        CATAPULTPARTS = 20000, BALLISTAPARTS = 20000,
    SIEGEAMMO = 30000,   BALLISTAARROWHEAD = 10000,
}

-- Item types whose runtime size varies per object and therefore drives
-- the whole yield design. Sampled harder and reported separately.
local VARIABLE_TYPES = {
    CORPSE = true, CORPSEPIECE = true, REMAINS = true,
    FOOD = true,   PET = true,
}

-- Caste fields that might carry a size, tried by name.
--
-- A guess list like ITEM_METHODS above. Reading a name that does not
-- exist returns nil and reports as absent, which is a result. The point
-- of naming them rather than enumerating is safety: see the comment on
-- enumerate_caste below.
local CASTE_SIZE_FIELDS = {
    "body_size_1", "body_size_2", "body_size_3",
    "body_appearance_modifiers",
}

local CASTE_MISC_SIZE_FIELDS = {
    "adult_size", "baby_size", "child_size",
    "size_dim", "grazer",
}

-- Set true to also run the enumeration pass in Section 3. Off by
-- default. Turn it on only if the named passes above come back empty,
-- and expect the possibility of a hard crash when you do. Everything
-- written before that point is already safely on disk.
local ENUMERATE_CASTE_FIELDS = false


-- ==========================================
-- OUTPUT BUFFER
-- ==========================================
-- Collected in memory and written once at the end, so a crash midway
-- leaves no half file to mistake for a complete one.
-- ==========================================

local out = {}

local function w(fmt, ...)
    if select('#', ...) > 0 then
        table.insert(out, string.format(fmt, ...))
    else
        table.insert(out, fmt)
    end
end

local function rule(title)
    w("")
    w("==================================================================")
    w(title)
    w("==================================================================")
end

-- ==========================================
-- FLUSH
-- ==========================================
-- Writes everything collected so far and leaves the buffer intact, so
-- calling it repeatedly just rewrites a longer file each time.
--
-- Called after every section rather than once at the end. Section 3
-- enumerates fields off a live struct, and the DFHack API warns that
-- enumerating certain structures can raise an access violation. That
-- is a hard crash in C++, not a Lua error, so pcall cannot catch it
-- and an end-of-run write would take the completed sections down with
-- it. Flushing as we go means a crash costs only the section that
-- caused it.
-- ==========================================
local function flush()
    local f = io.open(OUTFILE, "w")
    if not f then return false end
    f:write(table.concat(out, "\n"))
    f:write("\n")
    f:close()
    return true
end


-- ==========================================
-- SAFE CALL
-- ==========================================
-- Calls obj:method() and returns a printable result string. A method
-- that does not exist, or that throws, is reported rather than raised,
-- because "this accessor is unavailable on this item type" is one of
-- the answers we are here to collect.
-- ==========================================
local function try_method(obj, name)
    local ok, result = pcall(function()
        local fn = obj[name]
        if fn == nil then return "<absent>" end
        if type(fn) ~= "function" then return "<not a function>" end
        return obj[name](obj)
    end)
    if not ok then
        return "<error: " .. tostring(result) .. ">"
    end
    return tostring(result)
end

-- Same idea for a plain field read.
local function try_field(obj, name)
    local ok, result = pcall(function() return obj[name] end)
    if not ok then return "<error>" end
    if result == nil then return "<absent>" end
    return tostring(result)
end

-- Field read that expands short vectors inline.
--
-- BODY_SIZE in the raws is a growth curve, written as repeated
-- (year, tick, size) triples, so the caste side is expected to be
-- vectors rather than a single number. A bare tostring on a vector
-- prints only its type name, which would hide exactly the data we came
-- for. Anything longer than the cap is summarised by length instead,
-- so a pathological entry cannot flood the report.
local function read_size_field(obj, name)
    local ok, val = pcall(function() return obj[name] end)
    if not ok then return "<error>" end
    if val == nil then return "<absent>" end

    local ok_len, len = pcall(function() return #val end)
    if not ok_len or type(len) ~= "number" then
        return tostring(val)
    end

    if len == 0 then return tostring(val) .. "  (empty)" end

    if len > 24 then
        return tostring(val) .. string.format("  (%d entries, too long to expand)", len)
    end

    local parts = {}
    for k = 0, len - 1 do
        local ok_v, v = pcall(function() return val[k] end)
        table.insert(parts, ok_v and tostring(v) or "?")
    end
    return tostring(val) .. "  [" .. table.concat(parts, ", ") .. "]"
end


-- ==========================================
-- MATERIAL DENSITY
-- ==========================================
-- The wiki gives weight = density * size / 1,000,000. So if an item
-- exposes a weight but not a volume, volume can be recovered as
-- weight * 1,000,000 / density. This reads the density so that
-- fallback can be evaluated from the output.
--
-- Returns density and a readable material token, or nil for both when
-- the material cannot be decoded.
-- ==========================================
local function material_info(item)
    local ok, mi = pcall(function() return dfhack.matinfo.decode(item) end)
    if not ok or not mi then return nil, nil end

    local token = "?"
    pcall(function() token = mi:getToken() end)

    local density = nil
    pcall(function() density = mi.material.solid_density end)

    return density, token
end


-- ==========================================
-- SECTION 1: CAPABILITY PROBE
-- ==========================================
-- Answers the single most load-bearing question first: does an item
-- expose a volume accessor at all? Everything else in the yield design
-- branches on this. Run against the first item in the world so it is
-- true regardless of what the fortress happens to contain.
-- ==========================================
local function probe_capabilities()
    rule("SECTION 1: ITEM METHOD CAPABILITY")

    local items = df.global.world.items.all
    if #items == 0 then
        w("No items in world. Load a fortress with items and rerun.")
        return
    end

    local sample = items[0]
    local desc = "?"
    pcall(function() desc = dfhack.items.getDescription(sample, 0) end)

    w("Probed against item id %s (%s).", try_field(sample, "id"), desc)
    w("")
    w("An <absent> here means the method does not exist under that name")
    w("and the yield evaluator must not call it.")
    w("")

    for _, name in ipairs(ITEM_METHODS) do
        w("  %-22s %s", name, try_method(sample, name))
    end
end


-- ==========================================
-- SECTION 2: PER TYPE CENSUS
-- ==========================================
-- Buckets every item in the world by type, then samples a few from
-- each bucket and reports every accessor beside the wiki's published
-- volume. Where the two agree, that accessor is trustworthy for that
-- type. Where a type has no published volume, the accessor is the only
-- source we have and its per object variation is the finding.
-- ==========================================
local function census()
    rule("SECTION 2: PER ITEM TYPE CENSUS")

    -- Bucket first so the report is grouped and the counts are honest.
    local buckets = {}
    for _, item in ipairs(df.global.world.items.all) do
        local ok, itype = pcall(function() return item:getType() end)
        if ok then
            local tname = df.item_type[itype] or ("UNKNOWN_" .. tostring(itype))
            buckets[tname] = buckets[tname] or {}
            table.insert(buckets[tname], item)
        end
    end

    -- Sorted so two runs of this script can be diffed against each other.
    local names = {}
    for tname in pairs(buckets) do table.insert(names, tname) end
    table.sort(names)

    w("%d distinct item types present.", #names)
    w("")

    for _, tname in ipairs(names) do
        local list = buckets[tname]
        local wiki = WIKI_VOLUME[tname]
        local marker = VARIABLE_TYPES[tname] and "   *** VARIABLE SIZE ***" or ""

        w("")
        w("------------------------------------------------------------------")
        w("%s   (%d in world)   wiki volume: %s%s",
          tname, #list, wiki and tostring(wiki) or "unpublished", marker)
        w("------------------------------------------------------------------")

        -- Variable types get the deeper sample, because variation
        -- within the type is the entire reason this probe exists.
        local limit = VARIABLE_TYPES[tname] and (SAMPLES_PER_TYPE * 2) or SAMPLES_PER_TYPE
        if limit > #list then limit = #list end

        for i = 1, limit do
            local item = list[i]
            local desc = "?"
            pcall(function() desc = dfhack.items.getDescription(item, 0) end)

            local density, token = material_info(item)

            w("")
            w("  [%d] %s", i, desc)
            w("      material: %s   solid_density: %s",
              token or "?", density and tostring(density) or "?")

            for _, name in ipairs(ITEM_METHODS) do
                w("      %-20s %s", name, try_method(item, name))
            end

            -- Weight over density recovers volume when no volume
            -- accessor exists. Printed as a derived figure so it can be
            -- checked against the wiki column above.
            local ok_w, weight = pcall(function() return item:getWeight() end)
            if ok_w and type(weight) == "number" and density and density > 0 then
                w("      derived volume (weight * 1e6 / density): %.1f",
                  (weight * 1000000.0) / density)
            end
        end
    end
end


-- ==========================================
-- SECTION 3: CREATURE SIZE PATH
-- ==========================================
-- Corpse class items carry a race and caste rather than a size. This
-- walks that path for every race actually present in the fortress and
-- enumerates the caste fields whose names mention size.
--
-- Enumerated rather than named on purpose. Guessing at a field called
-- adult_size and being wrong would give a plausible looking number
-- from the wrong slot, which is the worst possible failure mode for a
-- balance formula. Reading the field list off the live struct cannot
-- be wrong.
-- ==========================================
local function creature_paths()
    rule("SECTION 3: CREATURE SIZE PATH FOR CORPSE CLASS ITEMS")

    -- Which races are actually represented, and by what.
    local races_seen = {}

    for _, item in ipairs(df.global.world.items.all) do
        local ok, itype = pcall(function() return item:getType() end)
        if ok then
            local tname = df.item_type[itype]
            if tname == "CORPSE" or tname == "CORPSEPIECE" or tname == "REMAINS" then
                local race = nil
                pcall(function() race = item.race end)
                if race then
                    races_seen[race] = races_seen[race] or { count = 0, sample = item }
                    races_seen[race].count = races_seen[race].count + 1
                end
            end
        end
    end

    local race_list = {}
    for race in pairs(races_seen) do table.insert(race_list, race) end
    table.sort(race_list)

    if #race_list == 0 then
        w("No corpse, corpsepiece or remains items found in this fortress.")
        w("Butcher something or find a battlefield, then rerun. The field")
        w("enumeration below still runs against creature 0 so the struct")
        w("layout is captured either way.")
        w("")
        -- Fall through: the layout dump is the more valuable half.
        race_list = { 0 }
        races_seen[0] = { count = 0, sample = nil }
    end

    for _, race in ipairs(race_list) do
        local entry = races_seen[race]
        local craw = nil
        pcall(function() craw = df.global.world.raws.creatures.all[race] end)

        w("")
        w("------------------------------------------------------------------")
        if craw then
            w("race %d: %s   (%d corpse class items)",
              race, try_field(craw, "creature_id"), entry.count)
        else
            w("race %d: <could not resolve creature raw>   (%d items)",
              race, entry.count)
        end
        w("------------------------------------------------------------------")

        if not craw then goto continue end

        -- The item itself, when we have one, so item side and raw side
        -- can be compared directly.
        if entry.sample then
            local desc = "?"
            pcall(function() desc = dfhack.items.getDescription(entry.sample, 0) end)
            w("  sample item: %s", desc)
            w("    item.race  = %s", try_field(entry.sample, "race"))
            w("    item.caste = %s", try_field(entry.sample, "caste"))
            for _, name in ipairs(ITEM_METHODS) do
                w("    %-20s %s", name, try_method(entry.sample, name))
            end
        end

        -- Caste side. Every caste, because a queen bee and a worker bee
        -- are the same race and very different sizes.
        local ok_castes, ncastes = pcall(function() return #craw.caste end)
        if not ok_castes then
            w("  <caste vector unreadable>")
            goto continue
        end

        w("  %d caste(s).", ncastes)

        for ci = 0, ncastes - 1 do
            local caste = craw.caste[ci]
            w("")
            w("    caste %d: %s", ci, try_field(caste, "caste_id"))

            -- PASS A: named candidates, read one at a time.
            --
            -- Safe by construction. A field that does not exist reads as
            -- nil and reports as absent, and no enumeration happens, so
            -- there is no access violation risk. If this pass alone
            -- answers the question, PASS B never has to run.
            for _, fname in ipairs(CASTE_SIZE_FIELDS) do
                w("      caste.%-26s %s", fname, read_size_field(caste, fname))
            end

            local ok_misc_named = pcall(function()
                local misc = caste.misc
                if not misc then
                    w("      caste.misc                  <absent>")
                    return
                end
                for _, fname in ipairs(CASTE_MISC_SIZE_FIELDS) do
                    w("      caste.misc.%-21s %s", fname, read_size_field(misc, fname))
                end
            end)
            if not ok_misc_named then
                w("      <caste.misc named read failed>")
            end

            -- PASS B: enumeration. Opt in only.
            --
            -- Catches any size field whose name we failed to guess. The
            -- DFHack API warns that enumerating a live struct can raise
            -- an access violation in C++, which no pcall can catch, so
            -- this is off unless ENUMERATE_CASTE_FIELDS is set. Flushed
            -- immediately before, so a crash here costs only this line.
            if ENUMERATE_CASTE_FIELDS then
                flush()
                w("      -- enumerated fields --")
                local found = 0
                local ok_enum = pcall(function()
                    for key, val in pairs(caste) do
                        if type(key) == "string"
                           and string.find(string.lower(key), "size") then
                            found = found + 1
                            w("      caste.%-26s %s", key, tostring(val))
                        end
                    end
                end)
                if not ok_enum then
                    w("      <enumeration failed on this caste>")
                elseif found == 0 then
                    w("      <no top level field name contains 'size'>")
                end
            end
        end

        ::continue::
    end
end


-- ==========================================
-- RUN
-- ==========================================

w("REFINISH METAL: ITEM SIZE PROBE")
w("Samples per type: %d", SAMPLES_PER_TYPE)
w("")
w("Size in Dwarf Fortress is volume in cubic centimetres, for creatures")
w("and items alike. Anything reported below that is not in cm3 is a")
w("finding, not a rounding error.")

-- Each section runs under its own pcall and flushes on completion, so
-- one section faulting costs that section and nothing else. The file on
-- disk is always current as of the last section that finished.
local SECTIONS = {
    { name = "capability", fn = probe_capabilities },
    { name = "census",     fn = census },
    { name = "creatures",  fn = creature_paths },
}

for _, section in ipairs(SECTIONS) do
    local ok, err = pcall(section.fn)
    if not ok then
        rule("SECTION FAULTED: " .. section.name)
        w("%s", tostring(err))
        w("")
        w("Everything above this line is still valid.")
    end
    flush()
end

if flush() then
    print("refinish-size-probe: wrote " .. OUTFILE .. " (" .. #out .. " lines).")
else
    print("refinish-size-probe: could not open " .. OUTFILE .. " for writing.")
end
