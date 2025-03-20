
AddPlayerCharacter(
    PlayerBackground{
            id = "SHEL",

            player_agent = "PC_SHEL",
            player_agent_skin = "f5c5bf85-1e7b-4f40-9ab3-5794f4d37f0a",

            name = "Shel Ushari",
            title = "The Downtrodden Merchant",
            desc = "An aspiring merchant with a brave heart and large ambitions.",
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
            id = "SHELS_ADVENTURE",
            
            name = "Fortune's Horizon",
            title = "Shel In Murder Bay",
            desc = "Shel works towards becoming a wealthy merchant.",
            
            act_image = engine.asset.Texture("UI/char_1_campaign.tex"),
            colour_frame = "0xFFDE5Aff",
            colour_text = "0xFFFF94ff",
            colour_background = "0xFFA32Aff",

            world_region = "murder_bay",

            max_resolve = 45,

            main_quest = "SHEL_STORY",
            game_type = GAME_TYPE.CAMPAIGN,

            slides = {
                "shel_slideshow",
            },
            
            convo_filter_fn = function( convo_def, game_state )
                if convo_def.id == "REST_AND_RELAXATION" then
                    return false
                end

                return true
            end,

            starting_fn = function( agent, game_state) 
                agent:DeltaMoney( 40 )
            end,
        })


-- You can allow this act to be played by other player backgrounds by making a unique clone for that character.
--[[
local act = GetPlayerActData( "SHELS_ADVENTURE" )
GetPlayerBackground( "ROOK" ):AddClonedAct( act, "ROOKS_ADVENTURE" )
--]]

--------------------------------------------------------------------------------

local decks = 
{
    NegotiationDeck("negotiation_basic", "PC_SHEL")
        :AddCards{ 
            fast_talk = 3,
            threaten = 3,
            deflection = 3,
            bravery = 1,
        },
    
    BattleDeck("battle_basic", "PC_SHEL")
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

