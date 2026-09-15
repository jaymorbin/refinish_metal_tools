-- refinish-scan.lua
-- Prototype 1.1: State Color & Value Dictionary Builder

local inorganics = df.global.world.raws.inorganics.all
local color_descriptors = df.global.world.raws.descriptors.colors
local combinations = {}
local total_scanned = 0
local unique_count = 0

print("==================================================")
print("REFINISH STEEL: INITIATING V50 STATE_COLOR SCANNER")
print("==================================================")

for i, mat in ipairs(inorganics) do
    -- Skip our own injected materials
    if not string.find(mat.id, "REFINISHED") then
        local material = mat.material
        
        -- Extract the Solid state_color index (df.matter_state.Solid is 0)
        local color_index = material.state_color[0]
        
        -- Map the integer back to the human-readable color string
        local color_name = "UNKNOWN"
        if color_index >= 0 and color_index < #color_descriptors then
            color_name = color_descriptors[color_index].id
        end
        
        -- Extract the Material Value
        local value = material.material_value

        -- Generate the unique dictionary key (e.g., "ASH_GRAY_V10")
        local key = string.format("%s_V%d", color_name, value)

        -- Build the Dictionary
        if not combinations[key] then
            combinations[key] = {
                count = 1,
                example_id = mat.id,
                color = color_name,
                value = value
            }
            unique_count = unique_count + 1
        else
            combinations[key].count = combinations[key].count + 1
        end
        
        total_scanned = total_scanned + 1
    end
end

print(string.format("Scan complete. Processed %d native inorganics.", total_scanned))
print(string.format("Found %d UNIQUE [State Color + Value] combinations.", unique_count))
print("--------------------------------------------------")

-- Print a sample to verify
local print_limit = 20
local printed = 0

for key, data in pairs(combinations) do
    if printed < print_limit then
        print(string.format("Key: %-25s | Example Reagent: %-15s | Shared by %d materials", key, data.example_id, data.count))
        printed = printed + 1
    end
end

if unique_count > print_limit then
    print("...")
end
print("==================================================")