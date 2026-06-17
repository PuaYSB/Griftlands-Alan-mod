
AddPlayerCharacter(
    PlayerBackground{
            id = "ALAN",

            player_agent = "PC_ALAN",
            --player_agent_skin = "f5c5bf85-1e7b-4f40-9ab3-5794f4d37f0a",

            name = "Alan",
            title = "The Smuggler",--走私犯
            desc = "After picking up leaks at a gang fight, prepared to become a second-hand fuel dealer.",--在一场群殴现场的捡漏后，准备当个燃料二道贩子
            advancement = DEFAULT_ADVANCEMENT,

            -- vo = "event:/vo/narrator/character/sal",

            -- pre_battle_music = "event:/music/dailyrun_precombat_sal",
            -- deck_music = "event:/music/viewdecks_sal",
            -- boss_music = "event:/music/adaptive_battle_boss",
            -- battle_music = "event:/music/adaptive_battle",
            -- negotiation_music = "event:/music/adaptive_negotiation_barter",

            -- ambush_neutral = "event:/music/stinger/ambush_neutral",
            -- ambush_bad = "event:/music/stinger/ambush_bad",
        }

        :AddAct{
        id = "ALAN_BRAWL",
        name = "Alan's brawl",
        title = "Brawl",
        desc = "Survice an escalating series of jobs as Alan works for a living.",

        act_image = engine.asset.Texture("UI/char_3_brawl.tex"),
        colour_frame = "0x0CD864ff",
        colour_text = "0x9BEFD8ff",
        colour_background = "0xFFDE5Aff",

        world_region = "brawl_region",
        main_quest = "ALAN_BRAWL",
        game_type = GAME_TYPE.BRAWL,

        starting_fn = function( agent, game_state) 
            agent:DeltaMoney( 70 )
        end,
    }
)


-- You can allow this act to be played by other player backgrounds by making a unique clone for that character.
--[[
local act = GetPlayerActData( "SHELS_ADVENTURE" )
GetPlayerBackground( "ROOK" ):AddClonedAct( act, "ROOKS_ADVENTURE" )
--]]

--------------------------------------------------------------------------------

local decks = 
{
    NegotiationDeck("negotiation_basic", "PC_ALAN")
        :AddCards{ 
            PC_ALAN_DISCUSS = 3,
            PC_ALAN_BLUFF = 3,
            PC_ALAN_GUIDANCE = 3,
            PC_ALAN_OBSERVATION_RECORD = 2,
            PC_ALAN_BRAINSTORM = 1,
        },
    
    BattleDeck("battle_basic", "PC_ALAN")
        :AddCards{ 
            PC_ALAN_PUNCH = 3,
            PC_ALAN_THROW_BOTTLE = 2,
            PC_ALAN_READY_FOR_DODGE = 3,
            PC_ALAN_CHEMICAL_RESERVES = 1,
            PC_ALAN_MEDICINE_BAG = 1,
        },
}

for k,v in ipairs(decks) do
    Content.AddDeck(v)
end

