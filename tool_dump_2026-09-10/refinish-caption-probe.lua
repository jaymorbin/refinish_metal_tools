-- refinish-caption-probe.lua
-- ==========================================
-- THE "BARS" CAPTION: IS IT WRITABLE, AND DOES DF READ IT
-- ==========================================
-- df.item_type.attrs[BAR].caption reads "bars". Two questions the
-- last probe did not ask, and they are different questions:
--
--   1. Can it be written at all.
--   2. If it can, does the NAME ON SCREEN change, or only what
--      DFHack reports about itself.
--
-- Question 2 is the whole thing. dfhack.items.getDescription calls
-- DF's own description vmethod, so it IS the in game name: if
-- blanking the caption changes that string, the suffix is ours. If
-- the write takes and the name does not move, the table is DFHack's
-- own metadata mirroring DF rather than feeding it, and the word on
-- screen comes from somewhere this cannot reach.
--
-- Everything is restored before the script returns.
--
-- USAGE
--   refinish-caption-probe
-- ==========================================

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end

local function describe(it)
    local d = '?'
    pcall(function() d = dfhack.items.getDescription(it, 0) end)
    return tostring(d)
end

-- Any inorganic bar. That is the branch that appends the word.
local bar
pcall(function()
    for _, it in ipairs(df.global.world.items.all) do
        if it:getType() == df.item_type.BAR then
            local mi = dfhack.matinfo.decode(it)
            if mi and tostring(mi.mode) == 'inorganic' then bar = it return end
        end
    end
end)

hr('SUBJECT')
if not bar then
    p('  No inorganic bar in the fort. Forge one and run this again.')
    return
end
p('  ' .. describe(bar))

-- ==========================================
-- 1. THE WRITE
-- ==========================================
-- Attempted three ways, because an enum attribute table can be a
-- plain Lua table, a DFHack owned struct array, or read only. Each
-- attempt reports what happened rather than assuming.
-- ==========================================
hr('1. writing the caption')
local attrs, entry, before_cap
pcall(function() attrs = df.item_type.attrs end)
pcall(function() entry = attrs[df.item_type.BAR] end)
pcall(function() before_cap = tostring(entry.caption) end)
p('  caption before        ' .. tostring(before_cap))

local wrote, why = false, nil
local ok, err = pcall(function() entry.caption = '' end)
if not ok then why = tostring(err) end
local after_cap = nil
pcall(function() after_cap = tostring(entry.caption) end)
p('  caption after write   ' .. tostring(after_cap))
if why then
    p('  the write threw:      ' .. why)
elseif after_cap == '' then
    wrote = true
    p('  the write TOOK.')
else
    p('  the write was accepted and silently did not stick, which is')
    p('  what a read only struct array does.')
end

-- ==========================================
-- 2. DOES THE NAME MOVE
-- ==========================================
-- The only question that matters. Read the same bar again with the
-- caption blank.
-- ==========================================
hr('2. the name with the caption blank')
local now = describe(bar)
p('  ' .. now)
if wrote then
    if now:lower():find('bar') then
        p('')
        p('  The caption is blank and the bar still says bars. So this')
        p('  table is DFHack metadata about DF, not the string DF')
        p('  renders from. The word is in the executable.')
    else
        p('')
        p('  THE SUFFIX IS GONE. The caption is the string, and it is')
        p('  writable. Note it is PER ITEM TYPE, not per material, so')
        p('  this blanks the word for every bar in the game, steel and')
        p('  charcoal alike. Section 3 says what that costs.')
    end
end

-- ==========================================
-- 3. WHAT ELSE READS IT
-- ==========================================
-- If the write worked, the same caption is what DFHack tools, and
-- anything else asking the enum, use to name a bar. Printed so the
-- cost of blanking it is visible rather than discovered later.
-- ==========================================
if wrote then
    hr('3. the same caption elsewhere')
    for _, t in ipairs({ 'BAR', 'BLOCKS', 'BOULDER', 'WOOD', 'ROCK' }) do
        local c = nil
        pcall(function() c = tostring(df.item_type.attrs[df.item_type[t]].caption) end)
        p(string.format('  %-10s %s', t, tostring(c)))
    end
end

-- ==========================================
-- RESTORE
-- ==========================================
if wrote then
    pcall(function() entry.caption = before_cap end)
    local back = nil
    pcall(function() back = tostring(entry.caption) end)
    hr('RESTORED')
    p('  caption  ' .. tostring(back))
    p('  bar      ' .. describe(bar))
else
    hr('NOTHING TO RESTORE')
    p('  The caption was never changed.')
end
p('')
