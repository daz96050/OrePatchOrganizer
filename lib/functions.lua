require "lib.resourceData"

Resource_Organizer = {
    Name = "", --[[@as string]]           --In-Game Name
    Count = 0,                            --Amount of resources caught
    CountPerCell = 0, --[[@as integer]]   --Per Cell count
    Surface = "", --[[@as string]]        --Surface collected from
    Category = "", --[[@as string]]       --Resource category
    Name_Localised = "", --[[@as string]] --Localised Name
    Handler = "", --[[@as string]]        --Spread or Spaced
    Grid_Spacing = 0, --[[@as integer]]   --Spacing between special buildings
    LockSurface = true, --[[@as boolean]]
    AllowSolids = true, --[[@as boolean]]
    AllowFluids = true, --[[@as boolean]]
    AllowMixing = true, --[[@as boolean]]
    MachineSize = 0, --[[@as integer]]
    Noise = false, --[[@as boolean]]        --Natural placement (dense center, sparse edges)
    NoiseFalloff = 2, --[[@as integer]]      --How sharply density drops toward the edges
    NoiseWaviness = 0.3, --[[@as number]]    --How irregular the patch outline is
    Debug = false --[[@as boolean]]
}

--Set Resource_Organizer settings, allowing run-time modifications
local function UpdateStoredSettings(event)
    Resource_Organizer.Grid_Spacing = settings.global["resource-patch-organizer-grid-spacing"].value
    Resource_Organizer.LockSurface = settings.global["resource-patch-organizer-lock-surface"].value
    Resource_Organizer.AllowSolids = settings.global["resource-patch-organizer-allow-solids"].value
    Resource_Organizer.AllowFluids = settings.global["resource-patch-organizer-allow-fluids"].value
    Resource_Organizer.AllowMixing = settings.global["resource-patch-organizer-allow-mixing"].value
    Resource_Organizer.Noise = settings.global["resource-patch-organizer-noise"].value
    Resource_Organizer.NoiseFalloff = settings.global["resource-patch-organizer-noise-falloff"].value
    Resource_Organizer.NoiseWaviness = settings.global["resource-patch-organizer-noise-waviness"].value
    Resource_Organizer.Debug = settings.get_player_settings(event.player_index)["resource-patch-organizer-debug"].value
end

--- @param InputString string String To Format To Camel Case
--- @return string OutputString Output of Function
local function ConvertStringToCamelCase(InputString)
    return string.gsub(" " .. InputString, "%W%l", string.upper):sub(2)
end

--- Adjusts a BoundingBox X/Y by fixed values
--- @param area BoundingBox The BoundingBox to modify
--- @param adjustX integer The value to adjust the X Coordinates
--- @param adjustY integer The value to adjust the Y Coordinates
--- @return BoundingBox area
local function AdjustBoundingBox(area, adjustX, adjustY)
    ---@type BoundingBox
    local newArea = {
        left_top = {
            x = area.left_top.x + adjustX,
            y = area.left_top.y + adjustY,
        },
        right_bottom = {
            x = area.right_bottom.x + adjustX,
            y = area.right_bottom.y + adjustY,
        },
    }
    return newArea
end

