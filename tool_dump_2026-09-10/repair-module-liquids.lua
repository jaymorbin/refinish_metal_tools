-- repair-module-liquids.lua
-- ==========================================
-- ONE PURPOSE: repair first generation module liquids minted with
-- stack_size 0, the malformation the pitch probe measured on tar
-- #1098. DF's consume path rejects a stack 0 liquid: the boil
-- completes, the tar survives untouched, the ghost rightly reports
-- NOT CONSUMED, and the purse rightly discards the credit. That
-- discard is the anti exploit working; the item is the fault.
--
-- Items minted after the injector's string vector fix come out
-- healthy: tar #1109 reads stack 1. This repairs the leftovers.
--
-- WHAT IT DOES
--   1. Every LIQUID_MISC carrying a MAKING_FUEL material with
--      stack_size below 1 gets stack_size = 1. Dimension is not
--      touched; 150 measured correct on the malformed item.
--   2. Any OTHER item type carrying a MAKING_FUEL material with
--      stack_size below 1 is REPORTED ONLY, so a second class of
--      leftover cannot hide behind this pass.
--
-- Safe to rerun; a healthy world prints zero repairs. State only,
-- no recycle needed:
--   dfhack> lua dofile('repair-module-liquids.lua')
--
-- THE TEST AFTER
--   Queue one boil on the repaired tar. The ledger should read
--   BURNED and print a 'carried in BANK_PITCH' line. The purse
--   then holds a third, and the third boil pays the first pitch
--   boulder. If a repaired tar still refuses to drain, stack was
--   not the whole malformation: report back and those items get
--   dumped and reminted instead. Measure before more machinery.
-- ==========================================

local repaired, flagged = 0, 0

-- Is this item made of a module material? Token match, the same
-- handle the classifier trusts, because getMaterial style accessors
-- lie on too many types to lean on here.
local function module_mat(it)
    local tok = nil
    pcall(function()
        local mi = dfhack.matinfo.decode(it)
        if mi then tok = tostring(mi:getToken()):upper() end
    end)
    if tok and tok:find('MAKING_FUEL_', 1, true) then
        return true, tok
    end
    return false, tok
end

print('==== MODULE LIQUID REPAIR ====')
for _, it in ipairs(df.global.world.items.all) do
    local sz = nil
    pcall(function() sz = it.stack_size end)
    if sz ~= nil and sz < 1 then
        local is_mod, tok = module_mat(it)
        if is_mod then
            local desc = '?'
            pcall(function() desc = dfhack.items.getDescription(it, 0) end)
            if it:getType() == df.item_type.LIQUID_MISC then
                local ok = pcall(function() it.stack_size = 1 end)
                if ok then
                    repaired = repaired + 1
                    print(string.format(
                        'repaired #%d  %s  stack %d -> 1',
                        it.id, tostring(desc), sz))
                else
                    -- A write that fails is a finding, not a shrug.
                    print(string.format(
                        'WRITE FAILED #%d  %s  stack=%d',
                        it.id, tostring(desc), sz))
                end
            else
                flagged = flagged + 1
                print(string.format(
                    'REPORT ONLY #%d  type=%s  %s  stack=%d',
                    it.id, tostring(df.item_type[it:getType()]),
                    tostring(desc), sz))
            end
        end
    end
end
print(string.format('---- %d repaired, %d reported only ----',
    repaired, flagged))
print('==== END ====')
