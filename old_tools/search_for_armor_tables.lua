local function search_keys(table_to_search, path_name)
    -- Wrap in a pcall in case a specific DF structure throws an exception when accessed
    local ok, err = pcall(function()
        for k, v in pairs(table_to_search) do
            local key_str = tostring(k):lower()
            -- Look for any table keys containing these keywords
            if key_str:find("armor") or key_str:find("metal") or key_str:find("weapon") then
                print("Found potential match: " .. path_name .. "." .. tostring(k) .. " (" .. type(v) .. ")")
            end
        end
    end)
    if not ok then print("Skipped " .. path_name .. " due to access error.") end
end

print("=== SEARCHING RAWS ===")
search_keys(df.global.world.raws, "df.global.world.raws")

print("=== SEARCHING ITEMDEFS ===")
search_keys(df.global.world.raws.itemdefs, "df.global.world.raws.itemdefs")

print("=== SEARCHING GLOBAL ===")
-- Sometimes UI or stockpile caches are held at the very top level
search_keys(df.global, "df.global")