local battle_defs = require "battle/battle_defs"
local BATTLE_EVENT = battle_defs.BATTLE_EVENT
local CARD_FLAGS = battle_defs.CARD_FLAGS

local negotiation_defs = require "negotiation/negotiation_defs"
local EVENT = negotiation_defs.EVENT

local SOCIAL_GRAFTS =
{
    PA_GIFT_PRESTIGE =
    {
        name = "Prestige",
        desc = "All enemies start battle with additional {SURRENDER}.",
        img = engine.asset.Texture( "icons/items/graft_terrorized.tex", true),
        
        battle_condition =
        {
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.ACTIVATED_FIGHTER ] = function( self, fighter )
                    if fighter ~= self.owner and fighter:GetTeam() ~= self.owner:GetTeam() then
                        fighter:DeltaMorale(.15)
                    end
                end,
            },
        },
    },

    PA_GIFT_WIMPY =
    {
        name = "Wimpy",
        desc = "Hostility cards deal 1 less damage.",
        img = engine.asset.Texture( "icons/items/graft_crisis.tex", true),
        
        battle_condition =
        {
            hidden = true,
            event_priorities =
            {
                [ EVENT.CALC_PERSUASION ] = EVENT_PRIORITY_MULTIPLIER,
            },

            event_handlers =
            {
                [ EVENT.CALC_PERSUASION ] = function ( self, source, persuasion, minigame )
                    if source.owner == self.owner then
                        if is_instance( source, Negotiation.Card ) and CheckBits( source.flags, CARD_FLAGS.HOSTILE ) then
                            persuasion:AddPersuasion( -1, -1, self )
                        end
                    end
                end,
            },
        },
    }
}
for id, graft in pairs( SOCIAL_GRAFTS ) do
    Content.AddSocialGraft( id, graft )
end

