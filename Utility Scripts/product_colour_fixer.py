import re

def swap_color_names_for_ids(color_definitions_text, product_list_text):
    # 1. Parse color definitions to create a Mapping: {NAME: IDENTIFIER}
    # Pattern looks for [COLOR:ID] followed by [NAME:name]
    color_map = {}
    
    # Split the color file into individual blocks to ensure we pair ID and NAME correctly
    color_blocks = re.split(r'(?=\[COLOR:)', color_definitions_text)
    
    for block in color_blocks:
        if not block.strip():
            continue
        
        id_match = re.search(r'\[COLOR:([^\]]+)\]', block)
        name_match = re.search(r'\[NAME:([^\]]+)\]', block)
        
        if id_match and name_match:
            color_id = id_match.group(1).strip()
            color_name = name_match.group(2).strip() if len(name_match.groups()) > 1 else name_match.group(1).strip()
            # Map the NAME to the ID
            color_map[color_name] = color_id

    # 2. Process the product list
    # Pattern captures the prefix, the name to be replaced, and the suffix
    # e.g. [PRODUCT:100:3:BAR:NONE:INORGANIC:][matte-silver][_COLOUR_STEEL_FINISH]
    new_products = []
    
    for line in product_list_text.strip().split('\n'):
        if not line.strip():
            continue
            
        updated_line = line
        # Check every color name we found to see if it exists in this line
        for name, identifier in color_map.items():
            # We look for the name specifically where it appears before "_COLOUR_STEEL_FINISH"
            target_string = f"{name}_COLOUR_STEEL_FINISH"
            if target_string in updated_line:
                replacement_string = f"{identifier}_COLOUR_STEEL_FINISH"
                updated_line = updated_line.replace(target_string, replacement_string)
        
        new_products.append(updated_line)

    # 3. Output results
    print("--- Updated Product List ---")
    print("\n".join(new_products))

# --- DATA INPUTS ---

