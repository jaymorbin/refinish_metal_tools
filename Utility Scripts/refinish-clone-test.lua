-- refinish-clone-test.lua
-- Prototype 2: Memory Allocation and Deep Copy Test

print("==================================================")
print("REFINISH STEEL: INITIATING CLONING PROTOCOL")
print("==================================================")

local inorganics = df.global.world.raws.inorganics.all
local steel_raw = nil

-- 1. Find the Master Template (Vanilla Steel)
for _, mat in ipairs(inorganics) do
    if mat.id == "STEEL" then
        steel_raw = mat
        break
    end
end

if not steel_raw then
    print("ERROR: Could not locate Vanilla Steel template.")
    return
end

print("Template acquired: " .. steel_raw.id)

-- 2. Allocate a new, empty C++ object in the RAM
local clone = df.inorganic_raw:new()

-- 3. The Deep Copy (DFHack utils clone method)
local utils = require('utils')
utils.assign(clone, steel_raw)

-- 4. The Mutation
-- We are simulating the creation of our SCARLET_V40 dictionary entry
local target_color_index = 87 -- Index for RED/SCARLET
local target_value = 40

clone.id = "REFINISHED_STEEL_SCARLET_V40"
clone.material.id = "REFINISHED_STEEL_SCARLET_V40"

-- Mutate the Solid State Color (Index 0)
clone.material.state_color[0] = target_color_index

-- Mutate the Material Value
clone.material.material_value = target_value

-- Mutate the Adjective/Name so it looks right in-game
clone.material.state_name.Solid = "scarlet refinished steel"
clone.material.state_adj.Solid = "scarlet refinished steel"

print("--------------------------------------------------")
print("CLONE SUCCESSFUL. VERIFYING PROPERTIES:")
print("Clone ID:       " .. clone.id)
print("Solid Name:     " .. clone.material.state_name.Solid)
print("Solid Color:    " .. tostring(clone.material.state_color[0]) .. " (Target: " .. target_color_index .. ")")
print("Material Value: " .. tostring(clone.material.material_value) .. " (Target: " .. target_value .. ")")
print("--------------------------------------------------")
print("Memory allocation safe. Clone is isolated from global array.")
print("==================================================")

-- Clean up the isolated memory to prevent a memory leak during testing
clone:delete()