Content.AddCharacterDef
(
    CharacterDef("NPC_PA_TRIO_BOSS_1",
    {
        unique = true,
        base_def = "NPC_BASE",
        alias = "NPC_PA_TRIO_BOSS_1",
        title = "Trio",
        species = SPECIES.SHROKE,
        gender = GENDER.MALE,
        skin_colour = 0x5B706BFF,
        renown = 2,
        combat_strength = 2,
        boss = true,
        name = "Juan",
        faction_id = "BANDITS",
        bio = "Actually, his name was Alger, but he changed it to stay hidden from his enemies.",

        loved_graft = "PA_GIFT_PRESTIGE",
        hated_graft = "PA_GIFT_WIMPY",
        death_item = "PC_ALAN_BLOOD_PACT_CLAW",

        voice_actor = "spreeLowClassMale01",
        can_talk = true,

        anims = {"anim/weapon_sickle_bandit.zip"},
        combat_anims = {"anim/med_combat_sickle_bandit_raider.zip"},
        build = "male_bandit_promoted_build",
        head = "head_male_shroke_merchant",

        negotiation_data =
        {
            behaviour =
            {
                KINGPIN = 0,

                OnInit = function( self )
                    self.escalation = self:AddArgument( "ESCALATION" )
                    self.kingpin = self:AddArgument( "KINGPIN" )
                    self.greedy = self:AddArgument( "GREEDY" )

                    if self.difficulty <= 2 then
                        self:SetPattern( self.BasicCycle )
                    else
                        self:SetPattern( self.Cycle )
                    end

                    self.negotiator:AddModifier("SHORT_FUSE")
                end,

                BasicCycle = function( self, turns )
                    if turns == 2 then
                        self:ChooseCard( self.escalation )
                        self:ChooseGrowingNumbers( 1, 1 )

                    elseif (turns-1) % 3 == 0 then
                        self:ChooseGrowingNumbers( 2, 1 )
                    else
                        self:ChooseGrowingNumbers( 1, 1 )
                    end
                end,

                Cycle = function( self, turns )
                    if turns % 3 == 0 then
                        self:ChooseCard( self.greedy )
                    end

                    if self.difficulty >= 4 and turns % 2 == 0 then
                        self:ChooseGrowingNumbers( 3, -1 )
                    elseif turns % 2 == 0 then
                        self:ChooseGrowingNumbers( 2, 1 )
                    else
                        self:ChooseGrowingNumbers( 1, 3 )
                    end

                    if (turns - 1) % 5 == 0 and not self.negotiator:FindModifier( "ESCALATION" ) then
                        self:ChooseCard( self.escalation )
                    end

                    if self.KINGPIN > 0 then
                        if (turns + 3) % 5 == 0 and not self.negotiator:FindModifier( "KINGPIN" ) then
                            self:ChooseCard( self.kingpin )
                        end
                    end
                end,
            }
        },

        fight_data = 
        {
            MAX_MORALE = MAX_MORALE_LOOKUP.VERY_LOW,
            MAX_HEALTH = 50,

            conditions = 
            { 
                NPC_PA_BACK_DOWN = 
                {
                    name = "Back down",
                    desc = "If {1}'s brothers is killed or panics, Increases the {1}'s {SURRENDER} meter by {2}.",
                    icon = "battle/conditions/surrender.tex",
                    desc_fn = function( self, fmt_str )
                        return loc.format(fmt_str, self:GetOwnerName(), self.sur_amt)
                    end,

                    ctype = CTYPE.DEBUFF,

                    sur_amt = 10,

                    event_handlers = 
                    {
                        [ BATTLE_EVENT.STATUS_CHANGED ] = function( self, fighter, status )
                            if not self.used and fighter ~= self.owner and (status == FIGHT_STATUS.DEAD or status == FIGHT_STATUS.SURRENDER ) and self.owner:IsActive() then
                                local health = self.owner:GetMaxHealth()
                                self.owner:DeltaMorale( self.sur_amt/health )
                            end
                        end,
                    },
                },
            },

            attacks = 
            {
                NPC_PA_special_move_one = table.extend(NPC_ATTACK)
                {
                    name = "Chop",
                    anim = "crush",

                    flags = CARD_FLAGS.MELEE | CARD_FLAGS.DEBUFF,

                    damage_mult = 0.7,

                    wound_amt = {2, 2, 3, 3},

                    OnPostResolve = function( self, battle, attack)
                        if not attack:CheckHitResult( attack.target, "evaded" ) and not attack:CheckHitResult( attack.target, "defended" ) then
                            attack:AddCondition("WOUND", self.wound_amt[math.min(GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1, #self.wound_amt)], self)
                        end
                    end,
                },

                NPC_PA_attack_one = table.extend(NPC_ATTACK)
                {
                    name = "Crush",
                    anim = "crush",

                    flags = CARD_FLAGS.MELEE,

                    OnPostResolve = function( self, battle, attack )
                    
                    end,
                },


                NPC_PA_defend_trio = table.extend(NPC_BUFF)
                {
                    name = "Taunt",
                    anim = "taunt",

                    flags = CARD_FLAGS.SKILL | CARD_FLAGS.BUFF,
                    target_type = TARGET_TYPE.SELF,

                    defend_amt = { 3, 5, 6, 8},

                    OnPostResolve = function( self, battle, attack )
                        attack:AddCondition("DEFEND", self.defend_amt[math.min(GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1, #self.defend_amt)], self)
                    end,
                },
            },

            behaviour =
            {
                OnActivate = function( self )
                    self.attack = self:AddCard("NPC_PA_attack_one")
                    self.defend = self:AddCard("NPC_PA_defend_trio")
                    self.special_move = self:AddCard("NPC_PA_special_move_one")

                    self:SetPattern( self.Cycle )
                    self.fighter:AddCondition("NPC_PA_BACK_DOWN")

                local agent = Agent("NPC_PA_TRIO_BOSS_2")
                agent:GetSocialConnections():SetRelationship( RELATIONSHIP.LOVED, self.fighter:GetAgent() )

                local new_fighter = Fighter.CreateFromAgent( agent, self.fighter:GetScale() )
                self.fighter:GetTeam():AddFighter( new_fighter )
                self.fighter:GetTeam():ActivateNewFighters( self.fighter.battle )
                self.fighter.battle:BroadcastEvent( BATTLE_EVENT.UPDATE_HOME_POSITIONS, self.fighter:GetTeam())

                local agent_2 = Agent("NPC_PA_TRIO_BOSS_3")
                agent_2:GetSocialConnections():SetRelationship( RELATIONSHIP.LOVED, self.fighter:GetAgent() )

                local new_fighter = Fighter.CreateFromAgent( agent_2, self.fighter:GetScale() )
                self.fighter:GetTeam():AddFighter( new_fighter )
                self.fighter:GetTeam():ActivateNewFighters( self.fighter.battle )
                self.fighter.battle:BroadcastEvent( BATTLE_EVENT.UPDATE_HOME_POSITIONS, self.fighter:GetTeam())

                end,

                Cycle = function( self, turns )
                    if turns % 3 == 0 then
                        self:ChooseCard(self.attack)
                    elseif (turns + 1) % 3 == 0 then
                        self:ChooseCard(self.defend)
                    else
                        self:ChooseCard(self.special_move)
                    end
                end,
            },
        },
    })
)

Content.GetCharacterDef("NPC_PA_TRIO_BOSS_1"):InheritBaseDef()

Content.AddCharacterDef
(
    CharacterDef("NPC_PA_TRIO_BOSS_2",
    {
        unique = true,
        base_def = "NPC_BASE",
        alias = "NPC_PA_TRIO_BOSS_2",
        title = "Trio",
        species = SPECIES.SHROKE,
        gender = GENDER.MALE,
        skin_colour = 0x5B706BFF,
        renown = 2,
        combat_strength = 2,
        boss = true,
        name = "Stu",
        faction_id = "BANDITS",
        bio = "Actually, his name is Nathan, but after joining Spree, he took on a new identity.",

        loved_graft = "PA_GIFT_PRESTIGE",
        hated_graft = "PA_GIFT_WIMPY",
        death_item = "PC_ALAN_BLOOD_PACT_CLAW",

        voice_actor = "spreeLowClassMale01",
        can_talk = true,

        anims = {"anim/weapon_knuckles_promoted_bandit.zip"},
        combat_anims = {"anim/med_combat_knuckles_promoted_bandit.zip"},
        build = "male_bandit_promoted_build",
        head = "head_male_shroke_merc",

        negotiation_data =
        {
            behaviour =
            {
                KINGPIN = 0,

                OnInit = function( self )
                    self.escalation = self:AddArgument( "ESCALATION" )
                    self.kingpin = self:AddArgument( "KINGPIN" )
                    self.greedy = self:AddArgument( "GREEDY" )

                    if self.difficulty <= 2 then
                        self:SetPattern( self.BasicCycle )
                    else
                        self:SetPattern( self.Cycle )
                    end

                    self.negotiator:AddModifier("SHORT_FUSE")
                end,

                BasicCycle = function( self, turns )
                    if turns == 2 then
                        self:ChooseCard( self.escalation )
                        self:ChooseGrowingNumbers( 1, 1 )

                    elseif (turns-1) % 3 == 0 then
                        self:ChooseGrowingNumbers( 2, 1 )
                    else
                        self:ChooseGrowingNumbers( 1, 1 )
                    end
                end,

                Cycle = function( self, turns )
                    if turns % 3 == 0 then
                        self:ChooseCard( self.greedy )
                    end

                    if self.difficulty >= 4 and turns % 2 == 0 then
                        self:ChooseGrowingNumbers( 3, -1 )
                    elseif turns % 2 == 0 then
                        self:ChooseGrowingNumbers( 2, 1 )
                    else
                        self:ChooseGrowingNumbers( 1, 3 )
                    end

                    if (turns - 1) % 5 == 0 and not self.negotiator:FindModifier( "ESCALATION" ) then
                        self:ChooseCard( self.escalation )
                    end

                    if self.KINGPIN > 0 then
                        if (turns + 3) % 5 == 0 and not self.negotiator:FindModifier( "KINGPIN" ) then
                            self:ChooseCard( self.kingpin )
                        end
                    end
                end,
            }
        },

        fight_data = 
        {
            MAX_MORALE = MAX_MORALE_LOOKUP.VERY_LOW,
            MAX_HEALTH = 50,


            attacks = 
            {
                NPC_PA_special_move_two = table.extend(NPC_BUFF)
                {
                    name = "Formation",
                    anim = "taunt",

                    flags = CARD_FLAGS.SKILL | CARD_FLAGS.BUFF,
                    target_type = TARGET_TYPE.SELF,
                    target_mod = TARGET_MOD.TEAM,

                    defend_amt = { 3, 4, 5, 6},

                    OnPostResolve = function( self, battle, attack )
                        attack:AddCondition("DEFEND", self.defend_amt[math.min(GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1, #self.defend_amt)], self)
                    end,
                },

                NPC_PA_attack_two = table.extend(NPC_ATTACK)
                {
                    name = "Wave",
                    anim = "promoted_attack",

                    flags = CARD_FLAGS.MELEE,

                    OnPostResolve = function( self, battle, attack )
                    
                    end,

                    target_count = 2,
                    damage_mult = 0.5,
                },
            },

            behaviour =
            {
                OnActivate = function( self )
                    self.attack = self:AddCard("NPC_PA_attack_two")
                    self.defend = self:AddCard("NPC_PA_defend_trio")
                    self.special_move = self:AddCard("NPC_PA_special_move_two")

                    self:SetPattern( self.Cycle )
                    self.fighter:AddCondition("NPC_PA_BACK_DOWN")

                end,

                Cycle = function( self, turns )
                    if turns % 3 == 0 then
                        self:ChooseCard(self.defend)
                    elseif (turns + 1) % 3 == 0 then
                        self:ChooseCard(self.special_move)
                    else
                        self:ChooseCard(self.attack)
                    end
                end,
            },
        },
    })
)

Content.GetCharacterDef("NPC_PA_TRIO_BOSS_2"):InheritBaseDef()

Content.AddCharacterDef
(
    CharacterDef("NPC_PA_TRIO_BOSS_3",
    {
        unique = true,
        base_def = "NPC_BASE",
        alias = "NPC_PA_TRIO_BOSS_3",
        title = "Trio",
        species = SPECIES.SHROKE,
        gender = GENDER.MALE,
        skin_colour = 0x5B706BFF,
        renown = 2,
        combat_strength = 2,
        boss = true,
        name = "Trey",
        faction_id = "BANDITS",
        bio = "And yes—his name is Trey.",

        loved_graft = "PA_GIFT_PRESTIGE",
        hated_graft = "PA_GIFT_WIMPY",
        death_item = "PC_ALAN_BLOOD_PACT_CLAW",

        voice_actor = "spreeLowClassMale01",
        can_talk = true,

        anims = {"anim/weapon_knuckles_bandit_common.zip"},
        combat_anims = {"anim/med_combat_knuckles_bandit_goon.zip"},
        build = "male_bandit_promoted_build",
        head = "head_male_shroke_04",

        negotiation_data =
        {
            behaviour =
            {
                KINGPIN = 0,

                OnInit = function( self )
                    self.escalation = self:AddArgument( "ESCALATION" )
                    self.kingpin = self:AddArgument( "KINGPIN" )
                    self.greedy = self:AddArgument( "GREEDY" )

                    if self.difficulty <= 2 then
                        self:SetPattern( self.BasicCycle )
                    else
                        self:SetPattern( self.Cycle )
                    end

                    self.negotiator:AddModifier("SHORT_FUSE")
                end,

                BasicCycle = function( self, turns )
                    if turns == 2 then
                        self:ChooseCard( self.escalation )
                        self:ChooseGrowingNumbers( 1, 1 )

                    elseif (turns-1) % 3 == 0 then
                        self:ChooseGrowingNumbers( 2, 1 )
                    else
                        self:ChooseGrowingNumbers( 1, 1 )
                    end
                end,

                Cycle = function( self, turns )
                    if turns % 3 == 0 then
                        self:ChooseCard( self.greedy )
                    end

                    if self.difficulty >= 4 and turns % 2 == 0 then
                        self:ChooseGrowingNumbers( 3, -1 )
                    elseif turns % 2 == 0 then
                        self:ChooseGrowingNumbers( 2, 1 )
                    else
                        self:ChooseGrowingNumbers( 1, 3 )
                    end

                    if (turns - 1) % 5 == 0 and not self.negotiator:FindModifier( "ESCALATION" ) then
                        self:ChooseCard( self.escalation )
                    end

                    if self.KINGPIN > 0 then
                        if (turns + 3) % 5 == 0 and not self.negotiator:FindModifier( "KINGPIN" ) then
                            self:ChooseCard( self.kingpin )
                        end
                    end
                end,
            }
        },

        fight_data = 
        {
            MAX_MORALE = MAX_MORALE_LOOKUP.VERY_LOW,
            MAX_HEALTH = 50,


            attacks = 
            {
                NPC_PA_special_move_three = table.extend(NPC_ATTACK)
                {
                    name = "Strike",
                    anim = "cut",

                    flags = CARD_FLAGS.MELEE | CARD_FLAGS.DEBUFF,

                    damage_mult = 0.4,

                    OnPostResolve = function( self, battle, attack )
                        if not attack:CheckHitResult( attack.target, "evaded" ) and not attack:CheckHitResult( attack.target, "defended" ) then
                            if attack.target:IsPlayer() then
                                local cards = {
                                    Battle.Card( "status_winded", attack.target ),
                                    Battle.Card( "status_winded", attack.target )
                                }
                                battle:DealCards( cards, battle:GetDiscardDeck() )
                            else
                                attack.target:AddCondition( "STUN", 1 )
                            end
                        end
                    end,
                },

                NPC_PA_attack_three = table.extend(NPC_ATTACK)
                {
                    name = "Punch",
                    anim = "thousand_cuts",

                    flags = CARD_FLAGS.MELEE,

                    OnPostResolve = function( self, battle, attack )
                    
                    end,

                    target_count = 3,
                    damage_mult = 0.33,
                },
            },

            behaviour =
            {
                OnActivate = function( self )
                    self.attack = self:AddCard("NPC_PA_attack_three")
                    self.defend = self:AddCard("NPC_PA_defend_trio")
                    self.special_move = self:AddCard("NPC_PA_special_move_three")

                    self:SetPattern( self.Cycle )
                    self.fighter:AddCondition("NPC_PA_BACK_DOWN")

                local agent = Agent("NPC_PA_TRIO_BOSS_2")
                agent:GetSocialConnections():SetRelationship( RELATIONSHIP.LOVED, self.fighter:GetAgent() )

                end,

                Cycle = function( self, turns )
                    if turns % 3 == 0 then
                        self:ChooseCard(self.special_move)
                    elseif (turns + 1) % 3 == 0 then
                        self:ChooseCard(self.attack)
                    else
                        self:ChooseCard(self.defend)
                    end
                end,
            },
        },
    })
)

Content.GetCharacterDef("NPC_PA_TRIO_BOSS_3"):InheritBaseDef()