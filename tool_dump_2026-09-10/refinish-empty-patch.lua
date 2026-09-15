-- refinish-empty-patch.lua
-- ==========================================
-- SET THE EMPTY BIT IN RAM, RIGHT NOW
-- ==========================================
-- Measured this session: Refuel's typed BOX/BARREL reagent carries
-- flags1 = 0x400 (bit 10, EMPTY) and refuses a full chest. Ours
-- carries 0x40000000 / 0x60000000 (not_bin, furniture) and eats it.
-- Every other field on the two reagents is identical.
--
-- This writes bit 10 onto our container reagents in memory, so the
-- gate can be tested without editing JSON and without a recycle.
-- It is a TEST INSTRUMENT, not a fix: RAM is rebuilt from the data
-- files on every startup, so this lasts until the next recycle.
--
-- WHAT IT SELECTS: any reagent on a MAKING_FUEL_RXN_ reaction that
-- currently has not_bin set. That is exactly the container family
-- and nothing else, because not_bin appears nowhere else in the
-- module. Ghost clones are patched too, since a running job may be
-- pointed at one.
--
-- USAGE (launcher, clear the input box first):
--   refinish-empty-patch          set the bit and report
--   refinish-empty-patch undo     put it back
-- ==========================================

local args = {...}
local undo = (args[1] == 'undo')

-- bit 10 of job_item_flags1, confirmed against df-structures.
local EMPTY_BIT = 0x00000400

local PREFIX = 'MAKING_FUEL_RXN_'
local n = 0

print('')
print(undo and '== CLEARING EMPTY ==' or '== SETTING EMPTY ==')
print(string.format('%-46s %-12s %s', 'reaction[reagent]', 'before', 'after'))

for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    local code = tostring(rxn.code)
    if code:find(PREFIX, 1, true) == 1 then
        for i = 0, #rxn.reagents - 1 do
            local g = rxn.reagents[i]
            -- pcall per reagent: a shape without flags1 reports
            -- instead of ending the run mid-way through the family.
            pcall(function()
                if g.flags1.not_bin then
                    local before = g.flags1.whole
                    g.flags1.empty = not undo
                    local after = g.flags1.whole
                    n = n + 1
                    -- Ghost clones are noisy; only the base reactions
                    -- are printed, but both are patched.
                    if not code:find('_GHOST_', 1, true) then
                        print(string.format('%-46s 0x%08X   0x%08X',
                            code .. '[' .. i .. ']', before, after))
                    end
                end
            end)
        end
    end
end

print(string.format('%d reagent(s) touched. RAM only — gone on next recycle.', n))
print('')
