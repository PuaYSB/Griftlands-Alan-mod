local new_builds = {
    alan_body = CreatePersonBuild{
        gender = GENDER.MALE,
        file = "anim/med_male_jake_smuggler_build.zip",
        gloves = GLOVES.ARMOURED, 
        colours = {base_glove = 0x1E1E1Eff,accent = 0x91A0A5ff},
    },
}
Content.AddCharacterBuilds(new_builds)

local def = CharacterDef("PC_ALAN",
{
    base_def = "PLAYER_BASE",
    name = "Alan",
    voice_actor = "sparkbaronHighClassMale01",
    build = "alan_body",
    head = "head_male_bogger",
    player_quip_tag = "player_alan",
    --battle_tutorial = "arint_battle_tutorial",
    --negotiation_tutorial = "arint_negotiation_tutorial",
    title_screen_plax = "title_screen",
    --default_skin = "f5c5bf85-1e7b-4f40-9ab3-5794f4d37f0a",

    anims = {"anim/med_dial_sal.zip"},
    combat_anims = { "anim/med_combat_unarmed_rise_pamphleteer.zip", "anim/med_combat_sal.zip", "anim/med_combat_smith.zip" },

    gender = GENDER.MALE,
    species = SPECIES.HUMAN,

    max_grafts = {
        [GRAFT_TYPE.COMBAT] = 3,
        [GRAFT_TYPE.NEGOTIATION] = 3,
        [GRAFT_TYPE.COIN] = 0,
    },


    starting_grafts = {"flourish_tracker"},
    required_grafts = {"flourish_tracker"},
    max_resolve = 35,
    basic_flourishes =
        {
            BATTLE = "PC_ALAN_FOCUSED_FIRE",
            NEGOTIATION = "PC_ALAN_COMPOSURE",
        },

    fight_data = 
    {
        MAX_HEALTH = 65,
        ranged_riposte = false,
        actions = 3,
        formation = FIGHTER_FORMATION.FRONT_X,

        anim_mapping =
            {
                riposte = "knee",
                execute = "stun",
            },
    },

    negotiation_data =
    {
        behaviour =
        {
            OnInit = function( self, difficulty )
                self.negotiator:AddModifier( "PC_ALAN_CORE" )
            end,
        }
    },

    card_series = { "GENERAL", "ALAN" },
    graft_series = { "GENERAL", "ALAN" },

    hair_colour = 0xCB5D3Cff,
    skin_colour = 0xd2a18cff,
    text_colour = 0xd16160FF,
        
    faction_id = PLAYER_FACTION,
})
def:InheritBaseDef()

Content.AddCharacterDef( def )
