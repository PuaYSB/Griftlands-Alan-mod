local battle_defs = require "battle/battle_defs"
local BATTLE_EVENT = battle_defs.BATTLE_EVENT
local CARD_FLAGS = battle_defs.CARD_FLAGS

local negotiation_defs = require "negotiation/negotiation_defs"
local EVENT = negotiation_defs.EVENT

local SOCIAL_GRAFTS =
{

}
for id, graft in pairs( SOCIAL_GRAFTS ) do
    Content.AddSocialGraft( id, graft )
end

Content.AddCharacterDef
(
    CharacterDef("NPC_PA_FAKE_SMITH",
    {
        unique = true,
        base_def = "NPC_BASE",
        alias = "NPC_PA_FAKE_SMITH",
        title = "Thug",
        species = SPECIES.KRADESHI,
        gender = GENDER.MALE,
        skin_colour = 0x7B8C5BFF,
        renown = 3,
        combat_strength = 2,
        boss = true,
        name = "Smyth",
        faction_id = "FEUD_CITIZEN",
        bio = "He plainly underestimated how unforgettable that Kradeshi is to every soul in Pearl-on-Foam.",

        loved_graft = "authority",
        hated_graft = "blacklisted",
        death_item = "adrenaline_shot",

        voice_actor = "sparkbaronHighClassMale01",
        can_talk = true,

        --anims = ,
        combat_anims = {"anim/med_combat_smith.zip"},
        build = "smith_outfit_02_build",
        head = "head_male_generic_kradeshi_01",

        fight_data = 
        {
            MAX_MORALE = MAX_MORALE_LOOKUP.HIGH,
            MAX_HEALTH = 95,
            battle_scale = 1.12,

            attacks = 
            {
                NPC_PA_SWIG_DRINK_1 = table.extend(NPC_BUFF)
                {
                    name = "Rust Bucket",
                    anim = "drink",
                    flags = CARD_FLAGS.SKILL | CARD_FLAGS.BUFF,
                    target_type = TARGET_TYPE.SELF,

                    defend_amt = {6, 8, 10, 12},

                    OnPostResolve = function( self, battle, attack )
                        self.owner:AddCondition("DEFEND", self.defend_amt[GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1], self)
                    end
                },

                NPC_PA_SWIG_DRINK_2 = table.extend(NPC_BUFF)
                {
                    name = "Pinto Pour",
                    anim = "drink_fancy",
                    flags = CARD_FLAGS.SKILL | CARD_FLAGS.BUFF,
                    target_type = TARGET_TYPE.SELF,

                    pwr_amt = {2, 2, 3, 3},

                    OnPostResolve = function( self, battle, attack )
                        self.owner:AddCondition("POWER", self.pwr_amt[GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1], self)
                    end
                },

                NPC_PA_SMYTH_ATTACK_1 = table.extend(NPC_ATTACK)
                {
                    name = "Bonkers",
                    anim = "cheers_smash",
                    flags = CARD_FLAGS.MELEE,

                    target_count = 2,

                    OnPostResolve = function( self, battle, attack )
                        
                    end
                },

                NPC_PA_SMYTH_ATTACK_2 = table.extend(NPC_ATTACK)
                {
                    name = "Shatter",
                    anim = "bottle_stab",
                    flags = CARD_FLAGS.MELEE | CARD_FLAGS.DEBUFF,

                    wound_amt = {3, 3, 4, 4},

                    OnPostResolve = function( self, battle, attack )
                        if not attack:CheckHitResult( attack.target, "evaded" ) and not attack:CheckHitResult( attack.target, "defended" ) then
                            attack:AddCondition("WOUND", self.wound_amt[math.min(GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1, #self.wound_amt)], self)
                        end
                    end
                },
            },

            behaviour =
            {
                OnActivate = function( self )
                    self.drink = self:MakePicker()
                        :AddID( "NPC_PA_SWIG_DRINK_1", 1)
                        :AddID( "NPC_PA_SWIG_DRINK_2", 1)
                    self.attack = self:MakePicker()
                        :AddID( "NPC_PA_SMYTH_ATTACK_1", 1)
                        :AddID( "NPC_PA_SMYTH_ATTACK_2", 1)

                    self:SetPattern( self.Cycle )
                end,

                Cycle = function( self, turns )
                    if turns % 2 == 0 then
                        self.attack:ChooseCard()
                    else
                        self.drink:ChooseCard()
                    end
                end
            }
        }
    })
)

Content.GetCharacterDef("NPC_PA_FAKE_SMITH"):InheritBaseDef()
