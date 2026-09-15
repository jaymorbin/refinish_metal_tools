local civ = df.historical_entity.find(df.global.plotinfo.civ_id)
local group = df.historical_entity.find(df.global.plotinfo.group_id)

local red_idx = -1
local blue_idx = -1

-- 1. Find the exact memory indexes of our injected metals
for i, mat in ipairs(df.global.world.raws.inorganics.all) do
    if mat.id == "REFINISHED_STEEL_RED" then red_idx = i end
    if mat.id == "REFINISHED_STEEL_BLUE" then blue_idx = i end
end

-- 2. Helper function to append the metals to the civilization's authorized list
local function authorize_metal(ent, mat_idx)
    if not ent or mat_idx == -1 then return end
    
    -- Check if it's already authorized to prevent duplicates
    for _, id in ipairs(ent.resources.metals) do
        if id == mat_idx then return end 
    end
    
    ent.resources.metals:insert(#ent.resources.metals, mat_idx)
end

-- 3. Authorize them for both the global Civ and the local Fortress Group
authorize_metal(civ, red_idx)
authorize_metal(civ, blue_idx)
authorize_metal(group, red_idx)
authorize_metal(group, blue_idx)

print("Red and Blue Steel have been authorized for your civilization!")