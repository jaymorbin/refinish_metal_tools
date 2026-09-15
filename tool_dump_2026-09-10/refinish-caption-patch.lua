-- refinish-caption-patch.lua
-- ==========================================
-- THE "BARS" CAPTION: WRITE IT THE HARD WAY
-- ==========================================
-- The plain write was refused with "raw pointer string". That is
-- DFHack declining to write through a const char* field. It is a
-- REFUSAL BY THE ACCESSOR, not a statement that the memory cannot be
-- written, and the two are different things. patchMemory writes
-- read only memory on purpose, which is what binpatches are built on.
--
-- So: find the byte the caption points at, write a NUL over the 'b',
-- read the bar's name again, put the byte back.
--
-- WHAT A RESULT MEANS
--   Name changes  the caption IS the string DF renders from, and
--                 the suffix is reachable. Per item type, not per
--                 material, so it would take steel bars with it.
--   Name does not the attrs table is DFHack's own metadata about
--                 DF rather than an input to it, and the word on
--                 screen is minted inside the executable. That is a
--                 measured ceiling rather than an assumed one.
--
-- The byte is restored either way, immediately, before the script
-- returns. Nothing persists and no save is touched.
--
-- USAGE
--   refinish-caption-patch
-- ==========================================

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end

local function describe(it)
    local d = '?'
    pcall(function() d = dfhack.items.getDescription(it, 0) end)
    return tostring(d)
end

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
-- FIND THE STRING
-- ==========================================
-- The attr entry is a struct; the caption field within it is a
-- pointer. _field returns a REF to the field rather than its value,
-- so the pointer itself can be read as a number and its target
-- reinterpreted as bytes.
-- ==========================================
hr('THE POINTER')
local entry, ref, addr
pcall(function() entry = df.item_type.attrs[df.item_type.BAR] end)
if not entry then p('  no attrs entry for BAR.') return end
pcall(function() ref = entry:_field('caption') end)
pcall(function() addr = ref and ref:tonumber() end)
if not addr or addr == 0 then
    -- Second route: some builds hand back the pointer directly.
    pcall(function() addr = tonumber(tostring(entry.caption)) end)
end
p('  caption reads         ' .. tostring(entry.caption))
p('  field ref             ' .. tostring(ref))
p('  target address        ' .. tostring(addr))
if not addr or addr == 0 then
    p('')
    p('  Could not resolve the string address, so there is nothing to')
    p('  patch. The accessor hides the pointer on this build.')
    return
end

-- ==========================================
-- PATCH ONE BYTE
-- ==========================================
-- A NUL at the front turns "bars" into the empty string without
-- moving anything or changing any length. One byte in, one byte back.
-- ==========================================
hr('PATCH')
local bytes = df.reinterpret_cast(df.uint8_t, addr)
if not bytes then p('  could not view the target as bytes.') return end

local original = nil
pcall(function() original = bytes[0] end)
p('  first byte            ' .. tostring(original)
  .. (original and (' (' .. string.char(original) .. ')') or ''))
if not original then p('  could not read it.') return end

local zero = df.new('uint8_t')
zero.value = 0
local ok_patch = false
pcall(function()
    ok_patch = dfhack.internal.patchMemory(addr, zero, 1)
end)
p('  patchMemory           ' .. tostring(ok_patch))
p('  caption now reads     ' .. tostring(entry.caption))

hr('THE NAME')
p('  ' .. describe(bar))

-- ==========================================
-- RESTORE, ALWAYS
-- ==========================================
local back = df.new('uint8_t')
back.value = original
pcall(function() dfhack.internal.patchMemory(addr, back, 1) end)
pcall(function() df.delete(zero) end)
pcall(function() df.delete(back) end)

hr('RESTORED')
p('  caption               ' .. tostring(entry.caption))
p('  bar                   ' .. describe(bar))
p('')
p('  If THE NAME above still said bars while the caption was empty,')
p('  that table is DFHack describing DF, not feeding it, and the')
p('  word lives in the executable.')
p('')
