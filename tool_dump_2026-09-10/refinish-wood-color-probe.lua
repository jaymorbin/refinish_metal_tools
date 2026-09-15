-- refinish-wood-color-probe.lua
-- =====================================================================
-- WOOD COLOR CENSUS
-- Walks every plant in the loaded raws, finds its WOOD material, and
-- reports the distinct solid-state color tokens in use, with example
-- trees for each. The bark dye palette is authored from this output:
-- one bark dye material per token that appears here, and the watcher
-- maps token to material at job completion. Nothing is curated; the
-- world says which colors exist.
--
-- Run with a world loaded. Output goes to the DFHack console.
-- =====================================================================

local colors = df.global.world.raws.descriptors.colors

-- token -> { count = n, examples = { plant ids } }
local seen = {}
local wood_total = 0

for _, plant in ipairs(df.global.world.raws.plants.all) do
    for _, mat in ipairs(plant.material) do
        if mat.id == 'WOOD' then
            wood_total = wood_total + 1

            -- state_color holds descriptor indices per matter state.
            -- Solid is the one a bark strip or a log displays.
            local idx = mat.state_color.Solid
            local token, name = 'NONE', 'none'
            if idx >= 0 and idx < #colors then
                token = colors[idx].id
                name  = colors[idx].name
            end

            local slot = seen[token]
            if not slot then
                slot = { count = 0, name = name, examples = {} }
                seen[token] = slot
            end
            slot.count = slot.count + 1
            if #slot.examples < 4 then
                table.insert(slot.examples, plant.id)
            end
        end
    end
end

-- sorted report, most common first
local order = {}
for token in pairs(seen) do table.insert(order, token) end
table.sort(order, function(a, b) return seen[a].count > seen[b].count end)

print(('wood materials scanned: %d, distinct solid colors: %d')
      :format(wood_total, #order))
print('')
for _, token in ipairs(order) do
    local s = seen[token]
    print(('%-18s %-14s x%-3d  e.g. %s')
          :format(token, '(' .. s.name .. ')', s.count,
                  table.concat(s.examples, ', ')))
end
print('')
print('Palette rule: one bark dye material per token above. The')
print('watcher reads the bark item\'s wood material, takes this same')
print('Solid color index, and pays the matching dye. Tokens that gain')
print('no dye fall back to the brown entry.')
