--@ module = false
-- refinish-inv-probe.lua

print("==================================================")
print("PROBING FORTRESS INVENTORY: BARS & POWDERS")
print("==================================================")

local unique_bars = {}
local unique_powders = {}

-- 1. Probe the BAR vector
if df.global.world.items.other.BAR then
    local start_time = os.clock()
    local bar_count = 0
    
    for _, item in ipairs(df.global.world.items.other.BAR) do
        -- Only check items that are available (on ground, in stockpiles/bins)
        if item.flags.on_ground or item.flags.in_inventory or item.flags.in_building or item.flags.in_container then
            local hash = item.mat_type .. "_" .. item.mat_index
            
            if not unique_bars[hash] then
                unique_bars[hash] = {type = item.mat_type, index = item.mat_index, count = 1}
            else
                unique_bars[hash].count = unique_bars[hash].count + 1
            end
            bar_count = bar_count + 1
        end
    end
    
    local elapsed = os.clock() - start_time
    print(string.format("Scanned %d valid Bar items in %.4f seconds.", bar_count, elapsed))
    for hash, data in pairs(unique_bars) do
        print(string.format("  -> Found Bar Material [Type: %d, Index: %d] (Qty: %d)", data.type, data.index, data.count))
    end
else
    print("PROBE FAILED: No BAR vector found.")
end

-- 2. Probe the POWDER vector
if df.global.world.items.other.POWDER_MISC then
    local start_time = os.clock()
    local powder_count = 0
    
    for _, item in ipairs(df.global.world.items.other.POWDER_MISC) do
        if item.flags.on_ground or item.flags.in_inventory or item.flags.in_building or item.flags.in_container then
            local hash = item.mat_type .. "_" .. item.mat_index
            
            if not unique_powders[hash] then
                unique_powders[hash] = {type = item.mat_type, index = item.mat_index, count = 1}
            else
                unique_powders[hash].count = unique_powders[hash].count + 1
            end
            powder_count = powder_count + 1
        end
    end
    
    local elapsed = os.clock() - start_time
    print(string.format("\nScanned %d valid Powder items in %.4f seconds.", powder_count, elapsed))
    for hash, data in pairs(unique_powders) do
        print(string.format("  -> Found Powder Material [Type: %d, Index: %d] (Qty: %d)", data.type, data.index, data.count))
    end
else
    print("PROBE FAILED: No POWDER_MISC vector found.")
end

print("==================================================")