color_file = """
[COLOR:AKRULTHAS_BRONZE]
    [NAME:shining-bronze]
  [WORD:BRONZE]
    [WORD:METAL]
  [RGB:191:126:18]

[COLOR:GUNMETAL]
    [NAME:red-brass]
  [WORD:BRASS]
    [WORD:METAL]
  [RGB:178:100:32]

[COLOR:GOBRONZE]
    [NAME:muted-bronze]
  [WORD:BRONZE]
    [WORD:METAL]
  [RGB:124:85:74]

[COLOR:ORICHALCUM]
    [NAME:golden-bronze]
  [WORD:BRONZE]
    [WORD:METAL]
  [RGB:232:179:26]

[COLOR:MITHRIL]
    [NAME:bright-silver]
  [WORD:SILVER]
    [WORD:METAL]
  [RGB:208:204:204]

[COLOR:DANMANKEL]
    [NAME:mauve-steel]
  [WORD:HEAVY]
    [WORD:METAL]
  [RGB:125:123:131]

[COLOR:ELGILRIL]
    [NAME:gleaming-chrome]
  [WORD:SPECIAL]
    [WORD:METAL]
  [RGB:164:168:168]

[COLOR:RELARKEL]
    [NAME:matte-silver]
  [WORD:ROYAL]
    [WORD:METAL]
  [RGB:157:147:148]

[COLOR:ARSENIC_BRONZE]
    [NAME:arsenical-bronze]
  [WORD:BRONZE]
    [WORD:METAL]
  [RGB:124:114:108]

[COLOR:ANTIMONY_BRONZE]
    [NAME:antimonial-bronze]
  [WORD:BRONZE]
    [WORD:METAL]
  [RGB:160:162:167]

[COLOR:MONEL]
    [NAME:burnished-nickel]
  [WORD:GRAY]
    [WORD:METAL]
  [RGB:167:165:167]

[COLOR:AKIMRIL]
    [NAME:titanium-silver]
  [WORD:SILVER]
    [WORD:METAL]
  [RGB:168:169:176]

[COLOR:CUPRONICKEL]
    [NAME:cupronickel]
  [WORD:COPPER]
    [WORD:METAL]
  [RGB:172:152:143]

[COLOR:CONIMOCRIL]
    [NAME:nickel-gray]
  [WORD:SILVER]
    [WORD:METAL]
  [RGB:151:162:163]

[COLOR:COBALTITE]
    [NAME:silvery-cobalt]
  [WORD:COBALT]
    [WORD:METAL]
  [RGB:151:181:195]

[COLOR:NICORIL]
    [NAME:steely-blue]
  [WORD:COBALT]
    [WORD:METAL]
  [RGB:145:160:175]

[COLOR:IRIDIUM]
    [NAME:iridescent-platinum]
  [WORD:RARE]
    [WORD:METAL]
  [RGB:151:146:158]

[COLOR:UMASTEEL]
    [NAME:earthen-green]
  [WORD:GREEN]
    [WORD:METAL]
  [RGB:101:120:91]

[COLOR:REDSTEEL]
    [NAME:red-steel]
  [WORD:RED]
    [WORD:METAL]
  [RGB:87:39:40]
  
[COLOR:BISMANGAZ_BRONZE]
    [NAME:deep-bronze]
  [WORD:METAL]
    [WORD:METAL]
  [RGB:178:125:54]

[COLOR:ALACRIL]
    [NAME:polished-nickel]
  [WORD:SILVER]
    [WORD:METAL]
  [RGB:147:152:155]

[COLOR:DAMASCUS]
    [NAME:dappled-gray]
  [WORD:PATTERN]
    [WORD:METAL]
  [RGB:116:127:134]

[COLOR:HARDSTEEL]
    [NAME:tungsten-gray]
  [WORD:HARDINESS]
    [WORD:METAL]
  [RGB:130:133:135]

[COLOR:BRIGHTSTEEL]
    [NAME:mirrored-steel]
  [WORD:BRIGHT]
    [WORD:METAL]
  [RGB:203:208:210]

[COLOR:EMENRIL]
    [NAME:titanium-gray]
  [WORD:SILVER]
    [WORD:METAL]
  [RGB:176:173:172]
  
[COLOR:DARKSTEEL]
    [NAME:blackened-iron]
  [WORD:BLACK]
    [WORD:METAL]
  [RGB:86:89:95]

[COLOR:RUBEDITIUM]
    [NAME:deep-red]
  [WORD:RED]
    [WORD:METAL]
  [RGB:141:33:20]

"""

product_file = """
[PRODUCT:100:3:BAR:NONE:INORGANIC:tungsten-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:blue-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:silvery-cobalt_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:iridescent-platinum_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:steely-blue_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:dappled-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:earthen-green_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:titanium-silver_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:tungsten-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:red-brass_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:burnished-nickel_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:arsenical-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:antimonial-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:muted-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:mirrored_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:dappled-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:blue-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:mirrored_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:tungsten-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:polished-nickel_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:gleaming-chrome_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:nickel-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:titanium-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:matte-silver_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:mauve-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:deep-red_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:golden-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:bright-silver_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:nickel-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:polished-nickel_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:silvery-cobalt_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:titanium-silver_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:dappled-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:tungsten-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:mirrored_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:gleaming-chrome_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:steely-blue_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:antimonial-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:shining-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:red-purple_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:blackened_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:nickel-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:titanium-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:steely-blue_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:arsenical-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:matte-silver_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:polished-nickel_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:blackened_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:red-brass_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:deep-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:tungsten-gray_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:muted-bronze_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:matte-silver_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:matte-silver_COLOUR_STEEL_FINISH]
[PRODUCT:100:3:BAR:NONE:INORGANIC:dappled-gray_COLOUR_STEEL_FINISH]
"""

swap_color_names_for_ids(color_file, product_file)