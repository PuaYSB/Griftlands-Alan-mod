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
    CharacterDef("NPC_PA_TESTING",
    {
		unique = true,
		base_def = "NPC_BASE",
		alias = "NPC_PA_TESTING",
		--head = "head_rook",
        build = "lumin_turret",
		species = SPECIES.MECH,
		gender = "MALE",
        renown = 1,
        combat_strength = 4,
        name = "代号C4",
		title = "无人机",
        faction_id = "NEUTRAL",
        --death_item = "PC_ARINT_twin_modified_pistols",
		--theme_music = "event:/music/slideshow_rook",
		bio = "铤而走险制造出的棋子。",
		
		boss = true,
		unique = true,
		can_talk = true,
        aspects = {
            social_connections = false,
        },
        fight_data = 
        {
            MAX_HEALTH = 120,

            MAX_MORALE = MAX_MORALE_LOOKUP.IMMUNE,
            
            conditions = 
            { 
                NPC_PA_boss_charges = 
                {
                    name = "充能倒计时",
                    desc = "当代号C4充能完毕后，将会不断造成恐怖的伤害。",
					icon = "battle/conditions/npc_rook_charges.tex",
					
					max_stacks = 3,
                },
			},

            attacks = 
            {
                -- COMBO ATTACKS
                NPC_PA_three = table.extend(NPC_BUFF)
                {
                    name = "三",
                    anim = "step_forward",
                    flags = BATTLE_CARD_FLAGS.BUFF,
                    target_type = TARGET_TYPE.SELF,
                    defend_amt = 10,

                    OnPostResolve = function( self, battle, attack )
						self.owner:RemoveCondition("NPC_PA_boss_charges", 1, self)
                        self.owner:AddCondition("DEFEND", self.defend_amt, self)
                    end
                },

                NPC_PA_two = table.extend(NPC_BUFF)
                {
                    name = "二",
                    anim = "step_forward",
                    flags = BATTLE_CARD_FLAGS.BUFF,
                    target_type = TARGET_TYPE.SELF,
                    pwr_amt = 3,
					
					OnPostResolve = function( self, battle, attack )
						self.owner:RemoveCondition("NPC_PA_boss_charges", 1, self)
                        self.owner:AddCondition("POWER", self.pwr_amt, self)
                    end
                },


                NPC_PA_one = table.extend(NPC_BUFF)
                {
                    name = "一",
                    anim = "taunt2",
                    flags = BATTLE_CARD_FLAGS.DEBUFF,
                    target_type = TARGET_TYPE.ENEMY,
                    target_mod = TARGET_MOD.TEAM,

                    OnPostResolve = function( self, battle, attack )
                    	self.owner:RemoveCondition("NPC_PA_boss_charges", 1, self)
                        attack:AddCondition("dread", 1, self)
                    end
                },
				
				NPC_PA_Startup_complete = table.extend(NPC_ATTACK)
				{
					name = "启动完毕",
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
                	self.three = self:MakePicker()
						:AddID("NPC_PA_three", 1)

					self.two = self:MakePicker()
						:AddID("NPC_PA_two", 1)

					self.one = self:MakePicker()
						:AddID("NPC_PA_one", 1)

					self.attack = self:MakePicker()
						:AddID("NPC_PA_Startup_complete", 1)

					self.fighter:AddCondition("NPC_PA_boss_charges", 3)
					self.fighter:AddCondition("METALLIC")
					
                    self:SetPattern(self.ComboCycle)
                end,

                ComboCycle = function( self )
                    
                    if self.battle:GetTurns() == 1 then
                        self.three:ChooseCard()
                    elseif self.battle:GetTurns() == 2 then
                        self.two:ChooseCard()
                    elseif self.battle:GetTurns() == 3 then
                    	self.one:ChooseCard()
                    else
                        self.attack:ChooseCard()
                    end
                end
            },
        },

        anims = { "anim/med_combat_drone_tei.zip", },
        combat_anims = { "anim/med_combat_drone_tei.zip" },
        --voice_actor = "rook",
    })
)

Content.GetCharacterDef("NPC_PA_TESTING"):InheritBaseDef()
