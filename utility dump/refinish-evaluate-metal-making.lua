-- ==========================================
-- REFINISH STEEL: REACTION EVALUATOR (PROBE)
-- Purpose: Safely evaluates all loaded reactions to identify
-- METAL_MAKING candidates based STRICTLY on verified paths.
-- ==========================================

local function evaluate_reaction(reaction)
    local score = 0

    -- ==========================================
    -- PHASE 1: THE GUILLOTINE (Instant Elimination)
    -- ==========================================
    
    -- Must use the SMELT skill (ID 24)
    if reaction.skill ~= 24 then return 0 end
    
    -- Must have at least one product
    if not reaction.products or #reaction.products == 0 then return 0 end
    
    -- Must have building requirements
    if not reaction.building or not reaction.building.type or #reaction.building.type == 0 then return 0 end

    -- Verify it uses a FURNACE (Type 5)
    local has_furnace = false
    for _, b_type in ipairs(reaction.building.type) do
        if b_type == 5 then 
            has_furnace = true 
            break 
        end
    end
    if not has_furnace then return 0 end

    -- If it survives this far, it is at a furnace using the smelt skill.
    score = score + 10 

    -- ==========================================
    -- PHASE 2: THE SCORING MATRIX
    -- ==========================================

    -- 1. Evaluate Products (Max 40 points)
    for _, product in ipairs(reaction.products) do
        -- Looking for: item_type 0 (BAR) and mat_type 0 (INORGANIC)
        if product.item_type == 0 and product.mat_type == 0 then
            score = score + 20
            -- Check standard dimension
            if product.product_dimension == 150 then
                score = score + 20
            end
            break -- We only need to prove one product is a standard metal bar
        end
    end

    -- 2. Evaluate Reagents (Max 30 points)
    if reaction.reagents and #reaction.reagents > 0 then
        for _, reagent in ipairs(reaction.reagents) do
            -- Scenario A: Ore Smelting
            -- item_type 4 is BOULDER. mat_type is often -1 for ores waiting for reference targets
            if reagent.item_type == 4 then
                -- Verify the metal_ore reference target index exists and is valid
                if reagent.metal_ore and reagent.metal_ore >= 0 then
                    score = score + 30
                    break
                end
            -- Scenario B: Alloy Blending / Refining
            -- item_type 0 is BAR, mat_type 0 is INORGANIC
            elseif reagent.item_type == 0 and reagent.mat_type == 0 then
                score = score + 15 
            end
        end
    end

    -- 3. Evaluate Environment specifics (Max 20 points)
    for _, b_subtype in ipairs(reaction.building.subtype) do
        if b_subtype == 1 or b_subtype == 4 then -- 1 = Smelter, 4 = Magma Smelter
            score = score + 10
            break
        end
    end

    if reaction.flags.FUEL then
        score = score + 10
    end

    -- ==========================================
    -- PHASE 3: RAW STRING CONTINGENCY (Max 10 points)
    -- ==========================================
    -- Fallback verification using the linear raw_strings array you mapped
    if reaction.raw_strings then
        for _, raw_str_obj in ipairs(reaction.raw_strings) do
            local str_val = raw_str_obj.value
            -- Look for the standard PRODUCT syntax requiring BAR and METAL
            if str_val and string.find(str_val, "%[PRODUCT:.*:.*:BAR:.*:METAL:.*%]") then
                score = score + 10
                break
            end
        end
    end

    return score
end

local function run_evaluation()
    print("\n==========================================")
    print("REFINISH STEEL: REACTION EVALUATION START")
    print("==========================================\n")

    local scored_reactions = {}
    local count = 0

    for i, reaction in ipairs(df.global.world.raws.reactions.reactions) do
        local r_score = evaluate_reaction(reaction)
        if r_score > 0 then
            table.insert(scored_reactions, {
                code = reaction.code, 
                score = r_score, 
                index = i
            })
            count = count + 1
        end
    end

    -- Sort descending by score
    table.sort(scored_reactions, function(a, b) return a.score > b.score end)

    print(string.format("Evaluation complete. Found %d potential metal-making reactions.\n", count))
    print("TOP SCORING REACTIONS:")
    print("------------------------------------------")
    
    for _, data in ipairs(scored_reactions) do
        print(string.format("Score: %3d | Index: %4d | Code: %s", data.score, data.index, data.code))
    end
    
    print("\n==========================================")
    print("REFINISH STEEL: REACTION EVALUATION END")
    print("==========================================\n")
end

run_evaluation()