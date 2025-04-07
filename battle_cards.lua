local battle_defs = require "battle/battle_defs"
local CARD_FLAGS = battle_defs.CARD_FLAGS
local EVENT = battle_defs.EVENT

local BATTLE_EVENT = ExtendEnum( battle_defs.EVENT,
{
    "SPARK_RESERVE",
})

local function CalculateTotalAndMaxCost(engine, self)
    local total_cost = self.cost
    local max_cost = self.cost
    
    for _, hand_card in engine:GetHandDeck():Cards() do
        local cost = engine:CalculateActionCost(hand_card)
        total_cost = total_cost + cost
        if cost > max_cost then
            max_cost = cost
        end
    end
    
    return total_cost, max_cost
end

local function CalculateConditionText( source, condition_id, stacks, target )
    if source.engine then
        local modified_stacks = source.engine:CalculateModifiedStacks( condition_id, stacks, target or source.target, source )

        if modified_stacks < stacks then
            return string.format( "<#PENALTY_CARD_TEXT>%d</>", modified_stacks ), modified_stacks
        elseif modified_stacks > stacks then
            return string.format( "<#BONUS_CARD_TEXT>%d</>", modified_stacks ), modified_stacks
        end
    end

    return tostring(stacks), stacks
end


local CONDITIONS = 
{
    SPARK_RESERVE =
    {
        name = "Spark Reserve",
        desc = "Up to 10 stacks. At 10 stacks, clear all stack and dealing 25% max HP damage to the bearer.",
        icon = "battle/conditions/hardknocks.tex",
        ctype = CTYPE.DEBUFF,
        apply_sound = "event:/sfx/battle/status/system/Status_Buff_Attack",
        target_type = TARGET_TYPE.ANY,
        max_stacks = 10,

        OnApply = function(self)
            if not self.stacks then
                self.stacks = 0
            end
        end,

        event_handlers =
        {
            [BATTLE_EVENT.CONDITION_ADDED] = function(self, owner, condition, stacks, source)
                if owner == self.owner and condition.id == "SPARK_RESERVE" then
                    if condition.stacks >= condition.max_stacks then
                        local max_health = owner:GetMaxHealth()
                        local damage = math.floor(max_health * 0.25)
                        owner:ApplyDamage(damage)
                        owner:RemoveCondition("SPARK_RESERVE", condition.stacks, self)
                    end
                end
            end
        }
    },

    LUMIN_RESERVE =
    {
        name = "Lumin Reserve",
        desc = "Your next attack applies <#HILITE>{1} {lumin_burnt}</> and <#HILITE>{2} {DEFEND}</> to the target.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks, math.ceil(self.stacks / 5))
        end,
        icon = "battle/conditions/sharpened_blade.tex",
        ctype = CTYPE.BUFF,
        apply_sound = "event:/sfx/battle/status/system/Status_Buff_Attack",
        target_type = TARGET_TYPE.SELF,
        max_stacks = 99,
        event_handlers =
        {
            [ BATTLE_EVENT.ON_HIT ] = function(self, battle, attack, hit)
                if attack.attacker == self.owner and attack.card:IsAttackCard() and not hit.evaded then
                    local stacks = self.stacks or 0
                    if stacks > 0 then
                        local defend_amount = math.ceil(stacks / 5)
                        attack:AddCondition("lumin_burnt", stacks, self)
                        attack:AddCondition("DEFEND", defend_amount, self)
                        self.owner:RemoveCondition(self.id)
                    end
                end
            end
        }
    },

    WARM_UP =
    {
        name = "Warm-up",
        desc = "Grants adrenaline at the start of your turn.",
        hidden = true,
        event_handlers = 
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function(self, battle)
            local stacks = self.stacks or 1 
            self.owner:AddCondition("ADRENALINE", stacks, self)
            self.owner:RemoveCondition("WARM_UP")
        end
        },
    },

    NEXT_TURN_ACTION_ALAN =
    {
        name = "Next turn action by alan",
        desc = "Grants action at the start of your turn.",
        hidden = true,
        event_handlers = 
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
            battle:ModifyActionCount(self.stacks or 1)
            self.owner:RemoveCondition("NEXT_TURN_ACTION_ALAN")
        end
        },
    },

    NEXT_TURN_CARD_ALAN =
    {
        name = "Next turn card",
        desc = "Draw additional card at the start of your turn.",
        hidden = true,
        event_handlers = 
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
            battle:DrawCards(self.stacks or 1)
            self.owner:RemoveCondition("NEXT_TURN_CARD_ALAN")
        end
        },
    },

    PC_ALAN_QUICK =
    {
        name = "飞刀计数器",
        desc = "用以计算打出多少张飞刀.",
        hidden = true,
    },

    PA_HAULING_CARGO =
    {
        name = "Hauling Cargo",
        icon = "battle/conditions/workers_gloves.tex",        
        desc = "Whenever you play a card that have cost at least 2, Gain <#HILITE>{1}</> {DEFEND}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount * self.stacks))
        end,
        defend_amount = 3,
        event_handlers =
        {
            [ BATTLE_EVENT.START_RESOLVE ] = function( self, battle, card )
                if card.owner == self.owner and card.cost > 1 then
                    card.owner:AddCondition("DEFEND", (self.defend_amount * self.stacks), self)
                end
            end,
        }
    },

    PA_THROWING_KNIFE_REPLICAROR =
    {
        name = "Throwing Knife Replicator",
        icon = "battle/conditions/active_shield_generator.tex",        
        desc = "At turn start, insert <#HILITE>{1}</> {PC_ALAN_QUICK_THROW} into your hand.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks )
        end,
        event_handlers =
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
                    local cards = {}
                    for i = 1, self.stacks do
                        local incepted_card = Battle.Card( "PC_ALAN_QUICK_THROW", self:GetOwner() )
                        incepted_card.auto_deal = true
                        table.insert( cards, incepted_card )
                    end
                    battle:DealCards( cards , battle:GetHandDeck() )
                end
        }
    },

    PA_SPARK_CORE =
    {
        name = "Spark Core",
        icon = "battle/conditions/defect.tex",        
        desc = "At turn start, Gain <#HILITE>{1} {SPARK_RESERVE}</> and <#HILITE>{1} {ADRENALINE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks * 2 )
        end,
        event_handlers =
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
            self.owner:AddCondition("ADRENALINE", (self.stacks * 2), self)
            self.owner:AddCondition("SPARK_RESERVE", (self.stacks * 2), self)
            end
        }
    },

    PA_LUMIN_SHIELD_GENERATOR =
    {
        name = "Lumin Shield Generator",
        icon = "battle/conditions/protective_procedure.tex",        
        desc = "At turn end, Gain the {DEFEND} equal to the {LUMIN_RESERVE}.",
        max_stacks = 1,
        event_handlers = 
        {
            [ BATTLE_EVENT.END_PLAYER_TURN ] = function( self, battle, condition )
            self.lumin_reserve = self.owner:GetConditionStacks( "LUMIN_RESERVE" ) or 0
            if self.lumin_reserve > 0 then
                self.owner:AddCondition("DEFEND", self.lumin_reserve, self)
            end
            end
        }
    },

    PA_DEEP_POCKETS =
    {
        name = "Deep Pockets",
        icon = "battle/conditions/combat_analysis.tex",        
        desc = "At turn start, draw <#HILITE>{1}</> card.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks )
        end,
        event_handlers =
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
            battle:DrawCards(self.stacks or 1)
            end
        }
    },

    PA_IMPROVEMENT =
    {
        name = "Improvement",
        desc = "The chosen card will deal 3 bonus damage until played.",
        hidden = true,
        event_priorities =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = EVENT_PRIORITY_MULTIPLIER,
        },
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if self.chosen_cards and table.contains(self.chosen_cards, card) then
                    local bonus_damage = 3 * self.stacks 
                    dmgt:AddDamage(bonus_damage, bonus_damage, self)
                end
            end,

            [ BATTLE_EVENT.END_RESOLVE ] = function( self, battle, card )
            if self.chosen_cards and table.contains(self.chosen_cards, card) then
                table.arrayremoveall(self.chosen_cards, card)
                if #self.chosen_cards == 0 then
                    self.owner:RemoveCondition(self.id)
                end
            end
            end
        }
    },

    PA_RHYTHM =
    {
        name = "Rhythm",
        icon = "battle/conditions/drive.tex",        
        desc = "Whenever you play a card that costs 0, gain <#HILITE>{1}</> {ADRENALINE}.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.stacks)
        end,
        event_handlers = 
        {
            [ BATTLE_EVENT.START_RESOLVE ] = function(self, battle, card, cost)
            if card.owner == self.owner and battle:CalculateActionCost(card) == 0 then
                self.owner:AddCondition("ADRENALINE", self.stacks or 1, self)
            end
            end,
        },
    },

    PA_CHARGE_UP =
    {
        name = "Charge Up",
        icon = "battle/conditions/concentration.tex",        
        desc = "At turn start, choose a card, double the damage of that card on this turn.",
        max_stacks = 1,
        deck_handlers = { DECK_TYPE.IN_HAND },
        event_handlers = 
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
            local hand = battle:GetHandDeck()

            local card = battle:ChooseCard( function(x) return x:IsDamageCard() end)
            if card and card:IsDamageCard() then
                local con = self.owner:GetCondition("cynotrainer") or self.owner:AddCondition("cynotrainer", 1, self)
                if con then
                    if con.buffed_cards then
                        table.insert(con.buffed_cards, card)
                    else
                        con.buffed_cards = {card}
                    end
                end
            end
            end,
        }
    },

    PA_BACKUP_LUMIN_FUEL =
    {
        name = "Backup Lumin Fuel",
        icon = "battle/conditions/duplication_potion.tex",        
        desc = "At the end of your turn, gain <#HILITE>{1}</> {LUMIN_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks * 2 )
        end,
        event_handlers =
        {
            [ BATTLE_EVENT.END_PLAYER_TURN ] = function( self, battle )
            self.owner:AddCondition("LUMIN_RESERVE", (self.stacks * 2), self)
            end
        }
    },

    PA_OVERLOADED_CORE =
    {
        name = "Overloaded Core",
        icon = "battle/conditions/charged_strikes.tex",        
        desc = "Gain {POWER} equal to your {SPARK_RESERVE}. When the amount of {SPARK_RESERVE} changes, the amount of {POWER} will also change.",
        max_stacks = 1,
        event_handlers =
        {
            [ BATTLE_EVENT.CONDITION_ADDED ] = function(self, owner, condition, stacks, source)
            if owner == self.owner and condition.id == "SPARK_RESERVE" then
                local new_spark_reserve = self.owner:GetConditionStacks("SPARK_RESERVE") or 0
                local diff = new_spark_reserve - (self.spark_reserve or 0)
                if diff > 0 then
                    self.owner:AddCondition("POWER", diff, self)
                end
                self.spark_reserve = new_spark_reserve
            end
            end,

            [ BATTLE_EVENT.CONDITION_REMOVED ] = function(self, owner, condition, stacks, source)
            if owner == self.owner and condition.id == "SPARK_RESERVE" then
                local new_spark_reserve = self.owner:GetConditionStacks("SPARK_RESERVE") or 0
                local diff = new_spark_reserve - (self.spark_reserve or 0)
                if diff < 0 then
                    self.owner:AddCondition("POWER", diff, self)  
                end
                self.spark_reserve = new_spark_reserve
            end
            end
        }
    },

    PA_PERFECT_ACCURACY =
    {
        name = "Perfect Accuracy",
        icon = "battle/conditions/combo.tex",        
        desc = "Your attacks deal max damage.",
        max_stacks = 1,
        event_handlers =
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
            self.owner:AddCondition("improve_accuracy", self.stacks, self)
            end
        }
    },

    PA_POWER_SURGE =
    {
        name = "Power Surge",
        icon = "battle/conditions/furor.tex",        
        desc = "Whenever you play a card that have cost at least 2, Play it again.",
        max_stacks = 1,
        event_handlers =
        {
            [ BATTLE_EVENT.START_RESOLVE ] = function(self, battle, card, attack)
            if card and card.owner == self.owner and card.cost and card.cost >= 2 then
                if not card.surge_played then
                    card.surge_played = true  
                    battle:PlayCard(card) 
                end
            end
            end,
        }
    },

    PA_LUMIN_BOOST =
    {
        name = "Lumin Boost",
        icon = "battle/conditions/lumin_daze.tex",        
        desc = "Each time you gain {LUMIN_RESERVE}, gain <#HILITE>{1}</> {POWER}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks)
        end,
        event_handlers =
        {
            [ BATTLE_EVENT.CONDITION_ADDED ] = function(self, owner, condition, stacks, source)
            if owner == self.owner and condition.id == "LUMIN_RESERVE" then
                    self.owner:AddCondition("POWER", self.stacks, self)
                end
            end,
        }
    },
}

for id, def in pairs( CONDITIONS ) do
    Content.AddBattleCondition( id, def )
end

