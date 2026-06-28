local battle_defs = require "battle/battle_defs"
local BATTLE_EVENT = battle_defs.BATTLE_EVENT
local BATTLE_CARD_FLAGS = battle_defs.CARD_FLAGS
local negotiation_defs = require "negotiation/negotiation_defs"
local MINIGAME_EVENT = negotiation_defs.EVENT
local MINIGAME_CARD_FLAGS = negotiation_defs.CARD_FLAGS

local function CalculateConditionText( source, condition_id, stacks, target )
	if source.engine then
        local modified_stacks = source.engine:CalculateModifiedStacks( condition_id, stacks, target or source.target, source )
        
		if modified_stacks < stacks then
            return string.format( "<#PENALTY_CARD_TEXT>%d</>", modified_stacks )
        elseif modified_stacks > stacks then
            return string.format( "<#BONUS_CARD_TEXT>%d</>", modified_stacks )
        end
    end

    return tostring(stacks)
end

Content.AddCharacterDef
(
    CharacterDef("NPC_PA_DRONE_C4",
    {
		unique = true,
		base_def = "NPC_BASE",
		alias = "NPC_PA_DRONE_C4",
        build = "lumin_turret",
		species = SPECIES.MECH,
		gender = GENDER.MALE,
        renown = 1,
        combat_strength = 4,
        name = "C4",
		title = "Drone",
        faction_id = "CULT_OF_HESH",
        death_item = "PC_ALAN_SUSPICIOUS_POWER_SOURCE",
		bio = "Somewhere in the Cult of Hesh, someone had come up with that idea.",
		
		boss = true,
		unique = true,
		can_talk = true,
        aspects = {
            social_connections = false,
        },
        fight_data = 
        {
            MAX_HEALTH = 90,

            MAX_MORALE = MAX_MORALE_LOOKUP.IMMUNE,
            
            attacks = 
            {
                NPC_PA_three = table.extend(NPC_BUFF)
                {
                    name = "THREE",
                    anim = "step_forward",
                    flags = BATTLE_CARD_FLAGS.BUFF,
                    target_type = TARGET_TYPE.SELF,
                    defend_amt = {10, 10, 12, 12},

                    OnPostResolve = function( self, battle )
                        self.owner:AddCondition("DEFEND", self.defend_amt[math.min(GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1, #self.defend_amt)], self)
                    end
                },

                NPC_PA_two = table.extend(NPC_BUFF)
                {
                    name = "TWO",
                    anim = "step_forward",
                    flags = BATTLE_CARD_FLAGS.BUFF,
                    target_type = TARGET_TYPE.SELF,
                    pwr_amt = {3, 3, 5, 5},
					
					OnPostResolve = function( self, battle, attack )
                        self.owner:AddCondition("POWER", self.pwr_amt[math.min(GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1, #self.pwr_amt)], self)
                    end
                },


                NPC_PA_one = table.extend(NPC_BUFF)
                {
                    name = "ONE",
                    anim = "taunt2",
                    flags = BATTLE_CARD_FLAGS.DEBUFF,
                    target_type = TARGET_TYPE.ENEMY,
                    target_mod = TARGET_MOD.TEAM,
                    dread_amt = {1, 1, 1, 2},

                    OnPostResolve = function( self, battle, attack )
                        attack:AddCondition("dread", self.dread_amt[math.min(GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1, #self.dread_amt)], self)
                    end
                },
				
				NPC_PA_Startup_complete = table.extend(NPC_ATTACK)
				{
					name = "Startup Complete",
                    anim = "shoot",
                    flags = BATTLE_CARD_FLAGS.RANGED,
                    target_type = TARGET_TYPE.ENEMY,
                    target_mod = TARGET_MOD.TEAM,
					target_count = 3,

                    min_damage = 1,
                    max_damage = 3,
				},
            },


            behaviour =
            {
                OnActivate = function( self, fighter )
                	self.three = self:AddCard("NPC_PA_three", 1)

					self.two = self:AddCard("NPC_PA_two", 1)

					self.one = self:AddCard("NPC_PA_one", 1)

					self.attack = self:AddCard("NPC_PA_Startup_complete", 1)

					self.fighter:AddCondition("METALLIC")
					
                    self:SetPattern(self.ComboCycle)
                end,

                ComboCycle = function( self )
                    
                    if self.battle:GetTurns() == 1 then
                        self:ChooseCard(self.three)
                    elseif self.battle:GetTurns() == 2 then
                        self:ChooseCard(self.two)
                    elseif self.battle:GetTurns() == 3 then
                    	self:ChooseCard(self.one)
                    else
                        self:ChooseCard(self.attack)
                    end
                end
            },
        },

        anims = { "anim/med_combat_drone_tei.zip", },
        combat_anims = { "anim/med_combat_drone_tei.zip" },
    })
)

Content.GetCharacterDef("NPC_PA_DRONE_C4"):InheritBaseDef()