--- Round a BoundingBox outwards to increments of the snaped value i.e. select 1 tile in Chunk, and snapValue of 64 = 1 chunk selected
--- @param area BoundingBox Area to snap/round
--- @param snapValue integer bounding box divisible number to enforce
--- @param snapToEventArea? boolean True = Snap to the top left of the 'area'; False = Snap to the world grid
--- @return BoundingBox area
local function SnapArea(area, snapValue, snapToEventArea)
    ---@type integer
    local adjustX
    ---@type integer
    local adjustY
    ---@type BoundingBox
    local newArea

    ---@type integer
    local snapLimit = 1000 --Only allow region to be 'snapped' outwards by 1000

    snapValue = math.min(math.max(1, snapValue), snapLimit)

    -- 1. Round the bounding box coords to whole numbers
    newArea = {
        left_top = {
            x = math.floor(area.left_top.x),
            y = math.floor(area.left_top.y),
        },
        right_bottom = {
            x = math.ceil(area.right_bottom.x),
            y = math.ceil(area.right_bottom.y),
        },
    }
    --Get Adjust values
    if snapToEventArea == true then
        adjustX = newArea.left_top.x
        adjustY = newArea.left_top.y
    else
        adjustX = 0
        adjustY = 0
    end

    -- 2. Adjust for snapToEventArea
    -- Adjust by negative
    -- Not needed for 0,0 but included for clarity
    newArea = AdjustBoundingBox(area, -adjustX, -adjustY)

    -- 3. Snap to SnapValue
    newArea = {
        left_top = {
            x = math.floor(area.left_top.x / snapValue) * snapValue,
            y = math.floor(area.left_top.y / snapValue) * snapValue,
        },
        right_bottom = {
            x = math.ceil(area.right_bottom.x / snapValue) * snapValue,
            y = math.ceil(area.right_bottom.y / snapValue) * snapValue,
        },
    }

    -- 4. UnAdjust for snapToEventArea
    -- Adjust by positive
    -- Not needed for 0,0 but included for clarity
    newArea = AdjustBoundingBox(area, adjustX, adjustY)
    -- 5. Return
    return newArea
end

--- Returns a multiple of Height x Width
--- @param area BoundingBox
--- @return integer count
local function CountAreaTiles(area)
    local width = area.right_bottom.x - area.left_top.x
    local height = area.right_bottom.y - area.left_top.y
    return width * height
end

--- Print bounding box to ingame chat
--- @param area BoundingBox
local function PrintArea(area)
    game.print("Left Top X: " .. area.left_top.x)
    game.print("Left Top Y: " .. area.left_top.y)
    game.print("Right Bottom X: " .. area.right_bottom.x)
    game.print("Right Bottom Y: " .. area.right_bottom.y)
end

--- Validate if a BoundingBox is 0
--- @param area BoundingBox
--- @return boolean zeroSize
local function IsZeroSize(area)
    return (area.left_top.x == area.right_bottom.x and area.left_top.y == area.right_bottom.y)
end

--- Format a number into comma separated thousands
--- @param number integer Number to format into a string
--- @return string formatted_number
local function FormatInt(number)
    local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    -- reverse the int-string and append a comma to all blocks of 3 digits
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    -- reverse the int-string back remove an optional comma and put the
    -- optional minus and fractional part back
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

-- Collect Resource
function On_Player_Selected_Area(event)
    --Only handle the ore patch organiser
    if event.item == "ore-patch-organizer" then
        --Update Settings allowing Map/Per-Player modifications
        UpdateStoredSettings(event)

        if Resource_Organizer.Debug then
            game.print({ "", "Debug Information: On_Player_Selected_Area" })
            game.print({ "", "Surface: ", ConvertStringToCamelCase(Resource_Organizer.Surface) })
            game.print({ "", "Name: ", Resource_Organizer.Name })
            game.print({ "", "Count: ", Resource_Organizer.Count })
            game.print({ "", "Grid Spacing: ", Resource_Organizer.Grid_Spacing })
            game.print({ "", "Machine Size: ", Resource_Organizer.MachineSize })
        end

        --Skip 0 size selection
        if IsZeroSize(event.area) then return end

        --Surface Lock
        if Resource_Organizer.LockSurface then
            if event.surface.name ~= Resource_Organizer.Surface and --Different surface from previous collection
                Resource_Organizer.Surface ~= "" then               --Surface hasn't been set, new collection
                game.print({ "", "Invalid Surface. Resources were previously collected from ",
                    ConvertStringToCamelCase(Resource_Organizer.Surface) })
                return
            end
        end

        --Loop all resources in Event
        for _, resource in pairs(event.entities) do

            --Contain validation within Category If/Then/End, to prevent extra checks
            --Category = "" - Do nothing, not valid collection
            --Category != "" - Collect resources/validate
            if Resource_Organizer.Category == "" then
                SetResourceOrganizer(resource)
                if Resource_Organizer.Category ~= "" then
                    Resource_Organizer.Surface = event.surface.name
                end
            end
            -- At this point all validation and variables are set

            -- Resource found must match Name
            if resource.name == Resource_Organizer.Name then

                Resource_Organizer.Count = Resource_Organizer.Count + resource.amount
                resource.destroy()
            end
        end

        if Resource_Organizer.Count ~= 0 then
            --Show the user what we've collected
            game.print({ "", "Total ", Resource_Organizer.Name_Localised, " Captured: ", FormatInt(Resource_Organizer.Count) })
        end

        --TODO: Save Data
    end
