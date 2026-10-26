--Graphics paths are resolved by mod name, so this must match "name" in info.json.
--Kept in one place because this fork is named differently to upstream OrePatchOrganizer.
local modPath = "__OrePatchOrganizer-forked__"

---@diagnostic disable-next-line: undefined-global
data:extend({
    {
        type = "selection-tool",
        name = "ore-patch-organizer",
        icon = modPath .. "/organizer.png",
        icon_size = 64,
        icon_mipmaps = 6,
        flags = {
            "only-in-cursor",
            "spawnable",
            "not-stackable"
        },
        subgroup = "tool",
        order = "c[automated-construction]-a[oreorganizer]",
        stack_size = 1,
        stackable = false,
        --skip_fog_of_war = true,
        select = {
            mode = "any-entity",
            border_color = { r = 1, g = 0, b = 0 },
            cursor_box_type = "copy",
            entity_type_filters = { "resource" }
        },
        alt_select = {
            mode = "any-entity",
            border_color = { r = 0, g = 1, b = 0 },
            cursor_box_type = "blueprint-snap-rectangle"
        }
    },
    {
        type = "shortcut",
        name = "ore-patch-organizer",
        icon = modPath .. "/organizer.png",
        icon_size = 64,
        small_icon = modPath .. "/organizer.png",
        small_icon_size = 64,
        order = "o[ore-organizer]",
        action = "spawn-item",
        localised_name = { "item-name.ore-patch-organizer" },
        -- technology_to_unlock = "oil-processing",
        item_to_spawn = "ore-patch-organizer",
        style = "blue",
    }
})
