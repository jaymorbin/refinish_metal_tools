-- refinish-empty-probe.lua
-- ==========================================
-- WHY DOES REFUEL'S CONTAINER REAGENT REFUSE A FULL ONE AND OURS NOT?
-- ==========================================
-- Measured: Refuel's typed BOX/BARREL reagent skipped the very barrel
-- our reaction had already hauled to the workshop. Same item, same
-- spot, same item type. So DF honours the gate on a typed container
-- reagent, and the difference is in the reagent, not in DF.
--
-- Refuel's is parsed from raws. Ours is cloned from a template
-- reaction, zeroed, and rebuilt from JSON. Any field that survives
-- the clone, or fails to get rebuilt, is a candidate — not only the
-- one flag we have been staring at.
--
-- So this dumps EVERY field of both reagents side by side. Bitfields
-- print as raw integers in hex: one number carries all 32 bits, so a
-- difference cannot hide behind a flag name nobody thought to print.
--
-- Read-only. Needs no JSON edit and no recycle to be useful.
--
-- USAGE (launcher, clear the input box first):
--   refinish-empty-probe
-- ==========================================

local utils = require('utils')

-- Ours first, then the Refuel equivalent for the same item type.
-- Substring match, so exact codes are not needed.
local PATTERNS = {
    'MAKING_FUEL_RXN_ASH_BOX',
    'MAKING_FUEL_RXN_ASH_BARREL',
    'BURN_FURNITURE_BOX',
    'BURN_FURNITURE_BARREL',
}

local function matches(code)
    for _, p in ipairs(PATTERNS) do
        if code:find(p, 1, true) then return true end
    end
    return false
end

-- Reads a dotted field path through pcall, so a shape that lacks the
-- field reports "??" instead of ending the run.
local function get(obj, path)
    local ok, v = pcall(function()
        local cur = obj
        for part in path:gmatch('[^%.]+') do cur = cur[part] end
        return cur
    end)
    if not ok then return '??' end
    return v
end

local function hex(v)
    if type(v) ~= 'number' then return tostring(v) end
    return string.format('0x%08X', v)
end

-- ==========================================
-- PART 1: REAGENT FIELD DUMP
-- ==========================================
-- Every scalar that can affect matching, plus all flag words. One
-- reagent per block, same field order every time, so two blocks
-- compare line for line.
local FIELDS = {
    'item_type', 'item_subtype', 'mat_type', 'mat_index',
    'quantity', 'min_dimension', 'has_tool_use', 'metal_ore',
    'reaction_class', 'has_material_reaction_product',
}

print('')
print('== REAGENTS ==')
for _, r in ipairs(df.global.world.raws.reactions.reactions) do
    local code = tostring(r.code)
    if matches(code) and not code:find('_GHOST_', 1, true) then
        for i = 0, #r.reagents - 1 do
            local g = r.reagents[i]
            print(string.format('-- %s [%d] code=%s',
                code, i, tostring(get(g, 'code'))))
            for _, f in ipairs(FIELDS) do
                print(string.format('     %-30s %s', f, tostring(get(g, f))))
            end
            -- Flag words as integers: all bits, nothing omitted.
            print(string.format('     %-30s %s', 'flags1.whole', hex(get(g, 'flags1.whole'))))
            print(string.format('     %-30s %s', 'flags2.whole', hex(get(g, 'flags2.whole'))))
            print(string.format('     %-30s %s', 'flags3.whole', hex(get(g, 'flags3.whole'))))
            print(string.format('     %-30s %s', 'flags4', hex(get(g, 'flags4'))))
            print(string.format('     %-30s %s', 'flags5', hex(get(g, 'flags5'))))
            -- The reaction-level reagent flags (PRESERVE, IN_CONTAINER,
            -- DOES_NOT_DETERMINE_PRODUCT_AMOUNT) are a separate word.
            print(string.format('     %-30s %s', 'flags(reagent).whole',
                hex(get(g, 'flags.whole'))))
        end
    end
end

-- ==========================================
-- PART 2: LIVE JOB FILTERS
-- ==========================================
-- Only meaningful with a matching job queued. job_items.elements is
-- what the hauler consults; if it ever disagrees with the reaction
-- printed above, that disagreement is the whole answer.
print('')
print('== LIVE JOBS ==')
local found = false
for _, job in utils.listpairs(df.global.world.jobs.list) do
    local code = tostring(job.reaction_name or '')
    if code ~= '' and matches(code) then
        found = true
        print(string.format('job %d  %s', job.id, code))
        local vec
        pcall(function()
            local jil = job.job_items
            vec = jil.elements or jil
        end)
        if vec then
            for i = 0, #vec - 1 do
                local f = vec[i]
                print(string.format('   filter[%d] itype=%-5s flags1=%s flags2=%s flags3=%s',
                    i, tostring(get(f, 'item_type')),
                    hex(get(f, 'flags1.whole')),
                    hex(get(f, 'flags2.whole')),
                    hex(get(f, 'flags3.whole'))))
            end
        end
        for _, iref in ipairs(job.items) do
            local it = iref.item
            if it then
                local n = 0
                pcall(function() n = #dfhack.items.getContainedItems(it) end)
                print(string.format('   attached: %s  container=%s holds=%d',
                    dfhack.items.getDescription(it, 0),
                    tostring(it.flags.container), n))
            end
        end
    end
end
if not found then print('(no matching job queued — Part 1 is the useful half)') end
print('')