end

-- Print Resource
function On_Player_Alt_Selected_Area(event)
    -- Only ore patch organizer
    if event.item == "ore-patch-organizer" then
        --Update Settings allowing Map/Per-Player modifications
        UpdateStoredSettings(event)

        if Resource_Organizer.Debug then
            game.print({ "", "Debug Information: On_Player_Alt_Selected_Area" })
            game.print({ "", "Surface: ", ConvertStringToCamelCase(Resource_Organizer.Surface) })
            game.print({ "", "Name: ", Resource_Organizer.Name })
            game.print({ "", "Count: ", Resource_Organizer.Count })
            game.print({ "", "Grid Spacing: ", Resource_Organizer.Grid_Spacing })
            game.print({ "", "Machine Size: ", Resource_Organizer.MachineSize })
            game.print({ "", "Event X Left_Top: ", event.area.left_top.x })
            game.print({ "", "Event X Right_Bottom: ", event.area.right_bottom.x })
            game.print({ "", "Event Y Left_Top: ", event.area.left_top.y })
            game.print({ "", "Event Y Right_Bottom: ", event.area.right_bottom.y })
        end

        -- No area selected
        if IsZeroSize(event.area) then return end

        -- No resources previously collected
        if Resource_Organizer.Name == "" or Resource_Organizer.count == 0 then return end

        -- Different surface from previous collection
        if Resource_Organizer.LockSurface and event.surface.name ~= Resource_Organizer.Surface then
            game.print({ "", "Invalid Surface. Resources were previously collected from ",
                ConvertStringToCamelCase(Resource_Organizer.Surface) })
            return
        end

        -- Other resources are in the way - Check setting
        if not Resource_Organizer.AllowMixing then
            for _, resource in pairs(event.entities) do
                if resource.type == "resource" then
                    game.print({ "", "Cannot print ", Resource_Organizer.Name_Localised,
                        ". Other Resources are in the way" })
                    return
                end
            end
        end

        --Count valid and invalid tiles in area
        local validCells = 0
        local invalidCells = 0
        for x = event.area.left_top.x, event.area.right_bottom.x do     --iterate x axis
            for y = event.area.left_top.y, event.area.right_bottom.y do --iterate y axis
                if event.surface.can_place_entity { name = Resource_Organizer.Name, position = { x, y } } then
                    validCells = validCells + 1
                else
                    invalidCells = invalidCells + 1
                end
            end
        end

        --There's got to be some cells to print to
        if validCells == 0 then
            game.print({ "", "No valid tiles selected to print ", FormatInt(Resource_Organizer.Count), " ",
                Resource_Organizer.Name_Localised })
            return
        end

        --No area, don't say we're "Printing"
        if Resource_Organizer.Handler == 'spaced' and invalidCells ~= 0 then
            --Spaced Resources must be placed on fully empty ground
            --This is for pure laziness to prevent calculating collisions
            game.print({ "", "Spaced Resources must have fully empty ground. Can't print ", FormatInt(Resource_Organizer
                .Count),
                " ", Resource_Organizer.Name_Localised })
            return
        end

        --If we get here, there are no resources in the area, there is space to print
        --Ensure at leaste 1 ore per tile. Round up to prevent remainder ores
        Resource_Organizer.CountPerCell = math.max(math.ceil(Resource_Organizer.Count / validCells), 1)
        game.print({ "", "Printing ", Resource_Organizer.Name_Localised, ": ", FormatInt(Resource_Organizer.Count) })

        if Resource_Organizer.Handler == 'spread' then
            if Resource_Organizer.Noise then
                --Natural placement: one solid, contiguous blob with an irregular outline,
                --richest in the centre and only slightly lighter toward the edges.

                --Centre and half-extents of the selection (used to build an inscribed ellipse)
                local cx = (event.area.left_top.x + event.area.right_bottom.x) / 2
                local cy = (event.area.left_top.y + event.area.right_bottom.y) / 2
                local halfW = math.max((event.area.right_bottom.x - event.area.left_top.x) / 2, 0.5)
                local halfH = math.max((event.area.right_bottom.y - event.area.left_top.y) / 2, 0.5)
                local falloff = Resource_Organizer.NoiseFalloff

                --Coherent, deterministic boundary noise: the patch edge is warped by a few sine
                --harmonics of the angle rather than a per-tile random roll. That keeps the body
                --a single connected mass (every tile inside the outline is filled - no gaps or
                --corner-only tiles) while giving it an organic, non-circular shape. Phases are
                --seeded from the patch centre so each patch looks different, and it stays
                --multiplayer-deterministic (no RNG).
                local seedA = cx * 0.7 + cy * 1.3
                local seedB = cx * 1.9 - cy * 0.6
                local waviness = Resource_Organizer.NoiseWaviness --How far the outline lumps inward from the ellipse (0 = smooth ellipse)
                --Yield gradient: rim tiles stay only slightly lighter than the centre. 'falloff'
                --scales how much lighter, kept gentle and capped so edges never fade to nothing.
                local edgeLightness = math.min(falloff * 0.1, 0.8)

                --Pass 1: fill every placeable tile inside the irregular outline, weighting ore by distance
                local chosen = {}
                local totalWeight = 0
                for x = event.area.left_top.x, event.area.right_bottom.x do     --Iterate x axis
                    for y = event.area.left_top.y, event.area.right_bottom.y do --iterate y axis
                        --Normalised radial distance: 0 at the centre, 1 on the inscribed ellipse
                        local nx = (x - cx) / halfW
                        local ny = (y - cy) / halfH
                        local r = math.sqrt(nx * nx + ny * ny)
                        --Irregular boundary radius for this direction. Star-convex (a single radius
                        --per angle) guarantees the filled region is one connected body.
                        --Factorio runs Lua 5.2.1 (math.atan2); the 'or' keeps it working on 5.3+ too.
                        ---@diagnostic disable-next-line: deprecated
                        local theta = math.atan2 and math.atan2(ny, nx) or math.atan(ny, nx)
                        local wave = 0.5 * math.sin(3 * theta + seedA)
                            + 0.3 * math.sin(5 * theta + seedB)
                            + 0.2 * math.sin(7 * theta + seedA * 1.7)
                        --Map wave (~[-1,1]) so the outline dips inward: boundary in [1 - waviness, 1]
                        local boundary = 1 - waviness * (0.5 - 0.5 * wave)
                        if r <= boundary and
                            event.surface.can_place_entity { name = Resource_Organizer.Name, position = { x, y } } then
                            --Distance to THIS direction's rim (0 centre .. 1 rim); gentle linear lightening
                            local weight = 1 - edgeLightness * math.min(r / boundary, 1)
                            chosen[#chosen + 1] = { x = x, y = y, weight = weight }
                            totalWeight = totalWeight + weight
                        end
                    end
                end

                --Pass 2: hand out the ore in proportion to each tile's weight, conserving the total exactly
                if #chosen == 0 then
                    --Nothing picked (tiny selection / unlucky rolls) - drop everything on the first placeable tile
                    for x = event.area.left_top.x, event.area.right_bottom.x do
                        for y = event.area.left_top.y, event.area.right_bottom.y do
                            if Resource_Organizer.Count ~= 0 and event.surface.can_place_entity { name = Resource_Organizer.Name, position = { x, y } } then
                                event.surface.create_entity({
                                    name = Resource_Organizer.Name,
                                    position = { x, y },
                                    amount = Resource_Organizer.Count
                                })
                                Resource_Organizer.Count = 0
                            end
                        end
                    end
                else
                    local remainingWeight = totalWeight
                    for i, tile in ipairs(chosen) do
                        if Resource_Organizer.Count <= 0 then break end
                        local amount
                        if i == #chosen then
                            --Last tile absorbs the remainder so no ore is lost to rounding
                            amount = Resource_Organizer.Count
                        else
                            amount = math.floor(Resource_Organizer.Count * tile.weight / remainingWeight + 0.5)
                            amount = math.min(amount, Resource_Organizer.Count)
                        end
                        remainingWeight = remainingWeight - tile.weight
                        if amount > 0 then
                            event.surface.create_entity({
                                name = Resource_Organizer.Name,
                                position = { tile.x, tile.y },
                                amount = amount
                            })
                            Resource_Organizer.Count = Resource_Organizer.Count - amount
                        end
                    end
                end
            else
                --Print solids in a clean square
                for x = event.area.left_top.x, event.area.right_bottom.x do     --Iterate x axis
                    for y = event.area.left_top.y, event.area.right_bottom.y do --iterate y axis
                        -- Check resources to print, and not colliding
                        if Resource_Organizer.Count ~= 0 and event.surface.can_place_entity { name = Resource_Organizer.Name, position = { x, y } } then
                            --Print resource
                            event.surface.create_entity({
                                name = Resource_Organizer.Name,
                                position = { x, y },
                                amount = math.min(Resource_Organizer.Count, Resource_Organizer.CountPerCell)
                            })
                            --Remove printed resource from our total count
                            Resource_Organizer.Count = Resource_Organizer.Count -
                                math.min(Resource_Organizer.Count, Resource_Organizer.CountPerCell)
                        end
                    end
                end
            end
            --Reset Mining Drills to detect any new ores pasted
            for _, e in pairs(event.surface.find_entities_filtered { area = event.area, type = "mining-drill" }) do
                e.update_connections()
            end

        elseif Resource_Organizer.Handler == 'spaced' then
            --Print fluids in an even grid
            local tileGrid = 0 --[[@as integer]]
            local machineSize = Resource_Organizer.MachineSize
            tileGrid = Resource_Organizer.Grid_Spacing + machineSize

            --TODO: Possibly upgrade to allow snapping to fixed grid sizes (Chunk/half chunk etc)
            local newArea = SnapArea(event.area, 1)
            --math.ceil to 'include' the bottom right tile in the selection, otherwise math.floor excludes it requiring the player to select beyond the area

            --100 tiles with tileGrid of 6 (3 for Pumpjack, 3 for Spacing) = 16.66, Rounded down to 16
            --i.e. 100x100 = 16x16 grid of fluid placement options = 96x96 used space
            local totalX = math.floor((event.area.right_bottom.x - event.area.left_top.x + machineSize) / tileGrid)
            local totalY = math.floor((event.area.right_bottom.y - event.area.left_top.y + machineSize) / tileGrid)

            if Resource_Organizer.Debug then
                game.print({ "", "Total X: ", totalX })
                game.print({ "", "Total Y: ", totalY })
            end
            if totalX <= 0 or totalY <= 0 then
                --Area too small - Print Single instance
                event.surface.create_entity({
                    name = Resource_Organizer.Name,
                    amount = Resource_Organizer.Count,
                    position = { event.area.left_top.x, event.area.left_top.y }
                })
            else
                Resource_Organizer.CountPerCell = math.max(math.ceil(Resource_Organizer.Count / (totalX * totalY)), 1)

                --Iterate via int Variables instead of direct Event X/Y because of rounding and causing an extra instance placing
                --Iterate x axis
                for x = 0, (totalX - 1) do
                    --Iterate y axis
                    for y = 0, (totalY - 1) do
                        --Print Fluids
                        if Resource_Organizer.Debug then
                            game.print({ "", "X: ", event.area.left_top.x + (x * tileGrid) + math.ceil(machineSize / 2) })
                            game.print({ "", "Y: ", event.area.left_top.y + (y * tileGrid) + math.ceil(machineSize / 2) })
                        end
                        event.surface.create_entity({
                            name = Resource_Organizer.Name,
                            amount = math.min(Resource_Organizer.Count, Resource_Organizer.CountPerCell),
                            position = { 
                                event.area.left_top.x + (x * tileGrid) + math.ceil(machineSize / 2),
                                event.area.left_top.y + (y * tileGrid) + math.ceil(machineSize / 2)
                            }
                        })
                        Resource_Organizer.Count = Resource_Organizer.Count -
                            math.min(Resource_Organizer.Count, Resource_Organizer.CountPerCell)
                    end
                end
            end
        end

        --Finish by removing the existing details
        ResetResourceOrganizer()
    end
end
