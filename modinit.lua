local filepath = require "util/filepath"

-- OnNewGame is called whenever a new game is started.
local function OnNewGame( mod, game_state )
    -- Require this Mod to be installed to launch this save game.
    if game_state:GetCurrentActID() == "ALAN_BRAWL" then
        game_state:RequireMod( mod )
    end
end

local function OnPreLoad()
    for k, filepath in ipairs( filepath.list_files( "ALANMOD:loc", "*.po", true )) do
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

    
    ------------------------------------------------------------------------------------------
    -- Aspects


    ------------------------------------------------------------------------------------------
    -- Player backgrounds

    require "ALANMOD:alan_background"
    
    ------------------------------------------------------------------------------------------
    -- Factions

    ------------------------------------------------------------------------------------------
    -- Codex

    ------------------------------------------------------------------------------------------
    -- Cards / Grafts

    require "ALANMOD:negotiation_cards"
    require "ALANMOD:negotiation_grafts"
    require "ALANMOD:battle_cards"
    require "ALANMOD:battle_grafts"
    require "ALANMOD:Flourishes"

    ------------------------------------------------------------------------------------------
    -- Characters

    require "ALANMOD:characters/alan"
    require "ALANMOD:characters/for_test"

    ------------------------------------------------------------------------------------------
    -- Convos / Quests

    require "ALANMOD:alan_brawl"
    require "ALANMOD:alan_single_target_alpha"
    require "ALANMOD:alan_negotiation_test"

    if not TheGame:GetGameProfile().values["unlocked_flourishes"]["PC_ALAN"] then
        TheGame:GetGameProfile().values["unlocked_flourishes"]["PC_ALAN"] = {BATTLE = {},NEGOTIATION = {},}
    end
    
    if not TheGame:GetGameProfile():HasMettleUnlocked("PC_ALAN") then
        TheGame:GetGameProfile():UnlockMettle("PC_ALAN")
    end

    ------------------------------------------------------------------------------------------
    -- Locations

    return PostLoad
end

--[[local MOD_OPTIONS =
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
}]]--

return
{
    -- [optional] version is a string specifying the major, minor, and patch version of this mod.
    version = "1.1.0",

    -- Pathnames to files within this mod can be resolved using this alias.
    alias = "ALANMOD",
    
    -- Mod API hooks.
    OnPreLoad = OnPreLoad,
    OnLoad = OnLoad,
    OnNewGame = OnNewGame,
    OnGameStart = OnGameStart,

    --load_after = { "HAVARIAN" },  Ensure this mod comes after the Havarian mod in the sort order.
    --load_before = { "SOME_OTHER_MOD" },  Ensure this mod comes before SOME_OTHER_MOD in the sort order.
    
    --mod_options = MOD_OPTIONS,

    -- UI information about this mod.
    title = "New Character Alan",

    -- You can embed this mod's descriptive text directly...
    -- description = "Play as Shel and guide her to riches and discover the mysterious Lost Passage!",

    -- or look it up in an external file.
    description_file = "ALANMOD:about.txt",

    -- This preview image is uploaded if this mod is integrated with Steam Workshop.
    previewImagePath = "preview.png",
}
