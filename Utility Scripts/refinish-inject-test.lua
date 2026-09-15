-- refinish-inject-test.lua
-- Prototype 3: Global Array Injection

print("==================================================")
print("REFINISH STEEL: INITIATING GLOBAL INJECTION")
print("==================================================")

local inorganics = df.global.world.raws.inorganics.all
local steel_raw = nil

for _, mat in ipairs(inorganics) do
    if mat.id == "STEEL" then
        steel_raw = mat
        break
    end
end

if not steel_raw then return end

-- 1. Create and Mutate the Clone
local clone = df.inorganic_raw:new()
local utils = require('utils')
utils.assign(clone, steel_raw)

clone.id = "REFINISHED_STEEL_SCARLET_V40_TEST"
clone.material.id = "REFINISHED_STEEL_SCARLET_V40_TEST"
clone.material.state_color[0] = 87
clone.material.material_value = 40
clone.material.state_name.Solid = "scarlet refinished steel"
clone.material.state_adj.Solid = "scarlet refinished steel"

-- 2. THE INJECTION
-- Record the size of the array before we touch it
local old_size = #inorganics

-- Push the clone to the absolute end of the global array
inorganics:insert('#', clone)

-- 3. THE VERIFICATION
local new_size = #inorganics
local injected_index = new_size - 1
local retrieved_mat = inorganics[injected_index]

print("Array Size Before: " .. old_size)
print("Array Size After:  " .. new_size)
print("--------------------------------------------------")

if retrieved_mat.id == "REFINISHED_STEEL_SCARLET_V40_TEST" then
    print("SUCCESS: Material successfully injected into Global Array at Index " .. injected_index)
    print("Engine recognizes new ID: " .. retrieved_mat.id)
else
    print("CRITICAL FAILURE: Memory rejection.")
end
print("==================================================")