local filepath = require "util/filepath"

-- OnNewGame is called whenever a new game is started.
local function OnNewGame( mod, game_state )
    -- Require this Mod to be installed to launch this save game.
    if game_state:GetCurrentActID() == "SHELS_ADVENTURE" then
        game_state:RequireMod( mod )
    end
end

local function OnPreLoad()
    for k, filepath in ipairs( filepath.list_files( "LOSTPASSAGE:loc", "*.po", true )) do
        if filepath:match( "(.+)[.]po$" ) then
            Content.AddPOFileToLocalization( filepath:match("([^/]+)[.]po$"), filepath )
        end
    end
end


local function PostLoad( mod )
    print( "PostLoad", mod.id )
end


-- OnLoad is called on startup after all core game content is loaded.
local function OnLoad( mod )

    ------------------------------------------------------------------------------------------
    -- These additional names are available for randomly generated characters across all campaigns.

    Content.ExtendNamePool( "NAMES", "LOSTPASSAGE:custom_names.txt" )

    Content.AddStringTable( mod.id, { LOST_PASSAGE = "Lost Passage" } )
    Content.AddStringTable( "COMMON", { CONVO_COMMON = { OPT_FOOBAR = "Foobar" }})

    Content.AddPlaxData( "INT_ShelsEstate", "LOSTPASSAGE:plax/INT_ShelsEstate" )

    local codex = Codex()
    codex:AddFilename( "LOSTPASSAGE:shel_codex.yaml" )
    Content.AddCodex( codex )

    local quips = QuipDatabase()
    quips:AddFilename( "LOSTPASSAGE:shel_quips.yaml" )
    Content.AddQuips( quips )

    Content.AddSlideShow( "shel_slideshow", require "LOSTPASSAGE:slides/shel_slideshow" )
    
    ------------------------------------------------------------------------------------------
    -- Aspects

    require "LOSTPASSAGE:bounty_target"
    require "LOSTPASSAGE:trader"

    ------------------------------------------------------------------------------------------
    -- Player backgrounds

    require "LOSTPASSAGE:shels_adventure"
    
    ------------------------------------------------------------------------------------------
    -- Factions

    ------------------------------------------------------------------------------------------
    -- Codex

    ------------------------------------------------------------------------------------------
    -- Cards / Grafts

    require "LOSTPASSAGE:negotiation_cards"
    require "LOSTPASSAGE:negotiation_grafts"
    require "LOSTPASSAGE:battle_cards"
    require "LOSTPASSAGE:battle_grafts"
    require "LOSTPASSAGE:Flourishes"
    require "LOSTPASSAGE:shel_shops"

    ------------------------------------------------------------------------------------------
    -- Characters

    require "LOSTPASSAGE:shel"

    ------------------------------------------------------------------------------------------
    -- Convos / Quests

    require "LOSTPASSAGE:shel_story"

    for k, filepath in ipairs( filepath.list_files( "LOSTPASSAGE:conversations", "*.lua", true )) do
        filepath = filepath:match( "^(.+)[.]lua$")
        require( filepath )
    end

    for k, filepath in ipairs( filepath.list_files( "LOSTPASSAGE:events", "*.lua", true )) do
        filepath = filepath:match( "^(.+)[.]lua$")
        require( filepath )
    end

    ------------------------------------------------------------------------------------------
    -- Locations

    require "LOSTPASSAGE:shel_locations"

    return PostLoad
end

local MOD_OPTIONS =
{
    -- Access this value from the user's settings by calling:
    -- Content.GetModSetting( <mod_id>, "resolve_per_day" )
    {
        title = "Resolve Per Day",
        slider = true,
        key = "resolve_per_day",
        default_value = 10,
        values = {
            range_min = 1,
            range_max = 20,
            step_size = 1,
            desc = "This is the amount of resolve Shel loses after sleeping.",
        },
    },
    -- Access this value from the user's settings by calling:
    -- Content.GetModSetting( <mod_id>, "min_stash_value" )
    {
        title = "Stash amount",
        spinner = true,
        key = "min_stash_value",
        default_value = 500,
        values =
        {
            { name="500", desc="Shel must stash at least 500 shills each time.", data = 500 },
            { name="1000", desc="Shel must stash at least 1000 shills each time.", data = 1000 },
            { name="5000", desc="Shel must stash at least 5000 shills each time.", data = 5000 },
        }
    },
    -- A 'button' option.  What it does is up to you.
    {
        title = "Button",
        desc = "This button click is just an example.",
        button = true,
        key = "button",
        on_click = function() print( "CLICK" ) end,
    }
}

return
{
    -- [optional] version is a string specifying the major, minor, and patch version of this mod.
    version = "0.1.1",

    -- Pathnames to files within this mod can be resolved using this alias.
    alias = "LOSTPASSAGE",
    
    -- Mod API hooks.
    OnPreLoad = OnPreLoad,
    OnLoad = OnLoad,
    OnNewGame = OnNewGame,
    OnGameStart = OnGameStart,

    load_after = { "HAVARIAN" }, -- Ensure this mod comes after the Havarian mod in the sort order.
    load_before = { "SOME_OTHER_MOD" }, -- Ensure this mod comes before SOME_OTHER_MOD in the sort order.
    
    mod_options = MOD_OPTIONS,

    -- UI information about this mod.
    title = "Shel's Adventure",

    -- You can embed this mod's descriptive text directly...
    -- description = "Play as Shel and guide her to riches and discover the mysterious Lost Passage!",

    -- or look it up in an external file.
    description_file = "LOSTPASSAGE:about.txt",

    -- This preview image is uploaded if this mod is integrated with Steam Workshop.
    previewImagePath = "preview.png",
}
