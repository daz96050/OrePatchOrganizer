--[[
Mod - Internal only, to show compatibility
ResourceCategory - 'basic-fluid' etc
ResourceType - Fluid or Solid (For Settings, i.e. Only Solids or Only Fluids)
ResourceHandler - Spaced or Spread (For pasting, spread like Ores, or Space like Oil)
ResourceSpace - Machine Size to dictate space between resource patches
                Treated as a minimum. If the deposit's own footprint is larger, the footprint wins
                (See SetResourceOrganizer)
]]
Resource_Data = {}

local function AddToTable(Mod, ResourceCategory, ResourceType, ResourceHandler, ResourceSpace)
    Resource_Data[ResourceCategory] = {
            Mod = Mod,
            ResourceCategory = ResourceCategory,
            ResourceType = ResourceType,
            ResourceHandler = ResourceHandler,
            ResourceSpace = ResourceSpace
        }
end

function SetResourceOrganizer(Resource)
    --resource.prototype.resource_category
    local tmp = Resource_Data[Resource.prototype.resource_category]
    if tmp == nil then return end --Doesn't exist in configured resources
    if (Resource_Organizer.AllowSolids and tmp['ResourceType'] == 'solid') or (Resource_Organizer.AllowFluids and tmp['ResourceType'] == 'fluid') then
        Resource_Organizer.Category = Resource.prototype.resource_category
        Resource_Organizer.Handler = tmp['ResourceHandler']
        --A single category can hold several sizes of deposit (i.e. Pyanodon's oil-mk01 to oil-mk04 are all 'oil-derrick')
        --Take the larger of the configured machine size and the deposit's own footprint, so large deposits can't overlap
        Resource_Organizer.MachineSize = math.max(tmp['ResourceSpace'], Resource.prototype.tile_width,
            Resource.prototype.tile_height)
        Resource_Organizer.Name = Resource.name
        Resource_Organizer.Name_Localised = Resource.localised_name
    end
end

function ResetResourceOrganizer()
    Resource_Organizer.Name = ""
    Resource_Organizer.Count = 0
    Resource_Organizer.CountPerCell = 0
    Resource_Organizer.Surface = ""
    Resource_Organizer.Category = ""
    Resource_Organizer.Name_Localised = ""
    Resource_Organizer.Handler = ""
end


--[[
    WARNING WARNING WARNING
    Do not add duplicate ResourceCategory entries
    Only the first one will be picked (Usually)
    Custom handling may be added in the future if 2 mods have the same ResourceCategory with different mechanics

    solid/fluid & spread/spaced must be all lower case
]]

AddToTable("Vanilla", "basic-solid", "solid", "spread", 0)
AddToTable("Vanilla", "basic-fluid", "fluid", "spaced", 3)
AddToTable("Vanilla", "hard-solid", "solid", "spread", 0)


AddToTable("Krastorio2", "hard-resource", "solid", "spread", 0)
AddToTable("Krastorio2", "kr-quarry", "solid", "spaced", 7)
AddToTable("Krastorio2", "oil", "fluid", "spaced", 3)

AddToTable("Vortek_Deep_Core_Mining", "vtk-deepcore-mining-crack", "solid", "spaced", 9)
AddToTable("Vortek_Deep_Core_Mining", "vtk-deepcore-mining-ore-patch", "solid", "spaced", 5)

AddToTable("BZ_Natural_Gas", "gas", "fluid", "spaced", 3)

--Paracelsin's data-final-fixes moves other mods' vents into this category too: Vulcanus sulfuric-acid-geyser,
--fluorine-vent, Moshine steam-geyser, Castra hydrogen-sulfide-vent, Rabbasca harene-vent, Carna vents
AddToTable("Paracelsin", "gas-vents", "fluid", "spaced", 3) --3x3 vents, Pressure Turbine / Pumpjack are 3x3

AddToTable("Pyanodon", "iron-rock", "solid", "spaced", 13)
AddToTable("Pyanodon", "copper-rock", "solid", "spaced", 13)


AddToTable("Pyanodon", "basic-with-fluid", "solid", "spread", 0)
AddToTable("Pyanodon", "ore-nexelit", "solid", "spread", 0)
AddToTable("Pyanodon", "nexelit-rock", "solid", "spaced", 11)
AddToTable("Pyanodon", "titanium-rock", "solid", "spaced", 23)
AddToTable("Pyanodon", "raw-coal", "solid", "spread", 0)
AddToTable("Pyanodon", "coal-rock", "solid", "spaced", 11)
AddToTable("Pyanodon", "ore-tin", "solid", "spread", 0)
AddToTable("Pyanodon", "tin-rock", "solid", "spaced", 13)
AddToTable("Pyanodon", "ore-chromium", "solid", "spread", 0)
AddToTable("Pyanodon", "chromium-rock", "solid", "spaced", 11)
AddToTable("Pyanodon", "ore-aluminium", "solid", "spread", 0) --UK Spelling aluminium
AddToTable("Pyanodon", "aluminium-rock", "solid", "spaced", 19) --UK Spelling aluminium
AddToTable("Pyanodon", "ore-nickel", "solid", "spread", 0)
AddToTable("Pyanodon", "nickel-rock", "solid", "spaced", 13)
AddToTable("Pyanodon", "uranium", "solid", "spread", 0)
AddToTable("Pyanodon", "uranium-rock", "solid", "spaced", 11)

AddToTable("Pyanodon", "borax", "solid", "spread", 0)
AddToTable("Pyanodon", "niobium", "solid", "spread", 0)

AddToTable("Pyanodon", "zinc-rock", "solid", "spaced", 11)
AddToTable("Pyanodon", "salt-rock", "solid", "spaced", 11)
AddToTable("Pyanodon", "lead-rock", "solid", "spaced", 11)

AddToTable("Pyanodon", "quartz-rock", "solid", "spaced", 13)
AddToTable("Pyanodon Petroleum", "sulfur-patch", "solid", "spaced", 7)
AddToTable("Pyanodon Petroleum", "bitumen-seep", "fluid", "spaced", 11)
AddToTable("Pyanodon Petroleum", "oil-sand", "fluid", "spread", 0)
--The three deposits a Bitumen Seep converts into
AddToTable("Pyanodon Petroleum", "oil-derrick", "fluid", "spaced", 5)   --oil-mk01 (5x5) to oil-mk04 (11x11), sized per deposit
AddToTable("Pyanodon Petroleum", "natural-gas", "fluid", "spaced", 7)   --1x1 deposit, Natural Gas Derrick is 7x7
AddToTable("Pyanodon Petroleum", "tar-patch", "fluid", "spaced", 9)     --9x9 deposit, Tar Extractor is 9x9

AddToTable("Pyanodon High Tech", "phosphate", "solid", "spaced", 9)
AddToTable("Pyanodon High Tech", "phosphate-rock-02", "solid", "spaced", 9)
AddToTable("Pyanodon High Tech", "rare-earth", "solid", "spaced", 9)
AddToTable("Pyanodon Alternate Energy", "ree", "solid", "spread", 0)
AddToTable("Pyanodon Alternate Energy", "geothermal-crack", "fluid", "spaced", 11) --Single large deposit (11x11), mined by Geothermal Plant (11x11)
AddToTable("Pyanodon Alternate Energy", "antimonium", "solid", "spread", 0)
AddToTable("Pyanodon Alien Life", "ore-bioreserve", "solid", "spread", 0)

AddToTable("Pyanodon Fusion Energy", "molybdenum", "solid", "spread", 0)
AddToTable("Pyanodon Fusion Energy", "volcanic-pipe", "solid", "spaced", 7)
AddToTable("Pyanodon Fusion Energy", "regolite", "solid", "spaced", 7)

AddToTable("Cursed Filter Mining", "coal", "solid", "spread", 0)
AddToTable("Cursed Filter Mining", "stone", "solid", "spread", 0)
AddToTable("Cursed Filter Mining", "copper-ore", "solid", "spread", 0)
AddToTable("Cursed Filter Mining", "iron-ore", "solid", "spread", 0)
AddToTable("Cursed Filter Mining", "uranium-ore", "solid", "spread", 0)
AddToTable("Cursed Filter Mining", "calcite", "solid", "spread", 0)
AddToTable("Cursed Filter Mining", "tungsten-ore", "solid", "spread", 0)
AddToTable("Cursed Filter Mining", "scrap", "solid", "spread", 0)
AddToTable("Cursed Filter Mining", "crude-oil", "fluid", "spaced", 3)
AddToTable("Cursed Filter Mining", "lithium-brine", "fluid", "spaced", 3)
AddToTable("Cursed Filter Mining", "sulfuric-acid-geyser", "fluid", "spaced", 3)
AddToTable("Cursed Filter Mining", "fluorine-vent", "fluid", "spaced", 3)