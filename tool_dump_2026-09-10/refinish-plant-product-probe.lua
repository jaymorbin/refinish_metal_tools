-- refinish-plant-product-probe.lua
-- ==========================================
-- CAN A REACTION PRODUCE A PLANT MATERIAL
-- ==========================================
-- createItem mints a bar of a plant material: proven, it read
-- "charcoal" and carried dimension 150. A REACTION product is a
-- different function, reaction_product_itemst::produce, and nothing
-- in vanilla names a plant material on a product directly. Vanilla
-- reaches plant materials through GET_MATERIAL_FROM_REAGENT instead,
-- so there is no precedent to read.
--
-- That one unknown decides the whole shape of the cinder work:
--
--   PRODUCES   the engine gets a product type that resolves a plant
--              token at build time, cinders become bars, and no
--              watcher is involved anywhere.
--   DOES NOT   reactions keep minting an inorganic token material
--              and the coal watcher converts it on creation, the
--              way the coals already work.
--
-- WHAT THIS DOES
--   Writes the plant material straight into one product slot of one
--   live reaction. Nothing is cloned and no new reaction appears:
--   the slot is patched, you run the job once, and it goes back.
--
-- A RECYCLE ALSO UNDOES IT. Reactions are rebuilt from the JSON on
-- every injection, so a forgotten restore costs nothing past the
-- next launch.
--
-- USAGE
--   refinish-plant-product-probe                     show and set
--   refinish-plant-product-probe restore             put it back
--   refinish-plant-product-probe set <CODE> <SLOT>   pick another
--
-- CODE is a full reaction code. The default is the cinder packing
-- reaction, which is fixed count and takes four cinders.
-- ==========================================

local args   = {...}
local verb   = args[1] or 'set'
local CODE   = args[2] or 'MAKING_FUEL_RXN_CHAR_CINDERS'
local SLOT   = tonumber(args[3]) or 0
local TOKEN  = 'PLANT_MAT:MAKING_FUEL_COAL_HOST:CHARCOAL'

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end

-- Survives between invocations, because setting and restoring are
-- two separate runs with a job in between.
_G.refinish_plant_product_saved = _G.refinish_plant_product_saved or {}
local saved = _G.refinish_plant_product_saved

local function find_reaction(code)
    for _, r in ipairs(df.global.world.raws.reactions.reactions) do
        if tostring(r.code) == code then return r end
    end
    return nil
end

-- ==========================================
-- RESTORE
-- ==========================================
if verb == 'restore' then
    hr('RESTORE')
    local n = 0
    for key, s in pairs(saved) do
        local r = find_reaction(s.code)
        if r and r.products[s.slot] then
            pcall(function()
                r.products[s.slot].mat_type  = s.mat_type
                r.products[s.slot].mat_index = s.mat_index
            end)
            p('  ' .. s.code .. ' slot ' .. s.slot .. ' -> '
              .. s.mat_type .. '/' .. s.mat_index)
            n = n + 1
        end
        saved[key] = nil
    end
    if n == 0 then p('  nothing was patched.') end
    p('')
    return
end

-- ==========================================
-- SET
-- ==========================================
local rxn = find_reaction(CODE)
hr('REACTION')
if not rxn then
    p('  no reaction with code ' .. CODE)
    p('  Pass a full code as the second argument.')
    return
end
p('  ' .. CODE)
p('  name                ' .. tostring(rxn.name))

-- What to feed it, so the job can be run without hunting.
p('')
p('  reagents:')
for i, rg in ipairs(rxn.reagents) do
    local t = '?'
    pcall(function() t = tostring(df.item_type[rg.item_type]) end)
    p(string.format('    [%d] %s x%s  mat %s/%s',
        i - 1, t, tostring(rg.quantity),
        tostring(rg.mat_type), tostring(rg.mat_index)))
end
p('')
p('  products:')
for i = 0, #rxn.products - 1 do
    local pr = rxn.products[i]
    local t, mat = '?', '?'
    pcall(function() t = tostring(df.item_type[pr.item_type]) end)
    pcall(function()
        local mi = dfhack.matinfo.decode(pr.mat_type, pr.mat_index)
        mat = mi and mi:getToken() or (pr.mat_type .. '/' .. pr.mat_index)
    end)
    p(string.format('    [%d] %s x%s dim %s  %s%s',
        i, t, tostring(pr.count), tostring(pr.product_dimension), mat,
        i == SLOT and '   <-- patching this one' or ''))
end

local mi = nil
pcall(function() mi = dfhack.matinfo.find(TOKEN) end)
hr('THE PLANT MATERIAL')
if not mi then
    p('  ' .. TOKEN .. ' does not resolve. Is the host injected?')
    return
end
p('  ' .. TOKEN)
p('  mat_type/index      ' .. tostring(mi.type) .. ' / ' .. tostring(mi.index))

local slot = rxn.products[SLOT]
if not slot then
    hr('NO SUCH SLOT')
    p('  product slot ' .. SLOT .. ' does not exist on this reaction.')
    return
end

saved[CODE .. ':' .. SLOT] = {
    code = CODE, slot = SLOT,
    mat_type = slot.mat_type, mat_index = slot.mat_index,
}
pcall(function()
    slot.mat_type  = mi.type
    slot.mat_index = mi.index
end)

hr('PATCHED')
p('  ' .. CODE .. ' slot ' .. SLOT .. ' now names ' .. TOKEN)
p('')
p('  Queue the job once and look at what drops.')
p('')
p('    a bar reading "charcoal"   the product code handles plant')
p('                               materials, and cinders can be bars')
p('                               with no watcher anywhere')
p('    nothing produced           it does not, and the cinder takes')
p('                               the coal route: an inorganic token')
p('                               material converted on creation')
p('    a rock, or a bar of the    it produced SOMETHING else, which')
p('    wrong thing                is its own answer, write down what')
p('')
p('  Then: refinish-plant-product-probe restore')
p('  A recycle undoes it too.')
p('')