local CARDS =
{
    PC_ALAN_PUNCH =
    {
        name = "Punch",
        icon = "battle/sucker_punch.tex",
        anim = "punch",
        flavour = "'No one said I can't use my fists.'",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.MELEE,
        cost = 1,
        max_xp = 7,
        min_damage = 2,
        max_damage = 5,
    },

    PC_ALAN_PUNCH_plus2a =
    {
        name = "Punch of Clarity",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.CONSUME,
        min_damage = 8,
        max_damage = 10,
    },

    PC_ALAN_PUNCH_plus2b =
    {
        name = "Rooted Punch",
        flags = CARD_FLAGS.MELEE,
        min_damage = 4,
        max_damage = 5,
    },

    PC_ALAN_PUNCH_plus2c =
    {
        name = "Lucid Punch",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.EXPEND,
        min_damage = 5,
        max_damage = 8,
    },

    PC_ALAN_PUNCH_plus2d =
    {
        name = "Pale Punch",
        flags = CARD_FLAGS.MELEE ,
        cost = 0,
        min_damage = 2,
        max_damage = 5,
    },

    PC_ALAN_PUNCH_plus2e =
    {
        name = "Punch of Vision",
        flags = CARD_FLAGS.MELEE ,
        desc = "<#UPGRADE>draw a card</>.",
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(1)
        end,
        min_damage = 2,
        max_damage = 5,
    },

    PC_ALAN_PUNCH_plus2f =
    {
        name = "Spark Punch",
        flags = CARD_FLAGS.MELEE,
        desc = "<#UPGRADE>Apply {1} {SPARK_RESERVE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "SPARK_RESERVE", self.spark_amt ))
        end,
        OnPostResolve = function(self, battle, attack)
            if attack and attack.target then
                attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
        end
    end,
        min_damage = 2,
        max_damage = 5,
        spark_amt = 2,
    },

    PC_ALAN_PUNCH_plus2g =
    {
        name = "Punch of the Stone",
        flags = CARD_FLAGS.MELEE,
        desc = "<#UPGRADE>Gain {1} {DEFEND}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        min_damage = 2,
        max_damage = 5,
        defend_amount = 3,
    },

    PC_ALAN_THROW_BOTTLE =
    {
        name = "Throw Bottle",
        icon = "battle/right_in_the_face.tex",
        anim = "throw",
        flavour = "'I'd better prepare more bottles, whether for storing or throwing.'",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.RANGED,
        cost = 0,
        max_xp = 8,
        min_damage = 3,
        max_damage = 3,
    },

    PC_ALAN_THROW_BOTTLE_plus2a =
    {
        name = "Boosted Throw Bottle",
        flags = CARD_FLAGS.RANGED ,
        min_damage = 5,
        max_damage = 5,
    },

    PC_ALAN_THROW_BOTTLE_plus2b =
    {
        name = "Throw of Clarity",
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.CONSUME,
        min_damage = 10,
        max_damage = 10,
    },

    PC_ALAN_THROW_BOTTLE_plus2c =
    {
        name = "Throw of Vision",
        flags = CARD_FLAGS.RANGED ,
        desc = "<#UPGRADE>Draw a card</>.",
        min_damage = 3,
        max_damage = 3,
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(1)
        end,
    },

    PC_ALAN_THROW_BOTTLE_plus2d =
    {
        name = "Throw Heavy Bottle",
        flags = CARD_FLAGS.RANGED ,
        cost = 2,
        min_damage = 10,
        max_damage = 10,
    },

    PC_ALAN_THROW_BOTTLE_plus2e =
    {
        name = "Throw Lumin Bottle",
        flags = CARD_FLAGS.RANGED ,
        desc = "<#UPGRADE>Apply {1} {lumin_burnt}</>.",
        min_damage = 3,
        max_damage = 3,
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.lumin_burnt_amt )
        end,
        lumin_burnt_amt = 3,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("lumin_burnt", self.lumin_burnt_amt, self)
        end
    },

    PC_ALAN_THROW_BOTTLE_plus2f =
    {
        name = "Weighted Throw Bottle",
        flags = CARD_FLAGS.RANGED ,
        desc = "<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Deal bonus damage double to the cost of the most expensive card in your hand</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        min_damage = 3,
        max_damage = 3,
        weight_thresh = 3,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function(self, card, target, dmgt)
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost >= self.weight_thresh and max_cost > 0 then
                    local extra_damage = max_cost * 2
                    dmgt:AddDamage(extra_damage, extra_damage, self)
                end
            end
            end,
        }
    },  

    PC_ALAN_THROW_BOTTLE_plus2g =
    {
        name = "Tall Throw Bottle",
        flags = CARD_FLAGS.RANGED,
        min_damage = 3,
        max_damage = 7,
    },

    PC_ALAN_READY_FOR_DODGE =
    {
        name = "Ready for Dodge",
        icon = "battle/feint.tex",
        anim = "step_back",
        flavour = "'Watch out for the enemy—they seem to be preparing an attack.'",
        desc = "Apply {1} {DEFEND}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        defend_amount = 4,
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        cost = 1,
        max_xp = 8,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition( "DEFEND", self.defend_amount, self )
        end
    },

    PC_ALAN_READY_FOR_DODGE_plus2a =
    {
        name = "Boosted Ready for Dodge",
        desc = "Apply <#UPGRADE>{1}</> {DEFEND}.",        
        flags = CARD_FLAGS.SKILL,
        defend_amount = 6,
    },

    PC_ALAN_READY_FOR_DODGE_plus2b =
    {
        name = "Lucid Ready for Dodge",
        desc = "Apply {1} {DEFEND} and<#UPGRADE> 1 {EVASION}</>.",       
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        eva_amt = 1,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition( "DEFEND", self.defend_amount, self )
            self.owner:AddCondition("EVASION", self.eva_amt, self)
        end,
    },

    PC_ALAN_READY_FOR_DODGE_plus2c =
    {
        name = "Lumin Ready for Dodge",
        desc = "Apply {1} {DEFEND} and<#UPGRADE> {2} {LUMIN_RESERVE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),CalculateConditionText(self, "LUMIN_RESERVE", self.lumin_res_amt))
        end,        
        flags = CARD_FLAGS.SKILL,
        OnPostResolve = function(self, battle, attack)
            attack:AddCondition("DEFEND", self.defend_amount, self)
            attack:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end,
        lumin_res_amt = 3,
    },

    PC_ALAN_READY_FOR_DODGE_plus2d =
    {
        name = "Spark Ready for Dodge",
        desc = "Apply {1} {DEFEND}.\n<#UPGRADE>Gain {2} {SPARK_RESERVE}.\nSpend 1 {SPARK_RESERVE}: Gain additional {1} {DEFEND}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),CalculateConditionText(self, "SPARK_RESERVE", self.spark_amt))
        end,        
        flags = CARD_FLAGS.SKILL,
        spark_amt = 2,
        OnPostResolve = function(self, battle, attack)
            if self.owner:GetConditionStacks("SPARK_RESERVE") > 0 then
                self.owner:RemoveCondition("SPARK_RESERVE", 1, self)
                self.defend_amount = 8
            end

            self.owner:AddCondition("DEFEND", self.defend_amount, self)
            self.owner:AddCondition("SPARK_RESERVE", self.spark_amt, self)
        end,
        spark_amt = 2,
        defend_amount = 4,
    },

    PC_ALAN_READY_FOR_DODGE_plus2e =
    {
        name = "Weighted Ready for Dodge",
        desc = "Apply {1} {DEFEND}.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{2}: Gain 1 Action</>.",   
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),self.weight_thresh)
        end,     
        flags = CARD_FLAGS.SKILL,
        action_bonus = 1,
        weight_thresh = 5,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_READY_FOR_DODGE_plus2f =
    {
        name = "Lightweight Ready for Dodge",
        desc = "Apply {1}{DEFEND}.\n<#UPGRADE>{PC_ALAN_LIGHTWEIGHT}{2}: Apply additional 3 {DEFEND}</>.",  
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),self.light_thresh)
        end,      
        flags = CARD_FLAGS.SKILL,
        light_thresh = 2,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                self.defend_amount = 7
            end
        end,
    },

    PC_ALAN_CHEMICAL_RESERVES =
    {
        name = "Fuel Reserve",
        icon = "battle/auxiliary.tex",
        flavour = "'Before deciding, I’d better prepare a bit of both—though both sides will likely have opinions.'",
        desc = "Insert {PC_ALAN_LUMIN} or {PC_ALAN_SPARK} into your hand.",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 8,

        OnPostResolve = function( self, battle, attack)
            local cards = {
                Battle.Card( "PC_ALAN_LUMIN", self.owner ),
                Battle.Card( "PC_ALAN_SPARK", self.owner ),
            }
            battle:ChooseCardsForHand( cards, nil, nil, nil, nil, nil, self )
        end,
    },

    PC_ALAN_LUMIN =
    {
        name = "Lumin",
        icon = "battle/lumin_canister.tex",
        anim = "taunt",
        flavour = "'Lumin, discovered by the Cult of Hesh during their search for Hesh, is relatively stable but still highly dangerous.'",
        desc = "Gain {1} {LUMIN_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "LUMIN_RESERVE", self.lumin_res_amt ))
        end,
        lumin_res_amt = 3,
        cost = 0,
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function(self, battle, attack)
            attack:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end,
    },

    PC_ALAN_SPARK =
    {
        name = "Spark",
        icon = "battle/sparkys_oppressor_cell.tex",
        flavour = "'Spark, first discovered around Lakespit, is of unknown flammability but is certainly highly explosive.'",
        anim = "throw",
        desc = "Apply {1} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "SPARK_RESERVE", self.spark_amt ))
        end,
        min_damage = 3,
        max_damage = 3,
        spark_amt = 2,
        cost = 0,
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.ENEMY,
        OnPostResolve = function(self, battle, attack)
            if attack and attack.target then
                attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
        end
    end,
    },

    PC_ALAN_CHEMICAL_RESERVES_plus =
    {
        name = "Lumin Reserve",
        icon = "battle/lumin_canister.tex",
        flavour = "'Better stock up on Lumin—my place can't handle daily explosions.'",
        desc = "Insert <#UPGRADE>{PC_ALAN_LUMIN_2a}</> or <#UPGRADE>{PC_ALAN_LUMIN_2b}</> into your hand.",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 8,

        OnPostResolve = function( self, battle, attack)
            local cards = {
                Battle.Card( "PC_ALAN_LUMIN_2a", self.owner ),
                Battle.Card( "PC_ALAN_LUMIN_2b", self.owner ),
            }
            battle:ChooseCardsForHand( cards, nil, nil, nil, nil, nil, self )
        end,
    },

    PC_ALAN_LUMIN_2a =
    {
        name = "Lumin Coating",
        icon = "battle/spear_head.tex",
        flavour = "'Apply it to your weapon, give the enemy a light scrape, and then watch them start begging for mercy.'",
        desc = "Gain {1} {LUMIN_RESERVE} and {2} {DEFEND}.",
        desc_fn = function(self, fmt_str)
        return loc.format(fmt_str, CalculateConditionText(self, "LUMIN_RESERVE", self.lumin_res_amt), self:CalculateDefendText(self.defend_amount))
    end,
        lumin_res_amt = 3,
        defend_amount = 4,
        cost = 0,
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function(self, battle, attack)
            attack:AddCondition("DEFEND", self.defend_amount, self)
            attack:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end,
    },

    PC_ALAN_LUMIN_2b =
    {
        name = "Lumin Tonic",
        icon = "battle/status_lumin_burn.tex",
        flavour = "'Or, if you find it troublesome, just throw it over instead.'",
        anim = "throw",
        desc = "Apply {1} {lumin_burnt}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.lumin_burnt_amt )
        end,
        lumin_burnt_amt = 3,
        cost = 0,
        min_damage = 4,
        max_damage = 6,
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.ENEMY,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("lumin_burnt", self.lumin_burnt_amt, self)
        end
    },

    PC_ALAN_CHEMICAL_RESERVES_plus2 =
    {
        name = "Spark Reserve",
        icon = "battle/sparkys_oppressor_cell.tex",
        anim = "taunt",
        flavour = "'Better stick with Spark—my equipment isn’t that well-sealed.'",
        desc = "Insert <#UPGRADE>{PC_ALAN_SPARK_2a}</> or <#UPGRADE>{PC_ALAN_SPARK_2b}</> into your hand.",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 8,

        OnPostResolve = function( self, battle, attack)
            local cards = {
                Battle.Card( "PC_ALAN_SPARK_2a", self.owner ),
                Battle.Card( "PC_ALAN_SPARK_2b", self.owner ),
            }
            battle:ChooseCardsForHand( cards, nil, nil, nil, nil, nil, self )
        end,
    },

    PC_ALAN_SPARK_2a =
    {
        name = "Spark Throw",
        icon = "battle/twist.tex",
        anim = "throw",
        flavour = "'Just toss it over and wait for the boom.'",
        desc = "Gain {1} {SPARK_RESERVE}.\nApply {2} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "SPARK_RESERVE", self.self_spark_amt), CalculateConditionText(self, "SPARK_RESERVE", self.target_spark_amt))
        end,
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.EXPEND,
        cost = 0,
        min_damage = 3,
        max_damage = 3,
        self_spark_amt = 2,
        target_spark_amt = 4,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("SPARK_RESERVE", self.self_spark_amt, self)
            if attack and attack.target then
                attack.target:AddCondition("SPARK_RESERVE", self.target_spark_amt, self)
            end
        end,
    },

    PC_ALAN_SPARK_2b =
    {
        name = "Spark Boost",
        icon = "battle/overloaded_spark_hammer_hatch.tex",
        anim = "throw",
        flavour = "'It’s best to use Spark right away—leave too much together for too long, and it might react.'",
        desc = "Spend 1 {SPARK_RESERVE}: Deal 4 bonus damage.",
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.EXPEND,
        cost = 0,
        min_damage = 4,
        max_damage = 4,
        event_handlers =
        {
            [ BATTLE_EVENT.START_RESOLVE ] = function(self, battle, card)
            if card == self then
                if self.owner:GetConditionStacks("SPARK_RESERVE") > 0 then
                    self.owner:RemoveCondition("SPARK_RESERVE", 1, self)
                    self.using_spark = true
                else
                    self.using_spark = false
                end
            end
        end,

        [ BATTLE_EVENT.CALC_DAMAGE ] = function(self, card, target, dmgt)
            if card == self and self.using_spark then
                dmgt:AddDamage(4, 4, self)
            end
        end,

        [ BATTLE_EVENT.CARD_MOVED ] = function(self, card, source_deck, source_idx, target_deck, target_idx)
            if card == self and target_deck == self.engine:GetHandDeck() then
                self.using_spark = false
            end
            end
        }
    },

    PC_ALAN_MEDICINE_BAG =
    {
        name = "Tonic Pouch",
        icon = "battle/ammo_pouch.tex",
        desc = "{IMPROVISE} a card from a pool of special cards.",
        flavour = "'Carrying tonics is just common sense—at least for me.'",
        target_type = TARGET_TYPE.SELF,
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.SKILL,
        cost = 1,
        has_checked = false,
        pool_size = 3,
        pool_cards = {"PC_ALAN_MEDICINE_a", "PC_ALAN_MEDICINE_b", "PC_ALAN_MEDICINE_c", "PC_ALAN_MEDICINE_d", "PC_ALAN_MEDICINE_e", "PC_ALAN_MEDICINE_f", "PC_ALAN_MEDICINE_g", "PC_ALAN_MEDICINE_h"},

        OnPostResolve = function( self, battle, attack)
            local cards = ObtainWorkTable()

            cards = table.multipick( self.pool_cards, self.pool_size )
            for k,id in pairs(cards) do
                cards[k] = Battle.Card( id, self.owner  )
            end
            battle:ImproviseCards( cards, 1, nil, nil, nil, self )
            ReleaseWorkTable(cards)
        end,
    },

    PC_ALAN_MEDICINE_BAG_plus =
    {
        name = "Promoted Tonic Pouch",
        desc = "{IMPROVISE} a card from a pool of <#UPGRADE>upgraded</> special cards.",
        pool_cards = {"PC_ALAN_MEDICINE_a_upgraded", "PC_ALAN_MEDICINE_b_upgraded", "PC_ALAN_MEDICINE_c_upgraded", "PC_ALAN_MEDICINE_d_upgraded", "PC_ALAN_MEDICINE_e_upgraded", "PC_ALAN_MEDICINE_f_upgraded", "PC_ALAN_MEDICINE_g_upgraded", "PC_ALAN_MEDICINE_h_upgraded"},
    },

    PC_ALAN_MEDICINE_BAG_plus2 = 
    {
        name = "Boosted Tonic Pouch",
        desc = "<#UPGRADE>{IMPROVISE_PLUS}</> a card from a pool of special cards.",
        pool_size = 5,
    },

    PC_ALAN_MEDICINE_a = 
    {
        name = "Small Bonded Elixir",
        icon = "battle/bombard_bonded_elixir.tex",
        anim = "throw",
        flavour = "'Sacrificed dosage for portability, but it’s no big deal.'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        min_damage = 1,
        max_damage = 2,
        features =
        {
            WOUND = 2,
        },
    },

    PC_ALAN_MEDICINE_a_upgraded =
    {
        name = "Boosted Small Bonded Elixir",
        icon = "battle/bombard_bonded_elixir.tex",
        anim = "throw",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        min_damage = 1,
        max_damage = 2,
        features =
        {
            WOUND = 3,
        },
    },

    PC_ALAN_MEDICINE_b = 
    {
        name = "Overloaded Bottle",
        icon = "battle/bombard_noxious_vial.tex",    
        anim = "throw",
        desc = "{PC_ALAN_WEIGHTED} {1}: Deal bonus damage equal to the cost of the most expensive card in your hand.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,   
        flavour = "'To ensure it explodes, I’ve filled it with a hefty amount of gas.'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        min_damage = 3,
        max_damage = 3,
        weight_thresh = 3,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost >= self.weight_thresh and max_cost >= 0 then
                    local extra_damage = max_cost
                    dmgt:AddDamage(extra_damage, extra_damage, self)
                end
            end
        end
    }

    },

    PC_ALAN_MEDICINE_b_upgraded = 
    {
        name = "Boosted Overloaded Bottle",
        icon = "battle/bombard_noxious_vial.tex",    
        anim = "throw",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        min_damage = 5,
        max_damage = 5,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost >= 3 and max_cost >= 0 then
                    local extra_damage = max_cost
                    dmgt:AddDamage(extra_damage, extra_damage, self)
                end
            end
        end
    }   
    },

    PC_ALAN_MEDICINE_c = 
    {
        name = "Diluted Tincture",
        icon = "battle/tincture.tex",
        flavour = "'At least now it can be taken multiple times a day.'",
        cost = 1,
        max_xp = 0,       
        anim = "taunt",
        target_type = TARGET_TYPE.SELF,

        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,

        features = 
        {
            POWER = 1
        },
    },

    PC_ALAN_MEDICINE_c_upgraded = 
    {
        name = "Pale Diluted Tincture",
        icon = "battle/tincture.tex",
        cost = 0,
        anim = "taunt",
        target_type = TARGET_TYPE.SELF,
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,

        features = 
        {
            POWER = 1
        },
    },

    PC_ALAN_MEDICINE_d = 
    {
        name = "Trash",
        icon = "battle/flekfis_junk.tex",
        anim = "taunt",
        flavour = "'…Sorry, I forgot to throw this away. Here, you can have it.'",
        target_type = TARGET_TYPE.SELF,

        rarity = CARD_RARITY.UNIQUE,
        cost = 2,
        max_xp = 0,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.BURNOUT,

        features =
        {
            DEFEND = 3,
        },
    },

    PC_ALAN_MEDICINE_d_upgraded = 
    {
        name = "Heavy Trash",
        icon = "battle/flekfis_junk.tex",
        anim = "taunt",
        target_type = TARGET_TYPE.SELF,

        rarity = CARD_RARITY.UNIQUE,
        cost = 3,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.BURNOUT,

        features =
        {
            DEFEND = 3,
        },
    },

    PC_ALAN_MEDICINE_e = 
    {
        name = "Dust Bomb",
        icon = "battle/gunsmoke.tex",
        anim = "throw",
        flavour = "'I admit, this idea is a bit dumb.'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        features =
        {
            IMPAIR = 1,
        },
    },

    PC_ALAN_MEDICINE_e_upgraded =
    {
        name = "Boosted Dust Bomb",
        icon = "battle/gunsmoke.tex",
        anim = "throw",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,

        features =
        {
            IMPAIR = 2,
        },
    },

    PC_ALAN_MEDICINE_f = 
    {
        name = "Emergency-Use Tidepool Pods",
        icon = "battle/rugs_tidepool_pods.tex",    
        anim = "throw",
        desc = "{PC_ALAN_LIGHTWEIGHT}{1}: deal 3 bonus damage.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.light_thresh)
        end,
        flavour = "'Primarily for emergencies (and just a reminder—it's meant to be thrown, not eaten).'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        min_damage = 3,
        max_damage = 3,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        light_thresh = 3,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost <= self.light_thresh then
                    dmgt:AddDamage(3, 3, self)
                end
            end
        end,
    }

    },

    PC_ALAN_MEDICINE_f_upgraded = 
    {
        name = "Boosted Emergency-Use Tidepool Pods",
        anim = "throw",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        min_damage = 5,
        max_damage = 5,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost <= 3 and max_cost > 0 then
                    dmgt:AddDamage(3, 3, self)
                end
            end
        end,
    }   
    },

    PC_ALAN_MEDICINE_g = 
    {
        name = "Diluted Lumin Grenade",
        icon = "battle/lumin_grenade.tex",
        anim = "throw",
        desc = "Apply {1} {lumin_burnt}.",
        desc_fn = function(self, fmt_str)
        return loc.format(fmt_str, CalculateConditionText(self, "lumin_burnt", self.lumin_burnt_amt))
    end,
        flavour = "'Called a diluted grenade, but really, it’s just Lumin stuffed into a bottle and sealed shut.'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        lumin_burnt_amt = 3,
        OnPostResolve = function(self, battle, attack)
            attack:AddCondition("lumin_burnt", self.lumin_burnt_amt, self)
        end,
    },

    PC_ALAN_MEDICINE_g_upgraded =
    {
        name = "Better Diluted Lumin Grenade",
        icon = "battle/lumin_grenade.tex",
        anim = "throw",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        lumin_burnt_amt = 5,
    },

    PC_ALAN_MEDICINE_h = 
    {
        name = "Spark Mixture",
        icon = "battle/spark_grenade.tex",
        anim = "throw",
        desc = "Gain {1} {SPARK_RESERVE}.\nApply {1} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "SPARK_RESERVE", self.spark_amt))
        end,
        flavour = "'Since it's not tightly bound, a bit of residue on you after throwing is perfectly normal.'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        spark_amt = 1,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("SPARK_RESERVE", self.spark_amt, self)
            if attack and attack.target then
                attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
            end
        end,
    },

    PC_ALAN_MEDICINE_h_upgraded =
    {
        name = "Boosted Spark Mixture",
        icon = "battle/spark_grenade.tex",
        anim = "throw",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        spark_amt = 2,
    },

    PC_ALAN_INERTIAL_IMPACT =
    {
        name = "Inertial Impact",
        icon = "battle/brazen_attack.tex",
        anim = "punch",
        desc = "Gain {1} {DEFEND}.\n{PC_ALAN_WEIGHTED} {2}: Gain 1 Action.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),self.weight_thresh)
        end,  
        flavour = "'A simple use of inertia can send a heavy object flying straight to your face.'",
        rarity = CARD_RARITY.COMMON,
        cost = 2,
        max_xp = 7,        
        action_bonus = 1,
        weight_thresh = 6,
        min_damage = 4,
        max_damage = 8,
        flags = CARD_FLAGS.MELEE,
        defend_amount = 4,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition( "DEFEND", self.defend_amount, self )
        end
    },

    PC_ALAN_INERTIAL_IMPACT_plus =
    {
        name = "Visionary Inertial Impact",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_INERTIAL_IMPACT_plus2 =
    {
        name = "Weighted Inertial Impact",
        desc = "Gain {1} {DEFEND}.\n<#UPGRADE>{PC_ALAN_WEIGHTED} {2}: Gain <#UPGRADE>2 {ADRENALINE}</> and 1 Action</>.",   
        flags = CARD_FLAGS.MELEE,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition( "DEFEND", self.defend_amount, self )
            self.owner:AddCondition( "ADRENALINE", 2, self )
        end
    },

    PC_ALAN_LUMIN_DAGGER =
    {
        name = "Lumin Dagger",
        icon = "battle/makeshift_dagger.tex",
        anim = "punch",
        desc = "Deal 3 bonus damage if you have any {LUMIN_RESERVE}.",
        flavour = "'A simple knife coated with Lumin. The craftsmanship is crude—worse than the daggers used by Luminitiates.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.MELEE,        
        cost = 1,
        max_xp = 9,
        min_damage = 3,
        max_damage = 5,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and self.owner:HasCondition("LUMIN_RESERVE") then
                    dmgt:AddDamage( 3, 3, self )
                end
            end,
        },
    },

    PC_ALAN_LUMIN_DAGGER_plus =
    {
        name = "Boosted Lumin Dagger",
        desc = "deal <#UPGRADE>6</> bonus damage  if you have any {LUMIN_RESERVE}.",
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and self.owner:HasCondition("LUMIN_RESERVE") then
                    dmgt:AddDamage( 6, 6, self )
                end
            end,
        },
    },

    PC_ALAN_LUMIN_DAGGER_plus2 =
    {
        name = "Lumin Dagger of the Mirror",
        desc = "Deal 3 bonus damage and <#UPGRADE>Attack twice.</> if you have any {LUMIN_RESERVE}.",
        min_damage = 1,
        max_damage = 3,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and self.owner:HasCondition("LUMIN_RESERVE") then
                    dmgt:AddDamage( 3, 3, self )
                    self.hit_count = 2
                    return true
                else
                    self.hit_count = 1
                    return false
                end
            end,
        },
    },

    PC_ALAN_SPARK_PROPULSION =
    {
        name = "Spark Propulsion",
        icon = "battle/spark_shot.tex",
        anim = "throw",
        desc = "Spend 1 {SPARK_RESERVE}: This card costs 0.",
        flavour = "'Once you understand the principle, it’s actually quite simple.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 9,
        min_damage = 4,
        max_damage = 4,
        PreReq = function( self, battle, target )
            return self.owner:GetConditionStacks("SPARK_RESERVE") >= 1
        end,

        OnPostResolve = function( self, battle, attack )
            if self.owner:GetConditionStacks("SPARK_RESERVE") >= 1 then
                self.owner:RemoveCondition("SPARK_RESERVE", 1, self)
            end
        end,

        event_priorities =
        {
            [ BATTLE_EVENT.CALC_ACTION_COST ] = EVENT_PRIORITY_SETTOR,
        },

        event_handlers = 
        {
            [ BATTLE_EVENT.CALC_ACTION_COST ] = function( self, cost_acc, card, target )
                if card == self then
                    if self.owner:GetConditionStacks("SPARK_RESERVE") >= 1 then
                        cost_acc:ModifyValue(0, self)
                    end
                end
            end,
        },
    },

    PC_ALAN_SPARK_PROPULSION_plus =
    {
        name = "Rooted Spark Propulsion",
        min_damage = 6,
        max_damage = 6,
    },

    PC_ALAN_SPARK_PROPULSION_plus2 =
    {
        name = "Tall Spark Propulsion",
        max_damage = 8
    },

    PC_ALAN_SPARK_BULLET =
    {
        name = "Spark Bullet",
        icon = "battle/improvise_tracer.tex",
        anim = "throw",
        desc = "Apply {1} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "SPARK_RESERVE", self.spark_amt))
        end,
        flavour = "'Small spark, just the right blast.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 9,
        min_damage = 2,
        max_damage = 4,
        spark_amt = 2,
        OnPostResolve = function(self, battle, attack)
            if attack and attack.target then
                attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
            end
        end,
    },

    PC_ALAN_SPARK_BULLET_plus =
    {
        name = "Boosted Spark Bullet",
        min_damage = 4,
    },

    PC_ALAN_SPARK_BULLET_plus2 =
    {
        name = "Tactless Spark Bullet",
        desc = "Apply <#UPGRADE>{1}</> {SPARK_RESERVE}.\n<#DOWNGRADE>Gain {2} {SPARK_RESERVE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, 
                CalculateConditionText(self, "SPARK_RESERVE", self.target_spark_amt), 
                CalculateConditionText(self, "SPARK_RESERVE", self.self_spark_amt)
                )
        end,
        target_spark_amt = 4,
        self_spark_amt = 2,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("SPARK_RESERVE", self.self_spark_amt, self)
            if attack and attack.target then
                attack.target:AddCondition("SPARK_RESERVE", self.target_spark_amt, self)
            end
        end,
    },

    PC_ALAN_LUMIN_BOMB =
    {
        name = "Lumin Bomb",
        icon = "battle/clear_shot.tex",
        anim = "throw",
        desc = "Apply {1} {lumin_burnt}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "lumin_burnt", self.lumin_burnt_amt))
        end,
        flavour = "'To be honest, it’s filled with lower-quality Lumin.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 9,
        min_damage = 2,
        max_damage = 2,
        lumin_burnt_amt = 3,
        OnPostResolve = function(self, battle, attack)
            attack:AddCondition("lumin_burnt", self.lumin_burnt_amt, self)
        end,
    },

    PC_ALAN_LUMIN_BOMB_plus =
    {
        name = "Boosted Lumin Bomb",
        min_damage = 4,
        max_damage = 4,
    },

    PC_ALAN_LUMIN_BOMB_plus2 =
    {
        name = "Enchanced Lumin Bomb",
        lumin_burnt_amt = 5,
        desc = "Apply <#UPGRADE>{1}</> {lumin_burnt}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "lumin_burnt", self.lumin_burnt_amt))
        end,
    },

    PC_ALAN_BLINDSIDE_TOSS =
    {
        name = "Blindside Toss",
        icon = "battle/rabbit_punch.tex",
        anim = "throw",
        desc = "Spend {1} {SPARK_RESERVE}: This card deals max damage and costs 1 less.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.spark_cost)
        end,
        flavour = "'A simple and effective solution—just be careful not to hit too hard.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 2,
        max_xp = 5,
        min_damage = 1,
        max_damage = 8,
        spark_cost = 2,
        
        PreReq = function( self, battle )
            return self.owner:GetConditionStacks("SPARK_RESERVE") >= 2
        end,

        event_handlers = 
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and (self.spark_spent or self.spark_spent == nil and self.owner:GetConditionStacks("SPARK_RESERVE") >= self.spark_cost) then
                    dmgt:ModifyDamage( dmgt.max_damage, dmgt.max_damage, self )                       
                end
            end,

            [ BATTLE_EVENT.CALC_ACTION_COST ] = function( self, cost_acc, card, target )
                if card == self and (self.spark_spent or self.spark_spent == nil and self.owner:GetConditionStacks("SPARK_RESERVE") >= self.spark_cost) then
                    cost_acc:AddValue(-1)
                end
            end
        },

        OnPreResolve = function( self, battle, attack )
            if self.owner:GetConditionStacks("SPARK_RESERVE") >= self.spark_cost then
                self.owner:RemoveCondition("SPARK_RESERVE", self.spark_cost)
                self.spark_spent = true
            else
                self.spark_spent = false
            end
        end,

        OnPostResolve = function( self, battle, attack)
            self.spark_spent = nil
        end,
    },

    PC_ALAN_BLINDSIDE_TOSS_plus =
    {
        name = "Pale Blindside Toss",
        cost = 1,
    },

    PC_ALAN_BLINDSIDE_TOSS_plus2 =
    {
        name = "Tall Blindside Toss",
        min_damage = 2,
        max_damage = 12,
    },

    PC_ALAN_SPLASH_LUMIN =
    {
        name = "Splash Lumin",
        icon = "battle/reversal.tex",
        anim = "throw",
        desc = "Apply {lumin_burnt} equal to the damage dealt by this card.",
        flavour = "'Throw it and run—the area’s off-limits for a while..'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 2,
        max_xp = 6,
        min_damage = 3,
        max_damage = 6,
        event_handlers = 
        {
            [ BATTLE_EVENT.ON_HIT ] = function( self, battle, attack, hit )
                if hit.card == self and not hit.evaded then
                    hit.target:AddCondition("lumin_burnt", hit.damage or 0, self)
                end
            end
        },
    },

    PC_ALAN_SPLASH_LUMIN_plus =
    {
        name = "Rooted Splash Lumin",
        min_damage = 5,
        max_damage = 5,
    },

    PC_ALAN_SPLASH_LUMIN_plus2 =
    {
        name = "Tall Splash Lumin",
        max_damage = 9,
    },    

    PC_ALAN_TRIP =
    {
        name = "Trip",
        icon = "battle/trip.tex",
        anim = "punch",
        desc = "Apply 1 {WOUND}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "WOUND", self.wou_amt ))
        end,
        flavour = "'Take this!'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 0,
        max_xp = 10,
        min_damage = 2,
        max_damage = 2,
        wou_amt = 1,
        OnPostResolve = function(self, battle, attack)
            attack.target:AddCondition("WOUND", self.wou_amt, self)
        end,
    },

    PC_ALAN_TRIP_plus =
    {
        name = "Lightweight Trip",
        desc = "<#DOWNGRADE>{PC_ALAN_LIGHTWEIGHT}{1}</>: Apply <#UPGRADE>{2}</> {WOUND}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self.light_thresh,self.wou_amt)
        end,
        light_thresh = 3,
        wou_amt = 3,
        OnPostResolve = function(self, battle, attack)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                attack.target:AddCondition("WOUND", self.wou_amt, self)
            end
        end,
    },

    PC_ALAN_TRIP_plus2 =
    {
        name = "Visionary Trip",
        desc = "Apply 1 {WOUND}.\n<#UPGRADE>Draw a card</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "WOUND", self.wou_amt ))
        end,
        OnPostResolve = function( self, battle, attack)
            attack.target:AddCondition("WOUND", self.wou_amt, self)
            battle:DrawCards(1)
        end,
    },

    PC_ALAN_CASUAL_TOSS =
    {
        name = "Casual Toss",
        icon = "battle/throw_rock.tex",
        anim = "throw",
        desc =  "Discard {1} random card from your hand.\nAttack a random enemy.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.discard_count, self.action_gain)
        end,
        flavour = "'Throw whatever you can first!'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        target_mod = TARGET_MOD.RANDOM1,
        cost = 0,
        max_xp = 10,
        min_damage = 6,
        max_damage = 6,
        discard_count = 1,

        OnPostResolve = function( self, battle, attack )
            local cards_to_discard = table.multipick(battle:GetHandDeck().cards, self.discard_count)
            for i,card in ipairs(cards_to_discard) do
                battle:DiscardCard(card)
            end
        end
    },

    PC_ALAN_CASUAL_TOSS_plus =
    {
        name = "Focus Casual Toss",
        desc = "<#UPGRADE>Discard {1} card from your hand</>.",
        target_mod = TARGET_MOD.SINGLE,
        OnPreResolve = function ( self, battle, attack )
            battle:DiscardCards(1, nil, self)
        end,
    },

    PC_ALAN_CASUAL_TOSS_plus2 =
    {
        name = "Tactless Casual Toss",
        desc =  "Discard <#DOWNGRADE>{1}</> random card from your hand.\nAttack a random enemy.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.discard_count, self.action_gain)
        end,
        min_damage = 10,
        max_damage = 10,
        discard_count = 2,
    },

    PC_ALAN_HEAVY_SUPPRESSION =
    {
        name = "Heavy Suppression",
        icon = "battle/boulder_rush.tex",
        anim = "punch",
        desc = "{PC_ALAN_WEIGHTED}{1}: Gain 2 actions.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        flavour = "'A bit of extra weight is fine—as long as it keeps things under control.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 3,
        max_xp = 3,
        min_damage = 7,
        max_damage = 12,
        weight_thresh = 8,
        action_bonus = 2, 
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },


    PC_ALAN_HEAVY_SUPPRESSION_plus =
    {
        name = "Visionary Heavy Suppression",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.REPLENISH
    },

    PC_ALAN_HEAVY_SUPPRESSION_plus2 =
    {
        name = "Weighted Heavy Suppression",
        desc = "{PC_ALAN_WEIGHTED}{1}: <#UPGRADE>Gain 3 {ADRENALINE}</> and 2 actions.",
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
                self.owner:AddCondition("ADRENALINE", 3, self)
            end
        end,
    },

    PC_ALAN_DISRUPTIVE_ATTACK =
    {
        name = "Disruptive Attack",
        icon = "battle/kidney_shot.tex",
        anim = "punch",
        desc = "{PC_ALAN_LIGHTWEIGHT}{1}: Deal 3 bonus damage and lose 1 action.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.light_thresh)
        end,
        flavour = "'Where are you looking?'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 0,
        max_xp = 10,
        min_damage = 3,
        max_damage = 5, 
        light_thresh = 3,
        action_bonus = -1,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost <= self.light_thresh then
                    dmgt:AddDamage(3, 3, self)
                end
            end
        end,
    },
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end
    },

    PC_ALAN_DISRUPTIVE_ATTACK_plus =
    {
        name = "Boosted Disruptive Attack",
        desc = "{PC_ALAN_LIGHTWEIGHT}{1}: Deal <#UPGRADE>5</> bonus damage and lose 1 action.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.light_thresh)
        end,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost <= self.light_thresh then
                    dmgt:AddDamage(5, 5, self)
                end
            end
        end,
    },
        OnPreResolve = function(self, battle)
            local total_cost= CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end
    },

    PC_ALAN_DISRUPTIVE_ATTACK_plus2 =
    {
        name = "Twisted Disruptive Attack",
        desc = "<#DOWNGRADE>{PC_ALAN_WEIGHTED}{1}</>: <#UPGRADE>Gain 2 {ADRENALINE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        weight_thresh = 7,
        action_bonus = 0,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("ADRENALINE", 2, self)
        end,

    },

    PC_ALAN_AIM =
    {
        name = "Aim",
        icon = "battle/crackle.tex",
        anim = "punch",
        desc = "If target have any {SPARK_RESERVE}, Apply {1} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "SPARK_RESERVE", self.spark_amt ))
        end,
        flavour = "'Try aiming at the spots with Sparks—might just set off an explosion.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 9,
        min_damage = 4,
        max_damage = 6, 
        spark_amt = 2,
        OnPostResolve = function(self, battle, attack)
            for i, hit in attack:Hits() do
                local target = hit.target
                if not hit.evaded and target:GetConditionStacks("SPARK_RESERVE") > 0 then 
                attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
            end
        end
    end
    },

    PC_ALAN_AIM_plus =
    {
        name = "Boosted Aim",
        min_damage = 6,
    },

    PC_ALAN_AIM_plus2 =
    {
        name = "Enchanced Aim",
        desc = "If target have any {SPARK_RESERVE}, Apply <#UPGRADE>{1}</> {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "SPARK_RESERVE", self.spark_amt ))
        end,
        spark_amt = 3,
    },

    PC_ALAN_CATALYST =
    {
        name = "Catalyst",
        icon = "battle/affliction.tex",
        anim = "throw",
        desc = "If the target have {lumin_burnt}, Apply {1} {WOUND} and {1} {EXPOSED}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "WOUND", self.wou_amt ),CalculateConditionText( self, "EXPOSED", self.exo_amt ))
        end,
        flavour = "'Lumin, Water of Hesh, and a bit of something from Roaloch—what happens next? Just take a look at this guy.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 9,
        min_damage = 2,
        max_damage = 3,    
        wou_amt = 1,
        exo_amt = 1,
        OnPostResolve = function( self, battle, attack )
            for i, hit in attack:Hits() do
                local target = hit.target
                if not hit.evaded and target:GetConditionStacks("lumin_burnt") > 0 then 
                    target:AddCondition("IMPAIR", self.exo_amt, self)
                    target:AddCondition("WOUND", self.wou_amt, self)
                end
            end
        end
    },

    PC_ALAN_CATALYST_plus =
    {
        name = "Boosted Catalyst",
        min_damage = 4,
        max_damage = 6,
    },

    PC_ALAN_CATALYST_plus2 =
    {
        name = "Enchanced Catalyst",
        desc = "If the target have {lumin_burnt}, Apply <#UPGRADE>{1}</> {WOUND} and <#UPGRADE>{1}</> {EXPOSED}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "WOUND", self.wou_amt ),CalculateConditionText( self, "EXPOSED", self.exo_amt ))
        end,
        wou_amt = 2,
        exo_amt = 2,
    },

    PC_ALAN_STINGER =
    {
        name = "Stinger",
        icon = "battle/flead_larvae_card.tex",
        anim = "throw",
        desc = "Remove all {DEFEND} on target.",
        flavour = "'I raised it myself—too bad it’s not friendly. It only stings freely.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.EXPEND,
        cost = 1,
        max_xp = 7,
        min_damage = 4,
        max_damage = 6,    
        OnPostResolve = function(self, battle, attack)
            if attack and attack.target then
                local target = attack.target
                local defend_stacks = target:GetConditionStacks("DEFEND")
                if defend_stacks > 0 then
                    target:RemoveCondition("DEFEND", defend_stacks, self)
                end
            end
        end
    },

    PC_ALAN_STINGER_plus =
    {
        name = "Sticky Stinger",
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.EXPEND | CARD_FLAGS.STICKY,
    },

    PC_ALAN_STINGER_plus2 =
    {
        name = "Pale Stinger",
        cost = 0,
    },

    PC_ALAN_DOUBLE_FISTS =
    {
        name = "Double Fists",
        icon = "battle/kiss_the_fists.tex",
        anim = "punch",
        desc = "Attack twice.",
        flavour = "'What do you do after throwing one punch? Throw another, of course!'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 2,
        max_xp = 7,
        min_damage = 3,
        max_damage = 6,
        hit_count = 2, 
    },

    PC_ALAN_DOUBLE_FISTS_plus =
    {
        name = "Triple Fists",
        desc = "Attack <#UPGRADE>Three Times</>.",
        min_damage = 2,
        max_damage = 5,
        hit_count = 3,
    },

    PC_ALAN_DOUBLE_FISTS_plus2 =
    {
        name = "Rooted Double Fists",
        min_damage = 6,
    },

    PC_ALAN_LUMIN_INFUSION =
    {
        name = "Lumin Infusion",
        icon = "battle/sals_daggers_bleed.tex",
        anim = "taunt",
        desc = "Gain {1} {LUMIN_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "LUMIN_RESERVE", self.lumin_res_amt ))
        end,
        flavour = "'See this protrusion? You can refill the knife’s Lumin through it.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9,  
        lumin_res_amt = 5,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end,
    },

    PC_ALAN_LUMIN_INFUSION_plus =
    {
        name = "Visionary Lumin Infusion",
        desc = "Gain {1} {LUMIN_RESERVE}.\n<#UPGRADE>Draw a Card</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "LUMIN_RESERVE", self.lumin_res_amt ))
        end,
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(1)
            attack:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end,
    },

    PC_ALAN_LUMIN_INFUSION_plus2 =
    {
        name = "Spark Infusion",
        desc = "<#UPGRADE>Apply {1} {SPARK_RESERVE}</>.\n<#DOWNGRADE>Gain {1} {SPARK_RESERVE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "SPARK_RESERVE", self.spark_amt ))
        end,
        target_type = TARGET_TYPE.ENEMY,
        spark_amt = 3,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("SPARK_RESERVE", self.spark_amt, self)
            self.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
        end,
    },

    PC_ALAN_PLAN =
    {
        name = "Plan",
        icon = "battle/footwork.tex",
        anim = "taunt",
        desc = "{IMPROVISE} a card from your draw pile.",
        flavour = "'Whether it’s an attack route or an escape route, it’s best to plan ahead.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 0,
        max_xp = 10,  
        OnPostResolve = function( self, battle, attack )
            if battle:GetDrawDeck():CountCards() == 0 then
                battle:ShuffleDiscardToDraw()
            end
            local cards = battle:ImproviseCards(table.multipick(battle:GetDrawDeck().cards, 3), 1, "off_hand", nil, nil, self)
        end
    },

    PC_ALAN_PLAN_plus =
    {
        name = "Boosted Plan",
        desc = "<#UPGRADE>{IMPROVISE_PLUS}</> a card from your draw pile.",
        OnPostResolve = function( self, battle, attack )
            if battle:GetDrawDeck():CountCards() == 0 then
                battle:ShuffleDiscardToDraw()
            end
            local cards = battle:ImproviseCards(table.multipick(battle:GetDrawDeck().cards, 5), 1, "off_hand", nil, nil, self)
        end
    },

    PC_ALAN_PLAN_plus2 =
    {
        name = "Plan of Vision",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.REPLENISH
    },

    PC_ALAN_WARM_UP =
    {
        name = "Warm-up",
        icon = "battle/lever.tex",
        anim = "taunt",
        desc = "Gain 3 {ADRENALINE} at the start of your next turn.",
        flavour = "'Can’t help it—that’s just how the old models are. Take it or leave it.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9, 
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("WARM_UP", 3, self) 
        end,
    },

    PC_ALAN_WARM_UP_plus =
    {
        name = "Weighted Warm-up",
        desc = "Gain 3 {ADRENALINE} at the start of your next turn.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Gain a bonus stack at next turn</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        weight_thresh = 6,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.owner:AddCondition("WARM_UP", 1, self)
            end
        end,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("WARM_UP", 3, self) 
        end,
    },

    PC_ALAN_WARM_UP_plus2 =
    {
        name = "Lightweight Warm-up",
        desc = "<#UPGRADE>{PC_ALAN_LIGHTWEIGHT}{1}: Gain 1 {ADRENALINE}</>.\nGain 3 {ADRENALINE} at the start of your next turn.", 
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.light_thresh)
        end,
        light_thresh = 3,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("ADRENALINE", 1, self) 
            self.owner:AddCondition("WARM_UP", 3, self) 
        end,
    },

    PC_ALAN_PLATE_ARMOR =
    {
        name = "Plate Armor",
        icon = "battle/bolstered_plating.tex",
        anim = "taunt",
        desc = "Gain {1} {DEFEND} per card in your hand.\n(Gain {2} {DEFEND}).",
        desc_fn = function(self, fmt_str)
            if self.engine then
                local defend_amount = self:CalcDefend()
                return loc.format(fmt_str, self.defend_amount, defend_amount)
            else
            return loc.format(fmt_str, self.defend_amount, 0) 
            end
        end,
        flavour = "'Freshly stocked plate armor—personally demonstrated by yours truly!'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9, 
        defend_amount = 1,
        CalcDefend = function(self)
            local num_cards = self.engine:GetHandDeck():CountCards()
            return math.floor( num_cards ) * self.defend_amount
        end,

        OnPostResolve = function( self, battle, attack )
             local defend_amount = self:CalcDefend() + self.defend_amount
            self.owner:AddCondition("DEFEND", defend_amount, self)
        end,
    },

    PC_ALAN_PLATE_ARMOR_plus =
    {
        name = "Boosted Plate Armor",
        desc = "Gain <#UPGRADE>{1}</> {DEFEND} per card in your hand.\n(Gain {2} {DEFEND}).",
        defend_amount = 2
    },

    PC_ALAN_PLATE_ARMOR_plus2 =
    {
        name = "Visionary Plate Armor",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_GOODS =
    {
        name = "Goods",
        icon = "battle/packrat.tex",
        anim = "taunt",
        desc = "Apply {1} {DEFEND}.\nThe cost of this card is equal to the cost of the most expensive card in your hand while turn start.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        flavour = "'Freshly stocked plate armor—personally demonstrated by yours truly!'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        cost = 0,
        max_xp = 7, 
        defend_amount = 4,
        event_handlers =
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function(self, battle)
            local max_cost = 0
            for _, hand_card in self.engine:GetHandDeck():Cards() do
                if hand_card ~= self then
                    local cost = hand_card.cost or 0
                    if cost > max_cost then
                    max_cost = cost
                end
            end
            end
            self.fixed_cost = max_cost > 0 and max_cost or 0
            end,
            [ BATTLE_EVENT.CALC_ACTION_COST ] = function(self, cost_acc, card, target)
            if card == self then
            cost_acc:AddValue(self.fixed_cost, self)
            end
            end,
        },
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition( "DEFEND", self.defend_amount, self )
        end
    },

    PC_ALAN_GOODS_plus =
    {
        name = "Conveyor Belt Goods",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_GOODS_plus2 =
    {
        name = "Heavy Goods",
        desc = "Apply <#UPGRADE>{1}</> {DEFEND}.\nThe cost of this card is equal to the cost of the most expensive card in your hand while turn start.",
        cost = 1,
        defend_amount = 8,
    },

    PC_ALAN_SHODDY_SHIELD =
    {
        name = "Shoddy Shield",
        icon = "battle/bouldering_charge.tex",
        anim = "taunt",
        desc = "Gain {1} {DEFEND}. Increase by {2} for each card played this turn.\n({3} cards played).",
        desc_fn = function(self, fmt_str)
            if self.engine then
                local total_defend = self.defend_amount + (self.defend_bonus * self.engine:CountCardsPlayed())
                return loc.format(fmt_str, total_defend, self.defend_bonus, self.engine:CountCardsPlayed())
            else
                return loc.format(fmt_str, self.defend_amount, self.defend_bonus, 0)
            end
        end,
        flavour = "'Far weaker than the real deal, but the low cost makes up for it.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 0,
        max_xp = 10, 
        defend_amount = 0,
        defend_bonus = 1,
        OnPostResolve = function( self, battle, attack)
            self.owner:AddCondition( "DEFEND", self.defend_amount + (self.defend_bonus * self.engine:CountCardsPlayed()), self )
        end,
    },

    PC_ALAN_SHODDY_SHIELD_plus =
    {
        name = "Shoddy Stone Shield",
        desc = "Gain {1} {DEFEND}. Increase by <#UPGRADE>{2}</> for each card played this turn.\n({3} cards played).",
        defend_bonus = 2,
    },

    PC_ALAN_SHODDY_SHIELD_plus2 =
    {
        name = "Shoddy Spiked Shield",
        desc = "Gain {1} {DEFEND} and <#UPGRADE>{1} {RIPOSTE}</> . Increase by {2} for each card played this turn.\n({3} cards played).",
        desc_fn = function(self, fmt_str)
            if self.engine then
                local total_defend = self.defend_amount + (self.defend_bonus * self.engine:CountCardsPlayed())
                return loc.format(fmt_str, total_defend, self.defend_bonus, self.engine:CountCardsPlayed())
            else
                return loc.format(fmt_str, self.defend_amount, self.defend_bonus, 0)
            end
        end,
        OnPostResolve = function( self, battle, attack)
            self.owner:AddCondition( "DEFEND", self.defend_amount + (self.defend_bonus * self.engine:CountCardsPlayed()), self )
            self.owner:AddCondition( "RIPOSTE", self.defend_amount + (self.defend_bonus * self.engine:CountCardsPlayed()), self )
        end,
    },

    PC_ALAN_COUNTER =
    {
        name = "Counter",
        icon = "battle/rebound.tex",
        anim = "taunt",
        desc = "Gain {1} {DEFEND} and {2} {RIPOSTE}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ), self.riposte_amount)
        end,
        flavour = "'I’m not just gonna stand here and take the hit.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9, 
        defend_amount = 4,
        riposte_amount = 3,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("DEFEND", self.defend_amount, self)
            self.owner:AddCondition("RIPOSTE", self.riposte_amount, self)
        end  
    },

    PC_ALAN_COUNTER_plus =
    {
        name = "Stone Counter",
        desc = "Gain <#UPGRADE>{1}</> {DEFEND} and {2} {RIPOSTE}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ), self.riposte_amount)
        end,
        defend_amount = 7,
    },

    PC_ALAN_COUNTER_plus2 =
    {
        name = "Spined Counter",
        desc = "Gain {1} {DEFEND} and <#UPGRADE>{2}</> {RIPOSTE}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ), self.riposte_amount)
        end,
        riposte_amount = 6,
    },

    PC_ALAN_THROWING_KNIVES =
    {
        name = "Throwing Knives",
        icon = "battle/daggerstorm.tex",
        anim = "taunt",
        desc = "Insert {1} {PC_ALAN_QUICK_THROW} into your hand.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.num_cards)
        end,
        flavour = "'Remember to retrieve them after the fight.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9,  
        num_cards = 2,
        OnPostResolve = function( self, battle, attack)
            local cards = {}
            for i = 1, self.num_cards do
                local incepted_card = Battle.Card( "PC_ALAN_QUICK_THROW", self:GetOwner() )
                incepted_card.auto_deal = true
                table.insert( cards, incepted_card )
            end
            battle:DealCards( cards , battle:GetHandDeck() )
        end,
    },

    PC_ALAN_THROWING_KNIVES_plus =
    {
        name = "Pale Throwing Knives",
        desc = "Insert <#DOWNGRADE>{1}</> {PC_ALAN_QUICK_THROW} into your hand.",
        cost = 0,
        num_cards = 1,
    },

    PC_ALAN_THROWING_KNIVES_plus2 =
    {
        name = "Throwing Knives Behind Stone",
        desc = "Insert {1} {PC_ALAN_QUICK_THROW} into your hand.\n<#UPGRADE>Gain {2} {DEFEND}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.num_cards, self:CalculateDefendText( self.defend_amount ))
        end,
        defend_amount = 5,
        OnPostResolve = function( self, battle, attack)
            local cards = {}
            for i = 1, self.num_cards do
                local incepted_card = Battle.Card( "PC_ALAN_QUICK_THROW", self:GetOwner() )
                incepted_card.auto_deal = true
                table.insert( cards, incepted_card )
            end
            battle:DealCards( cards , battle:GetHandDeck() )
            self.owner:AddCondition("DEFEND", self.defend_amount, self)
        end,
    },

    PC_ALAN_QUICK_THROW =
    {
        name = "Quick Throw",
        icon = "battle/blade_flash.tex",
        anim = "taunt",
        desc = "Increase the damage of all cards with the same name by 1 for this combat.",
        flavour = "One Slash, Two Slashes, Three Slashes.",
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.EXPEND,
        cost = 0,
        min_damage = 3,
        max_damage = 5,
        quick_amt = 1,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function(self, card, target, dmgt)
            if card == self then
                local pc_alan_quick = self.owner:GetCondition("PC_ALAN_QUICK")
                if pc_alan_quick then
                    dmgt:AddDamage(pc_alan_quick.stacks, pc_alan_quick.stacks, self)
                end
            end
            end
        },
        OnPostResolve = function( self, battle, attack)
            self.owner:AddCondition("PC_ALAN_QUICK", self.quick_amt, self)
        end,
    },


    PC_ALAN_BE_PREPARED =
    {
        name = "Be Prepared",
        icon = "battle/tracer.tex",
        anim = "taunt",
        desc = "Apply {1} {tracer}",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.tracer_amt)
        end,
        flavour = "'Don't focus solely on attacking—leave yourself a way out.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.ENEMY,
        cost = 1,
        max_xp = 9, 
        tracer_amt = 1,
        OnPostResolve = function( self, battle, attack )
            local con = attack:AddCondition("tracer", self.tracer_amt, self)
            if con then
                con.applier = self.owner
            end
        end,
    },

    PC_ALAN_BE_PREPARED_plus =
    {
        name = "Boosted Be Prepared",
        desc = "Apply <#UPGRADE>{1}</> {tracer}",
        tracer_amt = 2,
    },

    PC_ALAN_BE_PREPARED_plus2 =
    {
        name = "Pale Be Prepared",
        cost = 0,
    },

    PC_ALAN_BACKUP_WEAPON =
    {
        name = "Backup Weapon",
        icon = "battle/spare_blades.tex",
        anim = "taunt",
        desc = "Draw 3 cards.",
        flavour = "'Always good to have a fallback.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9, 
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(3)
        end,
    },

    PC_ALAN_BACKUP_WEAPON_plus =
    {
        name = "Lightweight Backup Weapon",
        desc = "Draw 3 cards.\n<#UPGRADE>{PC_ALAN_LIGHTWEIGHT}{1}: Draw 1 bonus cards</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.light_thresh)
        end,
        light_thresh = 3,
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(3)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                battle:DrawCards(1)
            end
        end
    },

    PC_ALAN_BACKUP_WEAPON_plus2 =
    {
        name = "Weighted Backup Weapon",
        desc = "Draw 3 cards.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Gain 1 Action</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        weight_thresh = 6,
        action_bonus = 1,
        OnPreResolve = function( self, battle, attack)
            battle:DrawCards(3)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end
    },

    PC_ALAN_CLEANUP =
    {
        name = "Clean up",
        icon = "battle/clean_house.tex",
        anim = "taunt",
        desc = "Discard 2 cards.\nDraw 2 cards.",
        flavour = "'Some things need to be dealt with quickly.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        cost = 0,
        max_xp = 8, 
        OnPostResolve = function( self, battle, attack )
            battle:DiscardCards(2, nil, self)
            battle:DrawCards(2)
        end
    },

    PC_ALAN_CLEANUP_plus =
    {
        name = "Clean up the stone",
        desc = "<#UPGRADE>Gain {1} {DEFEND}</>.\nDiscard 2 cards.\nDraw 2 cards.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        defend_amount = 4,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("DEFEND", self.defend_amount, self)
            battle:DiscardCards(2, nil, self)
            battle:DrawCards(2)
        end
    },

    PC_ALAN_CLEANUP_plus2 =
    {
        name = "Clean all",
        desc = "<#UPGRADE>Discard your hand</>.\n<#UPGRADE>Draw 3 cards</>.",
        OnPostResolve = function( self, battle, attack )
            local tbl = ObtainWorkTable()
            for i, card in battle:GetHandDeck():Cards() do
                table.insert(tbl, card)
            end

            for i, card in ipairs(tbl) do
                battle:DiscardCard(card)
            end

            ReleaseWorkTable(tbl)
            battle:DrawCards(3)
        end
    },

    PC_ALAN_SEIZE_THE_INITIATIVE =
    {
        name = "Seize the Initiative",
        icon = "battle/haste.tex",
        anim = "taunt",
        desc = "Gain 2 actions at next turn.",
        flavour = "'Some things need to be dealt with quickly.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9, 
        OnPostResolve = function( self, battle, attack)
            self.owner:AddCondition("NEXT_TURN_ACTION_ALAN",2 , self)
        end,
    },

    PC_ALAN_SEIZE_THE_INITIATIVE_plus =
    {
        name = "Seize the Important Initiative",
        desc = "Gain 2 actions at next turn.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Gain 1 bonus action at next turn</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        weight_thresh = 7,
        OnPostResolve = function( self, battle, attack)
            self.owner:AddCondition("NEXT_TURN_ACTION_ALAN",1 , self)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then

            end
        end,
    },

    PC_ALAN_SEIZE_THE_INITIATIVE_plus2 =
    {
        name = "Seize more Initiative",
        desc = "Gain 2 actions and <#UPGRADE>draw a card</> at next turn.",
        OnPostResolve = function( self, battle, attack)
            self.owner:AddCondition("NEXT_TURN_ACTION_ALAN",2 , self)
            self.owner:AddCondition("NEXT_TURN_CARD_ALAN",1 , self)
        end,
    },

    PC_ALAN_EXPLOSIVE_CARGO =
    {
        name = "Explosive Cargo",
        icon = "battle/suitcase_grenades.tex",
        anim = "taunt",
        desc = "Apply {1} {DEFEND} and {2} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),CalculateConditionText(self, "SPARK_RESERVE", self.spark_amt))
        end,  
        flavour = "'It’s packed with Sparks—handle with care.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        cost = 1,
        max_xp = 9, 
        defend_amount = 6,
        spark_amt = 2,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("DEFEND", self.defend_amount, self)
            self.owner:AddCondition("SPARK_RESERVE", self.spark_amt, self)
        end,
    },

    PC_ALAN_EXPLOSIVE_CARGO_plus =
    {
        name = "Softened Explosive Cargo",
        desc = "Apply {1} {DEFEND} and <#UPGRADE>{2}</> {SPARK_RESERVE}.",
        spark_amt = 1,
    },

    PC_ALAN_EXPLOSIVE_CARGO_plus2 =
    {
        name = "Heavy Explosive Cargo",
        desc = "Apply <#UPGRADE>{1}</> {DEFEND} and {2} {SPARK_RESERVE}.",
        cost = 2,
        defend_amount = 12,
    },

    PC_ALAN_RAPID_THROW =
    {
        name = "Rapid Throw",
        icon = "battle/dagger_throw.tex",
        anim = "throw",
        desc = "{PC_ALAN_LIGHTWEIGHT}{1}: Deals double damages.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.light_thresh)
        end,
        flavour = "'The faster you throw, the harder it hits.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 0,
        max_xp = 10,
        min_damage = 4,
        max_damage = 4,   
        light_thresh = 2,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                dmgt:AddDamage(dmgt.min_damage, dmgt.max_damage, self)
            end
            end
            end 
        },    
    },

    PC_ALAN_RAPID_THROW_plus =
    {
        name = "Boosted Rapid Throw",
        desc = "{PC_ALAN_LIGHTWEIGHT}{1}: Deals <#UPGRADE>triple</> damages.",
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                dmgt:AddDamage(dmgt.min_damage * 2, dmgt.max_damage * 2, self)
            end
            end
            end 
        }  
    },

    PC_ALAN_RAPID_THROW_plus2 =
    {
        name = "Mirror Rapid Throw",
        desc = "{PC_ALAN_LIGHTWEIGHT}{1}: <#UPGRADE>Attack twice</>.",
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                self.hit_count = 2
                return true
            else
                self.hit_count = 1
                return false
            end
            end
            end 
        } 
    },

    PC_ALAN_SPARK_LAUNCHER =
    {
        name = "Spark Launcher",
        icon = "battle/mantle.tex",
        anim = "throw",
        desc = "Hits all enemies and apply {1} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "SPARK_RESERVE", self.spark_amt))
        end,
        flavour = "'This lets you throw more at once—just don’t overdo it, or things might go wrong.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.RANGED,
        target_mod = TARGET_MOD.TEAM,
        cost = 2,
        max_xp = 7,
        min_damage = 3,
        max_damage = 3,   
        spark_amt = 3,
        OnPostResolve = function( self, battle, attack )
                attack:AddCondition("SPARK_RESERVE", self.spark_amt, self)
            end
    },

    PC_ALAN_SPARK_LAUNCHER_plus =
    {
        name = "Boosted Spark Launcher",
        min_damage = 6,
        max_damage = 6
    },

    PC_ALAN_SPARK_LAUNCHER_plus2 =
    {
        name = "Tactless Spark Launcher",
        desc = "Hits all enemies and apply <#UPGRADE>{1}</> {SPARK_RESERVE}.\n<#DOWNGRADE>Gain {2} {SPARK_RESERVE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "SPARK_RESERVE", self.target_spark_amt), CalculateConditionText(self, "SPARK_RESERVE", self.self_spark_amt))
        end,
        target_spark_amt = 5,
        self_spark_amt = 3,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("SPARK_RESERVE", self.self_spark_amt, self)
            attack:AddCondition("SPARK_RESERVE", self.target_spark_amt, self)
        end
    },
    
    PC_ALAN_SPARK_STORM =
    {
        name = "Spark Storm",
        icon = "battle/firestorm.tex",
        anim = "throw",
        desc = "Spend all {SPARK_RESERVE}: Attack one for each two {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "SPARK_RESERVE", self.spark_amt))
        end,
        flavour = "'Ready to enjoy some fireworks? The Spark-made kind.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 9,
        min_damage = 3,
        max_damage = 5,   
        PreReq = function( self, minigame )
            local stack_count = self.owner:GetConditionStacks("SPARK_RESERVE") or 0 
            local count = math.min(stack_count, 9) 
            if count > 0 then
                self.hit_count = 1 + (count/2)
            else
                self.hit_count = 1
            end
            return stack_count > 0 
        end,
        OnPostResolve = function( self, battle, attack )
            self.hit_count = 1
        end,
    },

    PC_ALAN_SPARK_STORM_plus =
    {
        name = "Rooted Spark Storm",
        min_damage = 5,
        max_damage = 5,
    },

    PC_ALAN_SPARK_STORM_plus2 =
    {
        name = "Tall Spark Storm",
        max_damage = 8,
    },

    PC_ALAN_SWEEPING_STRIKE =
    {
        name = "Sweeping Strike",
        icon = "battle/target_practice.tex",
        anim = "throw",
        desc = "Hits all enemies.",
        flavour = "'This lets you throw more at once—just don’t overdo it, or things might go wrong.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        target_mod = TARGET_MOD.TEAM,
        cost = 3,
        max_xp = 3,
        min_damage = 8,
        max_damage = 12,   
    },

    PC_ALAN_SWEEPING_STRIKE_plus =
    {
        name = "Pale Sweeping Strike",
        cost = 1,
        min_damage = 4,
        max_damage = 7,
    },

    PC_ALAN_SWEEPING_STRIKE_plus2 =
    {
        name = "Weighted Sweeping Strike",
        desc = "Hits all enemies.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Gain 2 Actions</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        weight_thresh = 8,
        action_bonus = 2,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_REPEATED_PUNCHES =
    {
        name = "Repeated Punches",
        icon = "battle/knuckle_down.tex",
        anim = "punch",
        desc = "Attack bonus time equal to the cost of the most expensive card in your hand.",
        flavour = "'Come on, say hello to my fists!'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 1,
        max_xp = 9,
        min_damage = 4,
        max_damage = 6,
        PreReq = function( self, minigame )
            local _, max_cost = CalculateTotalAndMaxCost(self.engine, self) 
            if max_cost >= 0 then
                self.hit_count = 1 + max_cost 
            else
                self.hit_count = 1
            end
            return max_cost >= 0 
        end,
        OnPostResolve = function( self, battle, attack )
            self.hit_count = 1
        end,
    },

    PC_ALAN_REPEATED_PUNCHES_plus =
    {
        name = "Boosted Repeated Punches",
        desc = "Attack bonus time equal to the cost of the most expensive card in your hand.\n<#UPGRADE>Deal bonus damage equal to the cost of the most expensive card in your hand</>.",
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function(self, card, target, dmgt)
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                    local extra_damage = max_cost
                    dmgt:AddDamage(extra_damage, extra_damage, self)
                end
            end
        },
    },

    PC_ALAN_REPEATED_PUNCHES_plus2 =
    {
        name = "Lucid Repeated Punches",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.EXPEND,
        min_damage = 8,
        max_damage = 10,
    },

    PC_ALAN_HAMMER_SWING =
    {
        name = "Hammer Swing",
        icon = "battle/hammer_swing.tex",
        anim = "punch",
        desc = "{PC_ALAN_WEIGHTED}{1}: Gain 2 Actions.\n{CHAIN}{PC_ALAN_HAMMER_SWING_II|}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        flavour = "The beginning is always the hardest, but after that, you’re in trouble.",
        cost = 3,
        flags = CARD_FLAGS.MELEE,
        rarity = CARD_RARITY.UNCOMMON,
        min_damage = 4,
        max_damage = 4,
        weight_thresh = 8,
        action_bonus = 2,
        OnPreResolve = function(self, battle)
        local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
        if total_cost >= self.weight_thresh then
            self.engine:ModifyActionCount(self.action_bonus)
        end
        end,
        OnPostResolve = function( self, battle, attack )
            local card = Battle.Card("PC_ALAN_HAMMER_SWING_II", self.owner)
            card.base_card = self
            card.auto_deal = true
            battle:DealCard(card, battle:GetDrawDeck())
            self:TransferCard( battle.trash_deck )
        end,
    },

    PC_ALAN_HAMMER_SWING_II =
    {
        name = "Hammer Swing II",
        icon = "battle/hammer_swing.tex",
        anim = "punch",
        desc = "{PC_ALAN_WEIGHTED}{1}: Gain 2 Actions.\n{CHAIN}{PC_ALAN_HAMMER_SWING_III|}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        hide_in_cardex = true,
        cost = 2,
        flags = CARD_FLAGS.MELEE,
        rarity = CARD_RARITY.UNIQUE,
        min_damage = 6,
        max_damage = 6,
        action_bonus = 1,
        weight_thresh = 7,
        OnPreResolve = function(self, battle)
        local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
        if total_cost >= self.weight_thresh then
            self.engine:ModifyActionCount(self.action_bonus)
        end
        end,
        OnPostResolve = function( self, battle, attack )
            local card = Battle.Card("PC_ALAN_HAMMER_SWING_III", self.owner)
            card.base_card = self.base_card
            card.auto_deal = true
            battle:DealCard(card, battle:GetDrawDeck())
            self:TransferCard( battle.trash_deck )
        end,
        deck_handlers = { DECK_TYPE.DISCARDS },
        event_handlers =
        {
            [ BATTLE_EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self and target_deck and target_deck:GetDeckType() == DECK_TYPE.DISCARDS then
                    local idx = self.engine:GetDrawDeck():CountCards() > 1 and math.random( self.engine:GetDrawDeck():CountCards() ) or 1
                    if self.base_card then self.base_card:TransferCard(self.engine:GetDrawDeck(), idx) end
                    self:TransferCard( self.engine.trash_deck )
                end
            end
        }
    },

    PC_ALAN_HAMMER_SWING_III =
    {
        name = "Hammer Swing III",
        icon = "battle/hammer_swing.tex",
        anim = "punch",
        desc = "{PC_ALAN_WEIGHTED}{1}: Draw a card.\n{CHAIN}{PC_ALAN_HAMMER_SWING_IV|}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        hide_in_cardex = true,
        cost = 1,
        flags = CARD_FLAGS.MELEE,
        rarity = CARD_RARITY.UNIQUE,
        min_damage = 8,
        max_damage = 8,
        weight_thresh = 6,
        OnPostResolve = function( self, battle, attack )
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                battle:DrawCards(1)
            end
            local card = Battle.Card("PC_ALAN_HAMMER_SWING_IV", self.owner)
            card.base_card = self.base_card
            card.auto_deal = true
            battle:DealCard(card, battle:GetDrawDeck())
            self:TransferCard( battle.trash_deck )
        end,
        deck_handlers = { DECK_TYPE.DISCARDS },
        event_handlers =
        {
            [ BATTLE_EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self and target_deck and target_deck:GetDeckType() == DECK_TYPE.DISCARDS then
                    local idx = self.engine:GetDrawDeck():CountCards() > 1 and math.random( self.engine:GetDrawDeck():CountCards() ) or 1
                    if self.base_card then self.base_card:TransferCard(self.engine:GetDrawDeck(), idx) end
                    self:TransferCard( self.engine.trash_deck )
                end
            end
        }
    },

    PC_ALAN_HAMMER_SWING_IV =
    {
        name = "Hammer Swing IV",
        icon = "battle/hammer_swing.tex",
        anim = "punch",
        hit_anim = true,
        desc = "{PC_ALAN_WEIGHTED}{1}: Draw a card.\n{CHAIN}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        hide_in_cardex = true,
        cost = 0,
        flags = CARD_FLAGS.MELEE,
        rarity = CARD_RARITY.UNIQUE,
        min_damage = 10,
        max_damage = 10,
        weight_thresh = 5,
        deck_handlers = { DECK_TYPE.DISCARDS },
        event_handlers =
        {
            [ BATTLE_EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self and target_deck and target_deck:GetDeckType() == DECK_TYPE.DISCARDS then
                    if source_deck and source_deck:GetDeckType() == DECK_TYPE.RESOLVE then
                        local idx = self.engine:GetDrawDeck():CountCards() > 1 and math.random( self.engine:GetDrawDeck():CountCards() ) or 1
                        self:TransferCard(self.engine:GetDrawDeck(), idx)
                    else
                        local idx = self.engine:GetDrawDeck():CountCards() > 1 and math.random( self.engine:GetDrawDeck():CountCards() ) or 1
                        if self.base_card then self.base_card:TransferCard(self.engine:GetDrawDeck(), idx) end
                        self:TransferCard( self.engine.trash_deck )
                    end
                end
            end
        },
        OnPostResolve = function( self, battle, attack )
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                battle:DrawCards(1)
            end
        end
    },

    PC_ALAN_FINALE =
    {
        name = "Finale",
        icon = "battle/body_blow.tex",
        anim = "punch",
        desc = "Deal {1} bonus damage for each cards played this turn.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.bonus_damage)
        end,
        flavour = "'Thanks for going down so cooperatively.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 0,
        max_xp = 10,
        min_damage = 0,
        max_damage = 0,   
        bonus_damage = 2,
        event_handlers = 
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
            local total_damage = self.bonus_damage * self.engine:CountCardsPlayed()
            dmgt:AddDamage(total_damage, total_damage, self)
            end
            end
        },
    },

    PC_ALAN_FINALE_plus =
    {
        name = "Boosted Finale",
        min_damage = 6,
        max_damage = 6,
    },

    PC_ALAN_FINALE_plus2 =
    {
        name = "Grand Finale",
        desc = "If this is the only card in your hand, deal 4 bonus damage\nIncrease by <#UPGRADE>{1}</> for each card played this turn.\n({2} cards played).",
        bonus_damage = 5,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.EXPEND,
    },

    PC_ALAN_DIRTY_TACTICS =
    {
        name = "Dirty Tactics",
        icon = "battle/shortcut.tex",
        anim = "punch",
        desc = "Apply {1} {WOUND}, {1} {IMPAIR} and {1} {EXPOSED}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.dirty_amt )
        end,
        flavour = "'Well, if you’re taking it this far, I’ll just have to play along.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.EXPEND,
        cost = 0,
        max_xp = 10,
        min_damage = 3,
        max_damage = 3,   
        dirty_amt = 1,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("WOUND", self.dirty_amt, self)
            attack:AddCondition("IMPAIR", self.dirty_amt, self)
            attack:AddCondition("EXPOSED", self.dirty_amt, self)
        end
    },

    PC_ALAN_DIRTY_TACTICS_plus =
    {
        name = "Boosted Dirty Tactics",
        desc = "Apply <#UPGRADE>{1}</> {WOUND}, <#UPGRADE>{1}</> {IMPAIR} and <#UPGRADE>{1}</> {EXPOSED}.",
        dirty_amt = 2,
    },

    PC_ALAN_DIRTY_TACTICS_plus2 =
    {
        name = "Visionary Dirty Tactics",
        desc = "Apply {1} {WOUND}, {IMPAIR} and {EXPOSED}.\n<#UPGRADE>Draw a card</>.",
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("WOUND", self.dirty_amt, self)
            attack:AddCondition("IMPAIR", self.dirty_amt, self)
            attack:AddCondition("EXPOSED", self.dirty_amt, self)
            battle:DrawCards(1)
        end
    },

    PC_ALAN_LUMIN_DARTS =
    {
        name = "Lumin Darts",
        icon = "battle/lumin_darts.tex",
        anim = "throw",
        desc = "This card deal bonus damage equal to your {LUMIN_RESERVE}.",
        flavour = "'The second-hand products from the Cult of Hesh. Its supply stability mainly depends on the Zealots' aim—or the number of guards watching the warehouse.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 9,
        min_damage = 4,
        max_damage = 6,   
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local lumin_reserve = self.owner:GetCondition("LUMIN_RESERVE")
                if lumin_reserve then
                    dmgt:AddDamage(lumin_reserve.stacks, lumin_reserve.stacks, self)
                end
            end
        end
        },
    },

    PC_ALAN_LUMIN_DARTS_plus =
    {
        name = "Boosted Lumin Darts",
        min_damage = 7,
        max_damage = 9,
    },

    PC_ALAN_LUMIN_DARTS_plus2 = 
    {
        name = "Continuous Lumin Darts",
        desc = "This card deal bonus damage equal to your {LUMIN_RESERVE}.\n<#UPGRADE>Gain {1} {LUMIN_RESERVE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "LUMIN_RESERVE", self.lumin_res_amt ))
        end,
        lumin_res_amt = 5,
        OnPostResolve = function( self, battle, attack)
            self.owner:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end,
    },

    PC_ALAN_SUDDEN_STRIKE =
    {
        name = "Sudden Strike",
        icon = "battle/direct_hit.tex",
        anim = "throw",
        desc = "Increase 1 cost for each card played this turn.",
        flavour = "'Sometimes, you need to remind your enemies what you’ve got.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 0,
        max_xp = 10,
        min_damage = 6,
        max_damage = 6,   
        event_handlers = 
        {
            [ BATTLE_EVENT.CALC_ACTION_COST ] = function(self, cost_acc, card, target)
            if card == self then
                self.discount = self.engine:CountCardsPlayed() or 0
                cost_acc:AddValue(self.discount, self) 
            end
            end,

            [ BATTLE_EVENT.END_TURN ] = function(self, fighter)
            self.discount = 0
            end 
        },
    },

    PC_ALAN_SUDDEN_STRIKE_plus =
    {
        name = "Boosted Sudden Strike",
        min_damage = 10,
        max_damage = 10,
    },

    PC_ALAN_SUDDEN_STRIKE_plus2 =
    {
        name = "Twisted Sudden Strike",
        desc = "<#UPGRADE>Attack a random enemy\nEvoke: Play 4 Attack cards in a single turn</>.",
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.UNPLAYABLE,
        min_damage = 10,
        max_damage = 10,
        target_mod = TARGET_MOD.RANDOM1,
        melee_ranged_count = 0,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        event_handlers = 
        {
            [ BATTLE_EVENT.POST_RESOLVE ] = function(self, battle, card)
            if self.triggered_this_turn then
                return
            end
            if card.owner == self.owner then
                if CheckBits(card.flags, CARD_FLAGS.MELEE) or CheckBits(card.flags, CARD_FLAGS.RANGED) then
                    self.melee_ranged_count = self.melee_ranged_count + 1
                end
            end
            if self.melee_ranged_count >= 4 then
                self:ClearFlags(CARD_FLAGS.UNPLAYABLE)
                battle:PlayCard(self, self.owner)
                self:SetFlags(CARD_FLAGS.UNPLAYABLE)
                self.triggered_this_turn = true 
            end
            end,

            [ BATTLE_EVENT.END_TURN ] = function(self, battle, fighter)
            self.melee_ranged_count = 0
            self.triggered_this_turn = false
            end
        },
    },

    PC_ALAN_REACT_AGAIN =
    {
        name = "React Again",
        icon = "battle/current.tex",
        anim = "throw",
        desc = "If the target have {lumin_burnt}, Apply {1} {DEFEND}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ))
        end,  
        flavour = "'Well, let’s go for another round.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 9,
        min_damage = 3,
        max_damage = 5,   
        defend_amount = 3,
        OnPostResolve = function(self, battle, attack)
            for i, hit in attack:Hits() do
                local target = hit.target
                if not hit.evaded and target:GetConditionStacks("lumin_burnt") > 0 then 
                    attack.target:AddCondition("DEFEND", self.defend_amount, self)
                end
            end
        end,
    },

    PC_ALAN_REACT_AGAIN_plus =
    {
        name = "Weighted React Again",
        desc = "If the target have {lumin_burnt}, Apply {1} {DEFEND}.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{2}: Gain 1 action</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ), self.weight_thresh)
        end, 
        weight_thresh = 5,
        action_bonus = 1,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_REACT_AGAIN_plus2 =
    {
        name = "Visionary React Again",
        desc = "If the target have {lumin_burnt}, Apply {1} {DEFEND}.\n<#UPGRADE>Draw a card</>.",
        OnPostResolve = function(self, battle, attack)
            for i, hit in attack:Hits() do
                local target = hit.target
                if not hit.evaded and target:GetConditionStacks("lumin_burnt") > 0 then 
                    attack.target:AddCondition("DEFEND", self.defend_amount, self)
                end
            end
            battle:DrawCards(1)
        end,
    },

    PC_ALAN_DEEP_CUT =
    {
        name = "Deep Cut",
        icon = "battle/gash.tex",
        anim = "punch",
        desc = "This card deal bonus damage equal to target's {lumin_burnt}.",
        flavour = "'Not my problem to cover the medical bills.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 1,
        max_xp = 9,
        min_damage = 2,
        max_damage = 2,   
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self and target then
                local lumin_burnt = target:GetCondition("lumin_burnt")
                local bonus_damage = lumin_burnt and lumin_burnt.stacks or 0
                dmgt:AddDamage(bonus_damage, bonus_damage, self)
                end
            end
        },
    },

    PC_ALAN_DEEP_CUT_plus =
    {
        name = "Double Deep Cut",
        desc = "This card deal bonus damage equal to target's {lumin_burnt}.\n<#UPGRADE>Attack twice</>.",
        cost = 2,
        hit_count = 2,
    },

    PC_ALAN_DEEP_CUT_plus2 =
    {
        name = "Boosted Deep Cut",
        min_damage = 5,
        max_damage = 5,
    },

    PC_ALAN_FREIGHTER =
    {
        name = "Freighter",
        icon = "battle/freighter.tex",
        anim = "punch",
        desc = "Deal bonus damage equal to twice the total cost of all cards at your hand.",
        flavour = "'Just charge in like a runaway freighter.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.REPLENISH,
        cost = 2,
        max_xp = 7,
        min_damage = 3,
        max_damage = 3, 
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card then
                    local cost = CalculateTotalAndMaxCost(self.engine, self) * 2
                    dmgt:AddDamage( cost, cost, self )
                end
            end,
        },        
    },

    PC_ALAN_FREIGHTER_plus =
    {
        name = "Weighted Freighter",
        desc = "Deal bonus damage equal to twice the total cost of all cards at your hand.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Gain 1 Action</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self.weight_thresh)
        end, 
        weight_thresh = 7,
        action_bonus = 1,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_FREIGHTER_plus2 =
    {
        name = "Pale Freighter",
        desc = "Deal bonus damage <#DOWNGRADE>equal to</> the total cost of all cards at your hand.",
        cost = 1,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card then
                    local cost = CalculateTotalAndMaxCost(self.engine, self) 
                    dmgt:AddDamage( cost, cost, self )
                end
            end,
        },  
    },

    PC_ALAN_RECKLESS_SWING =
    {
        name = "Reckless Swing",
        icon = "battle/over_extension.tex",
        anim = "punch",
        desc = "Gain {1} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "SPARK_RESERVE", self.spark_amt ))
        end,
        flavour = "'Doesn’t look like that thing’s aiming at me anyway.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 1,
        max_xp = 9,
        min_damage = 8,
        max_damage = 10, 
        spark_amt = 4,
        OnPostResolve = function( self, battle, attack)
            self.owner:AddCondition("SPARK_RESERVE", spark_amt, self)
        end,
    },

    PC_ALAN_RECKLESS_SWING_plus =
    {
        name = "Boosted Reckless Swing",
        min_damage = 11,
        max_damage = 13,
    },

    PC_ALAN_RECKLESS_SWING_plus2 =
    {
        name = "Wide Reckless Swing",
        desc = "<#UPGRADE>Attack all enemies</>.\nGain {1} {SPARK_RESERVE}.",
        target_mod = TARGET_MOD.TEAM,
        min_damage = 7,
        max_damage = 9,
    },

    PC_ALAN_SIGNATURE_UPPERCUT =
    {
        name = "Signature Uppercut",
        icon = "battle/uppercut.tex",
        anim = "punch",
        desc = "Only can use while doesn’t have others attack card on hand.",
        flavour = "'Don't ask why I'm throwing an uppercut while holding a dagger.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 2,
        max_xp = 7,
        min_damage = 11,
        max_damage = 14,
        loc_strings =
        {
            NO_INJURIES = "Cannot play with any other attack cards in hand",
        }, 
        CanPlayCard = function(self, battle, card)
            for _, hand_card in battle:GetHandDeck():Cards() do
                if hand_card ~= self and (CheckBits(hand_card.flags, CARD_FLAGS.MELEE) or CheckBits(hand_card.flags, CARD_FLAGS.RANGED)) then
                        return false, self.def:GetLocalizedString("NO_INJURIES")
                    end
                end
                return true
            end
    },

    PC_ALAN_SIGNATURE_UPPERCUT_plus =
    {
        name = "Boosted Signature Uppercut",
        min_damage = 14,
        max_damage = 17,
    },

    PC_ALAN_SIGNATURE_UPPERCUT_plus2 =
    {
        name = "Famous Uppercut",
        desc = "\nOnly can use while doesn’t have <#DOWNGRADE>others card</> on hand.",
        min_damage = 22,
        max_damage = 28,
        loc_strings =
        {
            NO_INJURIES_1 = "Cannot play with any other cards in hand",
        }, 
        CanPlayCard = function(self, battle, card)
            local count = self.engine:GetHandDeck():CountCards()
            if self.deck and ((count == 1 and self.deck:GetDeckType() == DECK_TYPE.IN_HAND)) then
                return true
            else
                return false, self.def:GetLocalizedString("NO_INJURIES_1")
            end
        end

    },

    PC_ALAN_COMBO_STRIKE =
    {
        name = "Combo Strike",
        icon = "battle/silent_shiv.tex",
        anim = "punch",
        desc = "Insert {PC_ALAN_QUICK_THROW} equal to damage dealt by this card.",
        flavour = "'I’ve got plenty more—this is nothing.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.RESTRAINED,
        cost = 1,
        max_xp = 9,
        min_damage = 2,
        max_damage = 3,
        num_cards = 0,
        event_handlers = 
        {
            [ BATTLE_EVENT.ON_HIT ] = function( self, battle, attack, hit )
                if hit.card == self then
                    local num_cards = hit.damage or 0
                    local cards = {}
                    for i = 1, num_cards do
                        local incepted_card = Battle.Card( "PC_ALAN_QUICK_THROW", self:GetOwner() )
                        incepted_card.auto_deal = true
                        table.insert( cards, incepted_card )
                    end
                    battle:DealCards( cards , battle:GetHandDeck() )
                end
            end
        },
    },

    PC_ALAN_COMBO_STRIKE_plus =
    {
        name = "Lightweight Combo Strike",
        desc = "Insert {PC_ALAN_QUICK_THROW} equal to damage dealt by this card.\n<#UPGRADE>{PC_ALAN_LIGHTWEIGHT}{1}: Gain 1 action</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self.light_thresh)
        end, 
        light_thresh = 2,
        action_bonus = 1,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_COMBO_STRIKE_plus2 =
    {
        name = "Combo Strike of the Stone",
        desc = "Insert {PC_ALAN_QUICK_THROW} equal to damage dealt by this card.\n<#UPGRADE>Gain {1} {DEFEND}</>.",   
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ))
        end,      
        defend_amount = 4,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("DEFEND", self.defend_amount, self)
        end,
    },

    PC_ALAN_SPARK_BARRAGE =
    {
        name = "Spark Barrage",
        icon = "battle/one_one_one.tex",
        anim = "punch",
        desc = "This card will attack twice and each hits deal 3 bonus damage if you have any {SPARK_RESERVE}.",
        flavour = "'Finish hitting, then remember to run.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 1,
        max_xp = 9,
        min_damage = 4,
        max_damage = 6,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and self.owner:HasCondition("SPARK_RESERVE") then
                    dmgt:AddDamage( 3, 3, self )
                    self.hit_count = 2
                    return true
                else
                    self.hit_count = 1
                    return false
                end
            end,
        },
    },

    PC_ALAN_SPARK_BARRAGE_plus =
    {
        name = "Boosted Spark Barrage",
        desc = "This card will attack twice, each hits deal <#UPGRADE>6</> bonus damage if you have any {SPARK_RESERVE}.",
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and self.owner:HasCondition("SPARK_RESERVE") then
                    dmgt:AddDamage( 6, 6, self )
                    self.hit_count = 2
                    return true
                else
                    self.hit_count = 1
                    return false
                end
            end,
        },
    },

    PC_ALAN_SPARK_BARRAGE_plus2 =
    {
        name = "Heavy Spark Barrage",
        desc = "This card will attack <#UPGRADE>three times</>, each hits deal 3 bonus damage if you have any {SPARK_RESERVE}.",
        cost = 2,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and self.owner:HasCondition("SPARK_RESERVE") then
                    dmgt:AddDamage( 3, 3, self )
                    self.hit_count = 3
                    return true
                else
                    self.hit_count = 1
                    return false
                end
            end,
        },
    },

    PC_ALAN_LIMIT_REACTION =
    {
        name = "Limit Reaction",
        icon = "battle/overloaded_spark_hammer.tex",
        anim = "punch",
        desc = "Apply and Gain {SPARK_RESERVE} equal to the damage dealt by this card.",
        flavour = "'This is already pushing the limit—any further, and things might go wrong.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.RESTRAINED,
        cost = 1,
        max_xp = 9,
        min_damage = 3,
        max_damage = 5,
        event_handlers = 
        {
            [ BATTLE_EVENT.ON_HIT ] = function( self, battle, attack, hit )
                if hit.card == self and not hit.evaded then
                    hit.target:AddCondition("SPARK_RESERVE", hit.damage or 0, self)
                    self.owner:AddCondition("SPARK_RESERVE", hit.damage or 0, self)
                end
            end
        },
    },

    PC_ALAN_LIMIT_REACTION_plus =
    {
        name = "Rooted Limit Reaction",
        min_damage = 5,
    },

    PC_ALAN_LIMIT_REACTION_plus2 =
    {
        name = "Focus Limit Reaction",
        desc = "<#UPGRADE>Apply</> {SPARK_RESERVE} equal to the damage dealt by this card.",
        min_damage = 2,
        max_damage = 4,
        event_handlers = 
        {
            [ BATTLE_EVENT.ON_HIT ] = function( self, battle, attack, hit )
                if hit.card == self and not hit.evaded then
                    hit.target:AddCondition("SPARK_RESERVE", hit.damage or 0, self)
                end
            end
        },
    },

    PC_ALAN_REUSE =
    {
        name = "Reuse",
        icon = "battle/combination.tex",
        anim = "punch",
        desc = "This card will regain the {LUMIN_RESERVE} consumed after being played.",
        flavour = "'What’s worse than getting doused in Lumin once? Getting doused twice.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 1,
        max_xp = 9,
        min_damage = 3,
        max_damage = 5,
        OnPreResolve = function( self, battle, attack)
            self.lumin_reserve = self.owner:GetConditionStacks( "LUMIN_RESERVE" ) or 0
        end,
        OnPostResolve = function( self, battle, attack)
            if self.lumin_reserve > 0 then
                self.owner:AddCondition("LUMIN_RESERVE", self.lumin_reserve, self)
            end
        end
    },

    PC_ALAN_REUSE_plus =
    {
        name = "Boosted Reuse",
        min_damage = 5,
        max_damage = 7,
    },

    PC_ALAN_REUSE_plus2 =
    {
        name = "Weighted Reuse",
        desc = "This card will regain the {LUMIN_RESERVE} consumed after being played.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Gain 1 action</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self.weight_thresh)
        end,
        weight_thresh = 5,
        action_bonus = 1, 
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_HEAVY_HAMMER =
    {
        name = "Heavy Hammer",
        icon = "battle/cross.tex",
        anim = "punch",
        desc = "{PC_ALAN_WEIGHTED}{1}: Gain 3 {ADRENALINE} and {2} action.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self.weight_thresh, self.action_bonus)
        end,
        flavour = "'This Hesh-damned hammer is heavy!'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 2,
        max_xp = 7,
        min_damage = 5,
        max_damage = 8,
        weight_thresh = 6,
        action_bonus = 1,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
                self.owner:AddCondition("ADRENALINE", 3, self)
            end
        end,
    },

    PC_ALAN_HEAVY_HAMMER_plus =
    {
        name = "Boosted Heavy Hammer",
        min_damage = 8,
        max_damage = 11,
    },

    PC_ALAN_HEAVY_HAMMER_plus2 =
    {
        name = "More Heavier Hammer",
        desc = "{PC_ALAN_WEIGHTED}<#DOWNGRADE>{1}</>: Gain <#UPGRADE>5</> {ADRENALINE} and <#UPGRADE>{2}</> actions.",
        cost = 3,
        weight_thresh = 7,
        action_bonus = 2,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
                self.owner:AddCondition("ADRENALINE", 5, self)
            end
        end,
    },

    PC_ALAN_SUPPRESSIVE_STRIKE =
    {
        name = "Suppressive Strike",
        icon = "battle/crusher.tex",
        anim = "punch",
        desc = "{PC_ALAN_WEIGHTED}{1}: Gain 3 actions.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self.weight_thresh )
        end,
        flavour = "'Where did I learn this move? Well, I forgot.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 3,
        max_xp = 3,
        min_damage = 6,
        max_damage = 9,
        weight_thresh = 8,
        action_bonus = 3,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_SUPPRESSIVE_STRIKE_plus = 
    {
        name = "Boosted Suppressive Strike",
        min_damage = 8,
        max_damage = 11,
    },

    PC_ALAN_SUPPRESSIVE_STRIKE_plus2 =
    {
        name = "Weighted Suppressive Strike",
        desc = "{PC_ALAN_WEIGHTED}{1}: <#UPGRADE>Gain 3 {ADRENALINE}</> and 3 actions.",
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
                self.owner:AddCondition("ADRENALINE", 3, self)
            end
        end,
    },

    PC_ALAN_LUMIN_DISC =
    {
        name = "Lumin Disc",
        icon = "battle/charged_disc.tex",
        anims = "punch",
        desc = "Attack all enemies.\nApply {1} {lumin_burnt}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.lumin_burnt_amt )
        end,
        flavour = "'So far, only Oolo seems to handle this thing proficiently.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MELEE,
        target_mod = TARGET_MOD.TEAM,
        cost = 1,
        max_xp = 9,
        min_damage = 3,
        max_damage = 6,
        lumin_burnt_amt = 5,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("lumin_burnt", self.lumin_burnt_amt, self)
        end
    },

    PC_ALAN_LUMIN_DISC_plus =
    {
        name = "Rooted Lumin Disc",
        min_damage = 6,
    },

    PC_ALAN_LUMIN_DISC_plus2 =
    {
        name = "Boosted Lumin Disc",
        desc = "Attack all enemies.\nApply {1} {lumin_burnt}.\n<#UPGRADE>Gain {2} {LUMIN_RESERVE}</>.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.lumin_burnt_amt, self.lumin_res_amt )
        end,
        lumin_res_amt = 5,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("lumin_burnt", self.lumin_burnt_amt, self)
            self.owner:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end
    },

    PC_ALAN_CARGO_SPILL =
    {
        name = "Cargo Spill",
        icon = "battle/entire_supply.tex",
        anims = "punch",
        desc = "At the end of your turn, if this card is still in your hand, increase its damage by 3 until played.",
        flavour = "'You must always be ready for the enemy’s moves.'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.STICKY,
        cost = 1,
        max_xp = 9,
        min_damage = 3,
        max_damage = 6,
        strength_gain = 3,
        event_handlers = 
        {
            [ BATTLE_EVENT.END_PLAYER_TURN ] = function( self, battle )
                if self.deck == battle:GetHandDeck() and battle:GetBattleResult() == nil then
                    self:NotifyTriggered()
                    self.min_damage = self.min_damage + self.strength_gain
                    self.max_damage = self.max_damage + self.strength_gain
                end
            end
        },
        OnPostResolve = function( self, battle, attack)
            self.min_damage = self.def.min_damage
            self.max_damage = self.def.max_damage
        end, 
    },

    PC_ALAN_CARGO_SPILL_plus =
    {
        name = "Heavy Cargo Spill",
        desc = "At the end of your turn, if this card is still in your hand, increase its damage by <#UPGRADE>6</> until played.",        
        cost = 2,
        strength_gain = 6,
    },

    PC_ALAN_CARGO_SPILL_plus2 =
    {
        name = "Boosted Cargo Spill",
        min_damage = 6,
        max_damage = 9,
    },

    PC_ALAN_TOSS_IT_OVER =
    {
        name = "Toss It Over",
        icon = "battle/efficient_disposal.tex",
        anim = "taunt",
        flavour = "'What? It’s about to blow? Hesh damn it, throw it away—now!'",
        desc = "Remove all stacks of {SPARK_RESERVE} and apply same amount to target.",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.ENEMY,
        cost = 1,
        max_xp = 9,
        OnPreResolve = function( self, battle, attack)
            self.spark_reserve = self.owner:GetConditionStacks( "SPARK_RESERVE" ) or 0
        end,
        OnPostResolve = function( self, battle, attack )
            self.owner:RemoveCondition("SPARK_RESERVE", self.spark_reserve, self)
            attack:AddCondition("SPARK_RESERVE", self.spark_reserve, self)
        end
    },

    PC_ALAN_TOSS_IT_OVER_plus =
    {
        name = "Pale Toss It Over",
        cost = 0,
    },

    PC_ALAN_TOSS_IT_OVER_plus2 =
    {
        name = "Boosted Toss It Over",
        desc = "Remove all stacks of {SPARK_RESERVE} and apply same amount <#UPGRADE>+2</> to target.",
        OnPostResolve = function( self, battle, attack )
            self.owner:RemoveCondition("SPARK_RESERVE", self.spark_reserve, self)
            attack:AddCondition("SPARK_RESERVE", (self.spark_reserve + 2), self)
        end
    },

    PC_ALAN_HAULING_CARGO =
    {
        name = "Hauling Cargo",
        icon = "battle/deepstance.tex",
        anim = "taunt",
        desc = "{PC_ALAN_WEIGHTED}{1}: Play this card automatically.\n{ABILITY}: Whenever you play a card that have cost at least 2, Gain 3 {DEFEND}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        flavour = "'One, two, three—lift!'",
        cost = 0,
        max_xp = 7,
        weight_thresh = 7,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.UNPLAYABLE,
        target_type = TARGET_TYPE.SELF,
        event_handlers = 
        {
            [ BATTLE_EVENT.DRAW_CARD ] = function(self, battle, card)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self) 
            if card.owner == self.owner then
                if total_cost >= self.weight_thresh then
                    self:ClearFlags(CARD_FLAGS.UNPLAYABLE)
                    battle:PlayCard(self, self.owner)
                    self:SetFlags(CARD_FLAGS.UNPLAYABLE)
                end
            end
            end
        },
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_HAULING_CARGO", 1, self)
        end
    },

    PC_ALAN_HAULING_CARGO_plus =
    {
        name = "Visionary Hauling Cargo",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_HAULING_CARGO_plus2 =
    {
        name = "Initial Hauling Cargo",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_THROWING_KNIFE_REPLICAROR =
    {
        name = "Throwing Knife Replicator",
        icon = "battle/replicator.tex",
        anim = "taunt",
        desc = "{ABILITY}: At turn start, insert 1 {PC_ALAN_QUICK_THROW} into your hand.",
        flavour = "'It can only replicate throwing knives, and the quality isn’t great.'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_THROWING_KNIFE_REPLICAROR", 1, self)
        end
    },

    PC_ALAN_THROWING_KNIFE_REPLICAROR_plus =
    {
        name = "Initial Throwing Knife Replicator",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_THROWING_KNIFE_REPLICAROR_plus2 =
    {
        name = "Boosted Throwing Knife Replicator",
        desc = "{ABILITY}: At turn start, insert <#UPGRADE>2</> {PC_ALAN_QUICK_THROW} into your hand.",
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_THROWING_KNIFE_REPLICAROR", 2, self)
        end
    },

    PC_ALAN_REFINED_LUMIN =
    {
        name = "Refined Lumin",
        icon = "battle/crank.tex",
        anim = "taunt",
        desc = "Double your {LUMIN_RESERVE}.",
        flavour = "'This helps remove some of the impurities in Lumin..'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("LUMIN_RESERVE", self.owner:GetConditionStacks( "LUMIN_RESERVE" ), self)
        end,
    },

    PC_ALAN_REFINED_LUMIN_plus =
    {
        name = "Pale Refined Lumin",
        cost = 0,
    },

    PC_ALAN_REFINED_LUMIN_plus2 =
    {
        name = "Enduring Refined Lumin",
        flags = CARD_FLAGS.SKILL,
    },

    PC_ALAN_FULL_REFUND =
    {
        name = "Full Refund",
        icon = "battle/shrewd.tex",
        anim = "taunt",
        desc = "Gain {DEFEND} and {RIPOSTE} equal to the damage of your target's next attack.",
        flavour = "'But not now.'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.BURNOUT,
        target_type = TARGET_TYPE.ENEMY,
        OnPostResolve = function( self, battle, attack )
            local defend_amt = 0
            for i,hit in ipairs(attack.hits) do
                if hit.target and hit.target.prepared_attacks then
                    for i,prep_attack in ipairs(hit.target.prepared_attacks) do
                        for i,prep_hit in ipairs(prep_attack.hits) do
                            if prep_hit.damage then
                                defend_amt = defend_amt + prep_hit.damage
                            end
                        end
                    end
                end
            end
            if defend_amt + self.bonus > 0 then
                self.owner:AddCondition("DEFEND", defend_amt, self)
                self.owner:AddCondition("RIPOSTE", defend_amt, self) 
            end
            end,
        },

    PC_ALAN_FULL_REFUND_plus =
    {
        name = "Stable Full Refund",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
    },

    PC_ALAN_FULL_REFUND_plus2 =
    {
        name = "Lumin Full Refund",
        desc = "Gain {DEFEND} and {RIPOSTE} equal to the damage of your target's next attack.\n<#UPGRADE>Gain {1} {LUMIN_RESERVE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.lumin_res_amt)
        end, 
        lumin_res_amt = 5,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
            local defend_amt = 0
            for i,hit in ipairs(attack.hits) do
                if hit.target and hit.target.prepared_attacks then
                    for i,prep_attack in ipairs(hit.target.prepared_attacks) do
                        for i,prep_hit in ipairs(prep_attack.hits) do
                            if prep_hit.damage then
                                defend_amt = defend_amt + prep_hit.damage
                            end
                        end
                    end
                end
            end
            if defend_amt > 0 then
                self.owner:AddCondition("DEFEND", defend_amt, self)
                self.owner:AddCondition("RIPOSTE", defend_amt, self) 
            end
            end,
    },

    PC_ALAN_BOTTLED_LUMIN =
    {
        name = "Bottled Lumin",
        icon = "battle/the_pinto_pour.tex",
        anim = "taunt",
        desc = "Gain {1} {LUMIN_RESERVE} and {2} {POWER}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.lumin_res_amt, self.pwr_amt )
        end,
        flavour = "'Wait, Smith—that's not your Pinto Pour!'",
        cost = 1,
        max_xp = 9,
        lumin_res_amt = 3,
        pwr_amt = 2,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
            self.owner:AddCondition("POWER", self.pwr_amt, self)
        end,
    },

    PC_ALAN_BOTTLED_LUMIN_plus =
    {
        name = "Pale Bottled Lumin",
        cost = 0,
    },

    PC_ALAN_BOTTLED_LUMIN_plus2 =
    {
        name = "Premium Bottled Lumin",
        desc = "Gain <#UPGRADE>{1}</> {LUMIN_RESERVE} and <#UPGRADE>{2}</> {POWER}.",
        lumin_res_amt = 5,
        pwr_amt = 3,
    },

    PC_ALAN_SPARK_CORE =
    {
        name = "Spark Core",
        icon = "battle/shock_core.tex",
        anim = "taunt",
        desc = "{ABILITY}: At turn start, Gain 2 {SPARK_RESERVE} and 2 {ADRENALINE}.",
        flavour = "'The black market folks tweaked it a bit—now it’s usable for people too.'",
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_SPARK_CORE", 1, self)
        end
    },

    PC_ALAN_SPARK_CORE_plus =
    {
        name = "Initial Spark Core",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_SPARK_CORE_plus2 =
    {
        name = "Pale Spark Core",
        cost = 1,
    },

    PC_ALAN_SPARK_TONIC =
    {
        name = "Spark Tonic",
        icon = "battle/fire_breather.tex",
        anim = "taunt",
        desc = "Spend all {SPARK_RESERVE} and {HEAL} {1} for every {SPARK_RESERVE} spent.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.heal_amt)
        end,
        flavour = "'I have no idea how this was made, and honestly, I don’t want to know.'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        heal_amt = 1,
        OnPostResolve = function( self, battle, attack )
            self.spark_reserve = self.owner:GetConditionStacks( "SPARK_RESERVE" ) or 0
            self.owner:HealHealth(self.spark_reserve * self.heal_amt, self)
            self.owner:RemoveCondition("SPARK_RESERVE")
        end,
    },

    PC_ALAN_SPARK_TONIC_plus =
    {
        name = "Boosted Spark Tonic",
        desc = "Spend all {SPARK_RESERVE} and {HEAL} <#UPGRADE>{1}</> for every {SPARK_RESERVE} spent.",
        heal_amt = 2,
    },

    PC_ALAN_SPARK_TONIC_plus2 =
    {
        name = "Pale Spark Tonic",
        cost = 0,
    },

    PC_ALAN_LUMIN_SHIELD_GENERATOR =
    {
        name = "Lumin Shield Generator",
        icon = "battle/emergency_shield_generator.tex",
        anim = "taunt",
        desc = "{ABILITY}: At turn end, Gain the {DEFEND} equal to the {LUMIN_RESERVE}.",
        flavour = "'I tweaked the internal circuits—now it can stay active for longer.'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_LUMIN_SHIELD_GENERATOR", 1, self)
        end
    },

    PC_ALAN_LUMIN_SHIELD_GENERATOR_plus =
    {
        name = "Initial Lumin Shield Generator",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_LUMIN_SHIELD_GENERATOR_plus2 =
    {
        name = "Boosted Lumin Shield Generator",
        desc = "<#UPGRADE>Gain {1} {LUMIN_RESERVE}</>.\n{ABILITY}: At turn end, Gain the {DEFEND} equal to the {LUMIN_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "LUMIN_RESERVE", self.lumin_res_amt ))
        end,
        lumin_res_amt = 5,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_LUMIN_SHIELD_GENERATOR", 1, self)
            self.owner:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end
    },

    PC_ALAN_CONFIRM_TARGET =
    {
        name = "Confirm Target",
        icon = "battle/fixed.tex",
        anim = "taunt",
        desc = "For every 0-cost card on hand, Apply 1 {tracer}\n(Apply {1} {tracer}).",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.tracer_amt)
        end,
        flavour = "'You're the one!'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.ENEMY,
        tracer_amt = 1,
        CalcDefend = function(self)
            local hand = self.engine:GetHandDeck() 
            local num_cards_0 = 0
            for i, card in ipairs(hand.cards) do 
                if card.cost == 0 then
                    num_cards_0 = num_cards_0 + 1
                end
            end
            return num_cards_0 * self.tracer_amt
        end,
        OnPostResolve = function( self, battle, attack )
            local tracer_amt = self:CalcDefend() 
            attack:AddCondition("tracer", tracer_amt, self)
        end,
    },

    PC_ALAN_CONFIRM_TARGET_plus =
    {
        name = "Boosted Confirm Target",
        min_damage = 4,
        max_damage = 7,
    },

    PC_ALAN_CONFIRM_TARGET_plus2 =
    {
        name = "Visionary Confirm Target",
        desc = "<#UPGRADE>Draw a card</>\nFor every 0-cost card on hand, Apply 1 {tracer}\n(Apply {1} {tracer}).",
        OnPostResolve = function( self, battle, attack )
            local tracer_amt = self:CalcDefend() 
            attack:AddCondition("tracer", tracer_amt, self)
            battle:DrawCards(1)
        end,
    },

    PC_ALAN_ANCHOR =
    {
        name = "Anchor",
        icon = "battle/boat_anchor.tex",
        anim = "taunt",
        desc = "Apply {1} {DEFEND}.\nThis card costs 1 more per two other cards in your hand.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.defend_amount )
        end,
        flavour = "Not as heavy as it looks, but still enough to give you trouble.",
        cost = 1,
        max_xp = 7,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        flags = CARD_FLAGS.SKILL,
        rarity = CARD_RARITY.UNCOMMON,
        defend_amount = 8,
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("DEFEND", self.defend_amount, self)
        end,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.IN_HAND, DECK_TYPE.DISCARDS },
        event_handlers = 
        {
            [ BATTLE_EVENT.CALC_ACTION_COST ] = function( self, cost_acc, card, target )
                if card == self then
                    local cost_reduction = math.floor((self.engine:GetHandDeck():CountCards() - 1) / 2) 
                    cost_acc:AddValue(cost_reduction)
                end
            end
        },
    },

    PC_ALAN_ANCHOR_plus =
    {
        name = "Visionary Anchor",
        desc = "Apply <#UPGRADE>{1}</> {DEFEND}.\nThis card costs 1 more per two other cards in your hand.",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_ANCHOR_plus2 =
    {
        name = "Stone Anchor",
        defend_amount = 12,
    },

    PC_ALAN_PERFORMANCE =
    {
        name = "Performance",
        icon = "battle/exertion.tex",
        anim = "taunt",
        desc = "Draw a card and play them for free.",
        flavour = "'Keep fighting, and you might just learn something new.'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, target )
            local drawn_cards = battle:DrawCards(1) 
            if drawn_cards and #drawn_cards > 0 then
                self.engine:PlayCard(drawn_cards[1])
            end
        end
    },

    PC_ALAN_PERFORMANCE_plus =
    {
        name = "Pale Performance",
        cost = 0,
    },

    PC_ALAN_PERFORMANCE_plus2 =
    {
        name = "Improvised Performance",
        desc = "{IMPROVISE} a card form your draw pile and play them for free.",
        OnPostResolve = function(self, battle, attack)
            self.active = true
            local cards = {}

            for i, card in battle:GetDrawDeck():Cards() do
                table.insert(cards, card)
            end

            if #cards == 0 then
                battle:ShuffleDiscardToDraw()
                for i, card in battle:GetDrawDeck():Cards() do
                    table.insert(cards, card)
                end
            end

            local chosen_cards = battle:ImproviseCards(table.multipick(cards, 3), 1, "off_hand", nil, nil, self)

             if chosen_cards and #chosen_cards > 0 then
                local chosen_card = chosen_cards[1]
                chosen_card.cost = 0 
                self.engine:PlayCard(chosen_card)
            end
        end,
    },

    PC_ALAN_FOCUS =
    {
        name = "Focus",
        icon = "battle/concentrate.tex",
        anim = "taunt",
        desc = "Draw 3 cards.",
        flavour = "'Remember to take a deep breath.'",
        cost = 0,
        max_xp = 10,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(3)
        end,
    },

    PC_ALAN_FOCUS_plus =
    {
        name = "Boosted Focus",
        desc = "Draw 3 cards <#UPGRADE>and Gain 1 action</>.",
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(3)
            self.engine:ModifyActionCount(1)
        end,
    },

    PC_ALAN_FOCUS_plus2 =
    {
        name = "Enduring Focus",
        cost = 1,
        flags = CARD_FLAGS.SKILL,
    }, 

    PC_ALAN_RAISE_SHIELD = 
    {
        name = "Raise Shield",
        icon = "battle/breather.tex",
        anim = "taunt",
        desc = "Apply {1} {DEFEND} and draw a card.\n{CHAIN}{PC_ALAN_RAISE_SHIELD_II|}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        flavour = "Honestly, no need to keep it up all the time.",
        cost = 0,
        flags = CARD_FLAGS.SKILL,
        rarity = CARD_RARITY.UNCOMMON,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        defend_amount = 3,
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("DEFEND", self.defend_amount, self)
            battle:DrawCards(1)
            local card = Battle.Card("PC_ALAN_RAISE_SHIELD_II", self.owner)
            card.base_card = self
            card.auto_deal = true
            battle:DealCard(card, battle:GetDrawDeck())
            self:TransferCard( battle.trash_deck )
        end,
    },

    PC_ALAN_RAISE_SHIELD_II =
    {
        name = "Raise Shield II",
        icon = "battle/breather.tex",
        anim = "taunt",
        desc = "Apply {1} {DEFEND} and draw a card.\n{CHAIN}{PC_ALAN_RAISE_SHIELD_III|}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        hide_in_cardex = true,
        cost = 1,
        flags = CARD_FLAGS.SKILL,
        rarity = CARD_RARITY.UNCOMMON,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        defend_amount = 6,
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("DEFEND", self.defend_amount, self)
            battle:DrawCards(1)
            local card = Battle.Card("PC_ALAN_RAISE_SHIELD_III", self.owner)
            card.base_card = self.base_card
            card.auto_deal = true
            battle:DealCard(card, battle:GetDrawDeck())
            self:TransferCard( battle.trash_deck )
        end,
        deck_handlers = { DECK_TYPE.DISCARDS },
        event_handlers =
        {
            [ BATTLE_EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self and target_deck and target_deck:GetDeckType() == DECK_TYPE.DISCARDS then
                    local idx = self.engine:GetDrawDeck():CountCards() > 1 and math.random( self.engine:GetDrawDeck():CountCards() ) or 1
                    if self.base_card then self.base_card:TransferCard(self.engine:GetDrawDeck(), idx) end
                    self:TransferCard( self.engine.trash_deck )
                end
            end
        }
    },

    PC_ALAN_RAISE_SHIELD_III =
    {
        name = "Raise Shield III",
        icon = "battle/breather.tex",
        anim = "taunt",
        desc = "Apply {1} {DEFEND} and draw a card.\n{CHAIN}{PC_ALAN_RAISE_SHIELD_IV|}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        hide_in_cardex = true,
        cost = 2,
        flags = CARD_FLAGS.SKILL,
        rarity = CARD_RARITY.UNCOMMON,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        defend_amount = 9,
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("DEFEND", self.defend_amount, self)
            battle:DrawCards(1)
            local card = Battle.Card("PC_ALAN_RAISE_SHIELD_IV", self.owner)
            card.base_card = self.base_card
            card.auto_deal = true
            battle:DealCard(card, battle:GetDrawDeck())
            self:TransferCard( battle.trash_deck )
        end,
        deck_handlers = { DECK_TYPE.DISCARDS },
        event_handlers =
        {
            [ BATTLE_EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self and target_deck and target_deck:GetDeckType() == DECK_TYPE.DISCARDS then
                    local idx = self.engine:GetDrawDeck():CountCards() > 1 and math.random( self.engine:GetDrawDeck():CountCards() ) or 1
                    if self.base_card then self.base_card:TransferCard(self.engine:GetDrawDeck(), idx) end
                    self:TransferCard( self.engine.trash_deck )
                end
            end
        }
    },

    PC_ALAN_RAISE_SHIELD_IV =
    {
        name = "Raise Shield IV",
        icon = "battle/breather.tex",
        anim = "taunt",
        desc = "Apply {1} {DEFEND} and draw a card.\n{CHAIN}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        hide_in_cardex = true,
        cost = 3,
        flags = CARD_FLAGS.SKILL,
        rarity = CARD_RARITY.UNCOMMON,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        defend_amount = 12,
        deck_handlers = { DECK_TYPE.DISCARDS },
        event_handlers =
        {
            [ BATTLE_EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self and target_deck and target_deck:GetDeckType() == DECK_TYPE.DISCARDS then
                    if source_deck and source_deck:GetDeckType() == DECK_TYPE.RESOLVE then
                        local idx = self.engine:GetDrawDeck():CountCards() > 1 and math.random( self.engine:GetDrawDeck():CountCards() ) or 1
                        self:TransferCard(self.engine:GetDrawDeck(), idx)
                    else
                        local idx = self.engine:GetDrawDeck():CountCards() > 1 and math.random( self.engine:GetDrawDeck():CountCards() ) or 1
                        if self.base_card then self.base_card:TransferCard(self.engine:GetDrawDeck(), idx) end
                        self:TransferCard( self.engine.trash_deck )
                    end
                end
            end
        },
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("DEFEND", self.defend_amount, self)
            battle:DrawCards(1)
        end
    },

    PC_ALAN_STAY_ALERT =
    {
        name = "Stay Alert",
        icon = "battle/thieves_instinct.tex",
        anim = "taunt",
        desc = "Apply {1} {DEFEND}\nAt the end of your turn, if this card is still in your hand, increase the Defense applied by this card by {2} until played.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ), self.defend_bonus)
        end,
        flavour = "'Wait—that’s my cargo!'",
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.STICKY,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        cost = 1,
        max_xp = 9,
        defend_amount = 4,
        defend_bonus = 3,
        event_handlers = 
        {
            [ BATTLE_EVENT.END_PLAYER_TURN ] = function( self, battle )
                if self.deck == battle:GetHandDeck() and battle:GetBattleResult() == nil then
                    self:NotifyTriggered()
                    self.defend_amount = self.defend_amount + self.defend_bonus
                end
            end
        },
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("DEFEND", self.defend_amount, self)
        end
    },

    PC_ALAN_STAY_ALERT_plus =
    {
        name = "More Stay Alert",
        desc = "Apply {1} {DEFEND}\nAt the end of your turn, if this card is still in your hand, increase the Defense applied by this card by <#UPGRADE>{2}</> until played.",        
        cost = 2,
        defend_bonus = 5,
    },

    PC_ALAN_STAY_ALERT_plus2 =
    {
        name = "Boosted Stay Alert",
        desc = "Apply <#UPGRADE>{1}</> {DEFEND}\nAt the end of your turn, if this card is still in your hand, increase the Defense applied by this card by {2} until played.",
        defend_amount = 7,
    },

    PC_ALAN_READY =
    {
        name = "Ready",
        icon = "battle/fistful.tex",
        anim = "taunt",
        flavour = "'Here, take it—just like you wanted.'",
        desc = "Draw {1} cards, gain {LUMIN_RESERVE} equal to twice of their combined cost.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.draw_count)
        end,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        draw_count = 2,
        OnPostResolve = function( self, battle, attack )
            local cards = battle:DrawCards(self.draw_count)
            local cost = self.lumin_reserve or 0
            for i,card in ipairs(cards) do
                cost = cost + card.cost
            end
            if cost > 0 then
                self.owner:AddCondition("LUMIN_RESERVE", (cost * 2), self)
            end
        end
    },

    PC_ALAN_READY_plus =
    {
        name = "Visionary Ready",
        desc = "Draw <#UPGRADE>{1}</> cards, gain {LUMIN_RESERVE} equal to twice of their combined cost.",
        draw_count = 3,
    },

    PC_ALAN_READY_plus2 = 
    {
        name = "Boosted Ready",
        desc = "Draw {1} cards, gain {LUMIN_RESERVE} equal to twice of their combined cost <#UPGRADE>+3</>.",
        lumin_reserve = 2,
    },

    PC_ALAN_DEEP_POCKETS =
    {
        name = "Deep Pockets",
        icon = "battle/rummage.tex",
        anim = "taunt",
        desc = "{ABILITY}: At turn start, draw a card.",
        flavour = "'I keep a few things in here—just in case.'",
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_DEEP_POCKETS", 1, self)
        end
    },

    PC_ALAN_DEEP_POCKETS_plus =
    {
        name = "Initial Deep Pockets", 
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_DEEP_POCKETS_plus2 =
    {
        name = "Pale Deep Pockets",
        cost = 1,       
    },

    PC_ALAN_IMPROVEMENT =
    {
        name = "Improvement",
        icon = "battle/intensify.tex",
        anim = "taunt",
        desc = "Choose a card in your hand, it deals 3 bonus damage until played.",
        flavour = "'Don’t worry, this one’s actually legal—just a bit prone to exploding.'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        condition_amt = 1,
        OnPostResolve = function( self, battle, attack )
            local card = battle:ChooseCard()
            if card then
                local con = self.owner:AddCondition("PA_IMPROVEMENT", self.condition_amt, self)
                if con then
                    con.chosen_cards = con.chosen_cards or {}
                    table.insert(con.chosen_cards, card)
                end
            end
        end,
    },

    PC_ALAN_IMPROVEMENT_plus =
    {
        name = "Boosted Improvement",
        desc = "Choose a card in your hand, it deals <#UPGRADE>6</> bonus damage until played.",
        condition_amt = 2,
    },

    PC_ALAN_IMPROVEMENT_plus2 =
    {
        name = "Pale Improvement",
        cost = 0,
    },

    PC_ALAN_UNYIELDING =
    {
        name = "Unyielding",
        icon = "battle/sentinel.tex",
        anim = "taunt",
        desc = "Can only be played if you haven't played any card in this turn.\nGain {1} {DEFEND} and {2} {POWER}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ), self.pwr_amt)
        end,
        flavour = "'Now it’s just a matter of who lasts longer!'",
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        defend_amount = 6,
        pwr_amt = 1,
        loc_strings =
        {
            CARD_PLAYED_ALAN = "Another card has already been played this turn.",
        }, 
        CanPlayCard = function( self, battle, target )
            local card_played = self.engine:CountCardsPlayed()
            if card_played ~= 0 then
                return false, self.def:GetLocalizedString("CARD_PLAYED_ALAN")
            end
            return true
        end,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("DEFEND", self.defend_amount, self)
            self.owner:AddCondition("POWER", self.pwr_amt, self)
        end
    },

    PC_ALAN_UNYIELDING_plus =
    {
        name = "Stone Unyielding",
        desc = "Can only be played if you haven't played any card in this turn.\nGain <#UPGRADE>{1}</> {DEFEND} and {2} {POWER}.",
        defend_amount = 10,
    },

    PC_ALAN_UNYIELDING_plus2 =
    {
        name = "Boosted Unyielding",
        desc = "Can only be played if you haven't played any card in this turn.\nGain {1} {DEFEND} and <#UPGRADE>{2}</> {POWER}.",
        pwr_amt = 2,
    },

    PC_ALAN_ALL_FOR_ONE =
    {
        name = "All for One",
        icon = "battle/bio_strike.tex",
        anim = "punch",
        desc = "Put all 0-cost card into your hand.",
        flavour = "'Took me a while to find this—rumor has it, it came from an ancient tower.'",
        cost = 0,
        max_xp = 9,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.EXPEND,
        min_damage = 5,
        max_damage = 6,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        OnPostResolve = function( self, card, source_deck, source_idx, target_deck, target_idx )
            local battle = self.engine
            local hand_deck = battle:GetHandDeck()
            local valid_cards = {}

            for _, draw_card in battle:GetDrawDeck():Cards() do
                local cost = draw_card.GetCost and draw_card:GetCost() or draw_card.cost 
                if cost and cost == 0 then
                    table.insert(valid_cards, draw_card)
                end
            end

            for _, discard_card in battle:GetDiscardDeck():Cards() do
                local cost = discard_card.GetCost and discard_card:GetCost() or discard_card.cost
                if cost and cost == 0 then
                    table.insert(valid_cards, discard_card)
                end
            end

            if #valid_cards > 0 then
                for _, move_card in ipairs(valid_cards) do
                    move_card:TransferCard(hand_deck)
                end
            end
        end
    },

    PC_ALAN_ALL_FOR_ONE_plus = 
    {
        name = "Boosted All for One",
        min_damage = 7,
        max_damage = 8,
    },

    PC_ALAN_ALL_FOR_ONE_plus2 =
    {
        name = "Enduring All for One",
        flags = CARD_FLAGS.MELEE,
        cost = 2,
    },

    PC_ALAN_SUPREME_STRIKE =
    {
        name = "Supreme Strike",
        icon = "battle/crushing_blow.tex",
        anim = "punch",
        desc = "At the end of your turn, if this card is still in your hand, decrease the cost by 1 until played.",
        flavour = "'Meet the Hesh!'",
        cost = 3,
        max_xp = 3,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.STICKY,
        min_damage = 8,
        max_damage = 14,
        event_handlers = 
        {
            [ BATTLE_EVENT.END_PLAYER_TURN ] = function( self, battle )
            if self.deck == battle:GetHandDeck() and battle:GetBattleResult() == nil then
                self:NotifyTriggered()
                self.cost = self.cost - 1
            end
            end
        },
        OnPostResolve = function( self, battle, attack )
            self.cost = self.def.cost
        end, 
    },

    PC_ALAN_SUPREME_STRIKE_plus =
    {
        name = "Pale Supreme Strike",
        cost = 2,
        min_damage = 5,
        max_damage = 9
    },

    PC_ALAN_SUPREME_STRIKE_plus2 =
    {
        name = "Heavy Supreme Strike",
        cost = 4,
        min_damage = 11,
        max_damage = 17,
    },

    PC_ALAN_WARNING_SHOT =
    {
        name = "Warning Shot",
        icon = "battle/cataclysm.tex",
        anim = "throw",
        desc = "If either you or the target has {SPARK_RESERVE}, Double the damage.\nIf both have {SPARK_RESERVE}, Double damage again.",
        flavour = "'You dare step closer? Huh?!'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.RANGED,
        min_damage = 3,
        max_damage = 6,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and self.owner:HasCondition("SPARK_RESERVE") then
                    dmgt:AddDamage( dmgt.min_damage, dmgt.max_damage, self )
                end

                if self == card and target and self.target:HasCondition("SPARK_RESERVE") then
                    dmgt:AddDamage( dmgt.min_damage, dmgt.max_damage, self )
                end
            end,
        },
    },

    PC_ALAN_WARNING_SHOT_plus =
    {
        name = "Rooted Warning Shot",
        min_damage = 6,
    },

    PC_ALAN_WARNING_SHOT_plus2 =
    {
        name = "Tall Warning Shot",
        max_damage = 9,
    },

    PC_ALAN_LUMIN_EXPLOSIVE = 
    {
        name = "Lumin Explosive",
        icon = "battle/high_yield_lumin_bomb.tex",
        anim = "throw",
        desc = "Attack all enemies.\nApply {1} {lumin_burnt}.\nOnce per turn, whenever you get hit, play this card for free.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.lumin_burnt_amt)
        end,
        flavour = "'Stay back! One step closer, and I’m throwing it!'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.RANGED,
        target_mod = TARGET_MOD.TEAM,
        min_damage = 6,
        max_damage = 6,
        lumin_burnt_amt = 5,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        triggered_this_turn = false,
        event_handlers =
        {
            [ BATTLE_EVENT.ON_HIT ] = function(self, battle, attack, hit)
            if hit.target == self.owner and attack.card:IsAttackCard() and not attack.is_counter and self.triggered_this_turn == false then
                self.engine:PushPostHandler(function()
                    battle:PlayCard(self, self.owner)
                    self.triggered_this_turn = true
                end)
            end
            end,

            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function(self, battle, fighter)
            self.triggered_this_turn = false
            end,
        },
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("lumin_burnt", self.lumin_burnt_amt, self)
        end
    },

    PC_ALAN_LUMIN_EXPLOSIVE_plus =
    {
        name = "Rooted Lumin Explosive",
        min_damage = 8,
        max_damage = 8,
    },

    PC_ALAN_LUMIN_EXPLOSIVE_plus2 =
    {
        name = "Tall Lumin Explosive",
        max_damage = 10,
    },

    PC_ALAN_DISHONORABLE =
    {
        name = "Dishonorable",
        icon = "battle/wretched_strike.tex",
        anim = "punch",
        desc = "Apply 1 {STUN}",
        flavour = "'Relax, it’s just a few days of bed rest.'",
        cost = 1,
        max_xp = 9,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.EXPEND,
        min_damage = 2,
        max_damage = 4,
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("STUN", 1, self)
        end
    },

    PC_ALAN_DISHONORABLE_plus =
    {
        name = "Boosted Dishonorable",
        min_damage = 3,
        max_damage = 6,
    },

    PC_ALAN_DISHONORABLE_plus2 =
    {
        name = "Enduring Dishonorable",
        desc = "<#DOWNGRADE>{PC_ALAN_LIGHTWEIGHT}{1}</>: Apply 1 {STUN}",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.light_thresh)
        end,
        flags = CARD_FLAGS.MELEE,
        light_thresh = 1,
        OnPostResolve = function( self, battle, attack )
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                attack.target:AddCondition("STUN", 1, self)
            end
        end
    },

    PC_ALAN_SECOND_HAND_SCANNER =
    {
        name = "Second-Hand Scanner",
        icon = "battle/scanner.tex",
        anim = "taunt",
        flavour = "'A discarded unit from the Aerostat, but with some repairs, it still works.'",
        desc = "Apply {1} {SCANNED} to a random enemy.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.scanned_amt )
        end,
        cost = 0,
        flags = CARD_FLAGS.SKILL,
        rarity = CARD_RARITY.RARE,
        target_mod = TARGET_MOD.RANDOM1,
        scanned_amt = 1,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("SCANNED", self.scanned_amt, self)
        end
    },

    PC_ALAN_SECOND_HAND_SCANNER_plus =
    {
        name = "Overloaded Second-Hand Scanner",
        desc = "Apply <#UPGRADE>{1} {SCANNED}</> to a random enemy.",
        scanned_amt = 2,
    },

    PC_ALAN_SECOND_HAND_SCANNER_plus2 =
    {
        name = "Precise Second-Hand Scanner",
        desc = "Apply {1} {SCANNED} to <#UPGRADE>an enemy.</>",
        target_mod = TARGET_MOD.SINGLE,
    },

    PC_ALAN_RHYTHM =
    {
        name = "Rhythm",
        icon = "battle/slam.tex",
        anim = "taunt",
        desc = "{ABILITY}: Whenever you play a card that costs 0, gain 1 {ADRENALINE}.",
        flavour = "'Come on, feel the beat with me.'",
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_RHYTHM", 1, self)
        end
    },

    PC_ALAN_RHYTHM_plus =
    {
        name = "Initial Rhythm", 
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_RHYTHM_plus2 =
    {
        name = "Boosted Rhythm",
        desc = "{ABILITY}: Whenever you play a card that costs 0, gain <#UPGRADE>2</> {ADRENALINE}.",
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_RHYTHM", 2, self)
        end
    },

    PC_ALAN_CHARGE_UP =
    {
        name = "Charge Up",
        icon = "battle/cynotrainer.tex",
        anim = "taunt",
        desc = "{ABILITY}: At turn start, choose a card, double the damage of that card.",
        flavour = "'Are you ready?!'",
        cost = 3,
        max_xp = 3,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_CHARGE_UP", 1, self)
        end
    },

    PC_ALAN_CHARGE_UP_plus =
    {
        name = "Initial Charge Up", 
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_CHARGE_UP_plus2 =
    {
        name = "Pale Charge Up",
        cost = 2,
    },

    PC_ALAN_BACKUP_LUMIN_FUEL =
    {
        name = "Backup Lumin Fuel",
        icon = "battle/secret_collection.tex",
        anim = "taunt",
        desc = "{ABILITY}: At the end of your turn, gain 2 {LUMIN_RESERVE}.",
        flavour = "'The amount is a bit low, but it’ll do.'",
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_BACKUP_LUMIN_FUEL", 1, self)
        end
    },

    PC_ALAN_BACKUP_LUMIN_FUEL_plus =
    {
        name = "Initial Backup Lumin Fuel", 
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_BACKUP_LUMIN_FUEL_plus2 =
    {
        name = "Pale Backup Lumin Fuel",
        cost = 1,       
    },

    PC_ALAN_CONVERT =
    {
        name = "Convert",
        icon = "battle/mettle.tex",
        anim = "taunt",
        desc = "At the end of your turn, if this card is on hand, play it.\nConvert all {ADRENALINE} into {POWER}.",
        flavour = "'The amount is a bit low, but it’ll do.'",
        cost = 0,
        max_xp = 9,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.UNPLAYABLE,
        target_type = TARGET_TYPE.SELF,
        event_handlers =
        {
            [ BATTLE_EVENT.END_PLAYER_TURN ] = function( self, battle, card )
                if self.deck == battle:GetHandDeck() then
                    self:ClearFlags(CARD_FLAGS.UNPLAYABLE)
                    battle:PlayCard(self, self.owner)
                    self:SetFlags(CARD_FLAGS.UNPLAYABLE)
                end
            end,
        },
        OnPostResolve = function( self, battle, attack )
            local count = self.owner:GetConditionStacks("ADRENALINE")
            if count > 0 then
                self.owner:RemoveCondition("ADRENALINE", count, self)
                self.owner:AddCondition("POWER", count, self)
            end
        end
    },

    PC_ALAN_CONVERT_plus =
    {
        name = "Visionary Convert",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_CONVERT_plus2 =
    {
        name = "Twisted Visionary Convert",
        desc = "Convert all {ADRENALINE} into {POWER}.",
        cost = 1,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.STICKY,
        event_handlers =
        {

        },
        OnPostResolve = function( self, battle, attack )
            local count = self.owner:GetConditionStacks("ADRENALINE")
            if count > 0 then
                self.owner:RemoveCondition("ADRENALINE", count, self)
                self.owner:AddCondition("POWER", count, self)
            end
        end
    },

    PC_ALAN_FIRST_AID =
    {
        name = "First Aid",
        icon = "battle/triage.tex",
        anim = "taunt",
        desc = "{1} {HEAL}.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.heal_amt)
        end,
        flavour = "'I know a bit of first aid—need a hand?'",
        cost = 1,
        max_xp = 9,
        heal_amt = 5,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        OnPostResolve = function( self, battle, attack)
            self.target:HealHealth( self.heal_amount, self )
        end,
    },

    PC_ALAN_FIRST_AID_plus =
    {
        name = "Boosted First Aid",
        desc = "<#UPGRADE>{1}</> {HEAL}",
        heal_amt = 8,
    },

    PC_ALAN_FIRST_AID_plus2 =
    {
        name = "Visionary First Aid",
        desc = "<#UPGRADE>Draw a card</>\n{1} {HEAL}",
        OnPostResolve = function( self, battle, attack)
            self.target:HealHealth( self.heal_amount, self )
            battle:DrawCards(1)
        end,
    },

    PC_ALAN_OVERLOADED_CORE =
    {
        name = "Overloaded Core",
        icon = "battle/overloaded_core.tex",
        anim = "taunt",
        desc = "{ABILITY}: Gain {POWER} equal to your {SPARK_RESERVE}. When the amount of {SPARK_RESERVE} changes, the amount of {POWER} will also change.",
        flavour = "'Handle with care—don’t let it blow up again.'",
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_OVERLOADED_CORE", 1, self)
        end
    },

    PC_ALAN_OVERLOADED_CORE_plus =
    {
        name = "Initial Overloaded Core", 
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_OVERLOADED_CORE_plus2 =
    {
        name = "Pale Overloaded Core",
        cost = 1,       
    },

    PC_ALAN_PERFECT_ACCURACY =
    {
        name = "Perfect Accuracy",
        icon = "battle/improve_accuracy.tex",
        anim = "taunt",
        desc = "{ABILITY}: Your attacks deal max damage for the rest of the turns.",
        flavour = "'Every strike is lethal!'",
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_PERFECT_ACCURACY", 1, self)
        end
    },

    PC_ALAN_PERFECT_ACCURACY_plus =
    {
        name = "Initial Perfect Accuracy", 
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_PERFECT_ACCURACY_plus2 =
    {
        name = "Visionary Perfect Accuracy",      
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_POWER_SURGE =
    {
        name = "Power Surge",
        icon = "battle/raw_power.tex",
        anim = "taunt",
        desc = "{PC_ALAN_WEIGHTED}{1}: Play this card automatically.\n{ABILITY}: Whenever you play a card that have cost at least 2, Play it again.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        flavour = "'WAAAGH!'",
        cost = 0,
        max_xp = 3,
        weight_thresh = 9,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.UNPLAYABLE,
        target_type = TARGET_TYPE.SELF,
        event_handlers = 
        {
            [ BATTLE_EVENT.DRAW_CARD ] = function(self, battle, card)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self) 
            if card.owner == self.owner then
                if total_cost >= self.weight_thresh then
                    self:ClearFlags(CARD_FLAGS.UNPLAYABLE)
                    battle:PlayCard(self, self.owner)
                    self:SetFlags(CARD_FLAGS.UNPLAYABLE)
                end
            end
            end
        },
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_POWER_SURGE", 1, self)
        end
    },

    PC_ALAN_POWER_SURGE_plus =
    {
        name = "Visionary Power Surge",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_POWER_SURGE_plus2 =
    {
        name = "Initial Power Surge",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_LUMIN_BOOST =
    {
        name = "Lumin Boost",
        icon = "battle/lumin_jolt.tex",
        anim = "taunt",
        desc = "{ABILITY}: Each time you gain {LUMIN_RESERVE}, gain 1 {POWER}.",
        flavour = "'Careful—don’t let the Cult of Hesh see this.'",
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_type = TARGET_TYPE.SELF,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("PA_LUMIN_BOOST", 1, self)
        end
    },

    PC_ALAN_LUMIN_BOOST_plus =
    {
        name = "Initial Lumin Boost", 
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_LUMIN_BOOST_plus2 =
    {
        name = "Pale Lumin Boost",
        cost = 1,       
    },

    PC_ALAN_THREATEN =
    {
        name = "Threaten",
        icon = "battle/doomed.tex",
        anim = "taunt",
        desc = "Increases the target's {SURRENDER} meter by {1}.",
        flavour = "'I'll give you a chance to beg for mercy!'",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.sur_amt)
        end,
        cost = 2,
        max_xp = 7,
        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.ENEMY,
        sur_amt = 10,
        OnPostResolve = function( self, battle, attack )
            for i, hit in attack:Hits() do
                if hit.target:HasMorale() then
                    local health = hit.target:GetMaxHealth()
                    hit.target:DeltaMorale( (self.sur_amt)/health )
                end
            end
        end,
    },

    PC_ALAN_THREATEN_plus =
    {
        name = "Pale Threaten",
        cost = 1,
    },

    PC_ALAN_THREATEN_plus2 =
    {
        name = "Boosted Threaten",
        desc = "Increases the target's {SURRENDER} meter by <#UPGRADE>{1}</>.",        
        sur_amt = 20,
    },


    --------------------------------------------------------------------------------------
    --
    
    spices =
    {
        name = "Spices",
        desc = "{COMMODITY}",
        icon = "LOSTPASSAGE:textures/spices.png",

        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.ITEM | CARD_FLAGS.UNPLAYABLE,
        shop_price = 150,
    },

    oshnu_mucus =
    {
        name = "Oshnu Mucus",
        desc = "{COMMODITY}",
        icon = "LOSTPASSAGE:textures/oshnu_mucus.png",

        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.ITEM | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.STICKY,
        shop_price = 80,
    },

    spollop =
    {
        name = "Spollop Fungus",
        desc = "{COMMODITY}",
        icon = "LOSTPASSAGE:textures/spollop.png",

        rarity = CARD_RARITY.RARE,
        flags = CARD_FLAGS.ITEM | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.BURNOUT,
        shop_price = 300,
    },
}

for i, id, carddef in sorted_pairs( CARDS ) do
    carddef.series = carddef.series or "SHEL"
    Content.AddBattleCard( id, carddef )
end


------------------------------------------------------------------------------------------------------

local COMMODITY = BattleFeatureDef( "COMMODITY",
{
    name = "Commodity",
    desc = "This object can be sold to the right person for money."
})

Content.AddBattleCardFeature( "COMMODITY", COMMODITY )

local FEATURES =
{
    PC_ALAN_WEIGHTED =
    {
    name = "Weighted ",
    desc = "If the total cost of all cards in hand is <b>at least</b> a certain amount before this card is played, an additional effect is triggered.",
    },

    PC_ALAN_LIGHTWEIGHT =
    {
    name = "Lightweight ",
    desc = "If the total cost of all cards in hand is <b>at most</b> a certain amount before this card is played, an additional effect is triggered.",
    }
}

for id, data in pairs( FEATURES ) do
    local def = BattleFeatureDef(id, data)
    Content.AddBattleCardFeature(id, def)
end