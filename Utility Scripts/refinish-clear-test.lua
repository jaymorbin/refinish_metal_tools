-- ==========================================
-- SCRIPT LOGIC
-- ==========================================
local raws = df.global.world.raws.inorganics.all
local count = 0

-- Iterate backwards to safely remove items from the vector without shifting targets
for i = #raws - 1, 0, -1 do
    if string.find(raws[i].id, "REFINISHED") then
        raws:erase(i)
        count = count + 1
    end
end

if count > 0 then
    print("Refinish Steel: Cleared " .. count .. " custom indices. RAM safely compressed.")
else
    print("Refinish Steel: No custom materials found. Memory is pristine.")
end

-- Toggle state manager at the absolute end of the file
_G.refinish_ram_loaded = false