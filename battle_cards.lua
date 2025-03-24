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
        desc = "Up to 10 stacks. At 10 stacks, clear all stack and dealing 20% max HP damage to the bearer.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks)
        end,

        icon = "battle/conditions/resonance.tex",
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
                        local damage = math.floor(max_health * 0.2)
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
        desc = "Your next attack applies {1} {lumin_burnt} and {2} {DEFEND} to the target.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks, math.ceil(self.stacks / 5))
        end,

        icon = "battle/conditions/resonance.tex",
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
                        hit.target:AddCondition("lumin_burnt", stacks, self)
                        hit.target:AddCondition("DEFEND", defend_amount, self)
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

    NEXT_TURN_CARD =
    {
        name = "Next turn card",
        desc = "Draw additional card at the start of your turn.",
        hidden = true,
        event_handlers = 
        {
            [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
            battle:DrawCards(self.stacks or 1)
            self.owner:RemoveCondition("NEXT_TURN_CARD")
        end
        },
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
        max_xp = 5,
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
        flavour = "'As a fuel merchant, I'd better prepare more bottles, whether for storing or throwing.'",
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
        min_damage = 4,
        max_damage = 4,
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
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.num_draw)
        end,
        min_damage = 3,
        max_damage = 3,
        num_draw = 1,
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards( self.num_draw )
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
        max_xp = 6,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition( "DEFEND", self.defend_amount, self )
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
        spark_amt = 3,
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
        desc = "Insert {PC_ALAN_LUMIN_2a} or {PC_ALAN_LUMIN_2b} into your hand.",
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
        desc = "Insert {PC_ALAN_SPARK_2a} or {PC_ALAN_SPARK_2b} into your hand.",
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
            return loc.format(fmt_str, 
                CalculateConditionText(self, "SPARK_RESERVE", self.self_spark_amt), 
                CalculateConditionText(self, "SPARK_RESERVE", self.target_spark_amt)
                )
        end,
        rarity = CARD_RARITY.UNIQUE,
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.EXPEND,
        cost = 0,
        min_damage = 3,
        max_damage = 3,
        self_spark_amt = 2,
        target_spark_amt = 3,
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
        cost = 3,
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
        cost = 4,
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
        flavour = "'说是弱化手雷，其实只是单纯蓝明塞进一个瓶子里然后堵住。'",
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
        desc = "Gain {1} {DEFEND}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        flavour = "'A simple use of inertia can send a heavy object flying straight to your face.'",
        rarity = CARD_RARITY.COMMON,
        cost = 2,
        max_xp = 7,
        min_damage = 4,
        max_damage = 8,
        flags = CARD_FLAGS.MELEE,
        defend_amount = 4,
    },

    PC_ALAN_INERTIAL_IMPACT_plus =
    {
        name = "Inertial Impact on Vision",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_INERTIAL_IMPACT_plus2 =
    {
        name = "Weighted Inertial Impact",
        desc = "Gain {1} {DEFEND}.\n<#UPGRADE>{PC_ALAN_WEIGHTED} {2}: Gain 1 Action</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),self.weight_thresh)
        end,     
        flags = CARD_FLAGS.MELEE,
        action_bonus = 1,
        weight_thresh = 6,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
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

    PC_ALAN_SPARK_BOMB =
    {
        name = "Spark Bomb",
        icon = "battle/burner.tex",
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
        spark_amt = 4,
        OnPostResolve = function(self, battle, attack)
            if attack and attack.target then
                attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
            end
        end,
    },

    PC_ALAN_SPARK_BOMB_plus =
    {
        name = "Boosted Spark Bomb",
        min_damage = 4,
    },

    PC_ALAN_SPARK_BOMB_plus2 =
    {
        name = "Tactless Spark Bomb",
        min_damage = 5,
        max_damage = 7,
        desc = "Apply {1} {SPARK_RESERVE}.\n<#DOWNGRADE>Gain {2} {SPARK_RESERVE}</>.",
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
        desc = "Spend 2 {SPARK_RESERVE}: This card deals max damage.",
        flavour = "'A simple and effective solution—just be careful not to hit too hard.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 2,
        max_xp = 5,
        min_damage = 1,
        max_damage = 10,
        
        PreReq = function( self, battle )
            return self.owner:GetConditionStacks("SPARK_RESERVE") >= 2
        end,

        event_handlers = 
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                if self == card and (self.spark_spent or self.spark_spent == nil and self.owner:GetConditionStacks("SPARK_RESERVE") >= 2) then
                    dmgt:ModifyDamage( dmgt.max_damage, dmgt.max_damage, self )                       
                end
            end,
        },

        OnPreResolve = function( self, battle, attack )
            if self.owner:GetConditionStacks("SPARK_RESERVE") >= 2 then
                self.owner:RemoveCondition("SPARK_RESERVE", 2)
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
        max_damage = 15,
    },

    PC_ALAN_SPLASH_LUMIN =
    {
        name = "Splash Lumin",
        icon = "battle/reversal.tex",
        anim = "throw",
        desc = "Apply {lumin_burnt} equal to the damage dealt by this card.",
        flavour = "'A simple and effective solution—just be careful not to hit too hard.'",
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
        name = "Trip on Vision",
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
        icon = "battle/bolo_strike.tex",
        anim = "punch",
        flavour = "'A bit of extra weight is fine—as long as it keeps things under control.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.MELEE,
        cost = 3,
        max_xp = 3,
        min_damage = 7,
        max_damage = 12,
    },


    PC_ALAN_HEAVY_SUPPRESSION_plus =
    {
        name = "Heavy Suppression On Vision",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.REPLENISH
    },

    PC_ALAN_HEAVY_SUPPRESSION_plus2 =
    {
        name = "Weighted Heavy Suppression",
        desc = "<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Deal 3 bonus damage and gain 2 actions</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        weight_thresh = 8,
        action_bonus = 2,
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
    },     
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= self.weight_thresh then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,

    },

    PC_ALAN_TWO_THROWING_KNIVES =
    {
        name = "Two Throwing Knives",
        icon = "battle/daggerstorm.tex",
        anim = "throw",
        desc = "Attack 2 random enemies.",
        flavour = "'Remember to retrieve them after the fight.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.RANGED,
        cost = 2,
        max_xp = 6,
        min_damage = 5,
        max_damage = 9, 
        target_mod = TARGET_MOD.RANDOM1,
        target_count = 2,       
    },

    PC_ALAN_TWO_THROWING_KNIVES_plus =
    {
        name = "Three Throwing Knives",
        desc = "Attack <#UPGRADE>3</> random enemies.",
        cost = 3,
        target_count = 3,
    },

    PC_ALAN_TWO_THROWING_KNIVES_plus2 =
    {
        name = "One Throwing Knive",
        desc = "Attack <#DOWNGRADE>1</> random enemies.",
        cost = 1,
        target_count = 1,
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
        desc = "<#DOWNGRADE>{PC_ALAN_WEIGHTED}{1}</>: Deal <#UPGRADE>5</> bonus damage.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        weight_thresh = 6,
        action_bonus = 0,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost >= self.weight_thresh then
                    dmgt:AddDamage(5, 5, self)
                end
            end
        end,
    },
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
                    target:AddCondition("IMPAIR", self.impair_per_bleed, self)
                    target:AddCondition("WOUND", self.wound_amount, self)
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

    PC_ALAN_LUMIN_INFUSION =
    {
        name = "Lumin Infusion",
        icon = "battle/saber_grip.tex",
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
            attack:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end,
    },

    PC_ALAN_LUMIN_INFUSION_plus =
    {
        name = "Lumin Infusion on Vision",
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
        name = "Plan on Vision",
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.REPLENISH
    },

    PC_ALAN_WARM_UP =
    {
        name = "Warm-up",
        icon = "battle/lever.tex",
        anim = "taunt",
        desc = "Gain 2 {ADRENALINE} at the start of your next turn.",
        flavour = "'Can’t help it—that’s just how the old models are. Take it or leave it.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9, 
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("WARM_UP", 2, self) 
        end,
    },

    PC_ALAN_WARM_UP_plus =
    {
        name = "Weighted Warm-up",
        desc = "Gain 2 {ADRENALINE} at the start of your next turn.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Gain additional stack at next turn</>.",
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
            self.owner:AddCondition("WARM_UP", 2, self) 
        end,
    },

    PC_ALAN_WARM_UP_plus2 =
    {
        name = "Lightweight Warm-up",
        desc = "<#UPGRADE>{PC_ALAN_LIGHTWEIGHT}{1}: Gain 1 {ADRENALINE}</>.\nGain 2 {ADRENALINE} at the start of your next turn.", 
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.light_thresh)
        end,
        light_thresh = 3,
        OnPostResolve = function(self, battle, attack)
            self.owner:AddCondition("ADRENALINE", 1, self) 
            self.owner:AddCondition("WARM_UP", 2, self) 
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
        name = "Plate Armor on Vision",
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
        desc = "Gain <#UPGRADE>{1}</> {DEFEND}. Increase by {2} for each card played this turn.\n({3} cards played).",
        desc_fn = function(self, fmt_str)
            if self.engine then
                local total_defend = self.defend_amount + (self.defend_bonus * self.engine:CountCardsPlayed())
                return loc.format(fmt_str, total_defend, self.defend_bonus, self.engine:CountCardsPlayed())
            else
                return loc.format(fmt_str, self.defend_amount, self.defend_bonus, 0)
            end
        end,
        defend_amount = 4,
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

    PC_ALAN_INSPIRE =
    {
        name = "Inspire",
        icon = "battle/slam.tex",
        anim = "taunt",
        desc = "Apply {1} {ADRENALINE} to you and allies.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.adr_amt)
        end,
        flavour = "'The enemy is about to fall!'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        target_mod = TARGET_MOD.TEAM,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        cost = 1,
        max_xp = 7, 
        adr_amt = 2,
        OnPostResolve = function( self, battle, attack)
            attack:AddCondition("ADRENALINE", self.imp_amt)
        end,
    },

    PC_ALAN_INSPIRE_plus =
    {
        name = "Enduring Inspire",
        desc = "Apply {1} <#UPGRADE>{POWER}</> to you and allies.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.pwr_amt)
        end,
        pwr_amt = 1,
    },

    PC_ALAN_INSPIRE_plus2 =
    {
        name = "Boosted Inspire",
        desc = "Apply <#UPGRADE>{1}</> {ADRENALINE} to you and allies.",
        adr_amt = 3,
    },

    PC_ALAN_BE_PREPARED =
    {
        name = "Be Prepared",
        icon = "battle/fixed.tex",
        anim = "taunt",
        desc = "Apply {1} {fixed}",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.fixed_amt)
        end,
        flavour = "'Don't focus solely on attacking—leave yourself a way out.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.ENEMY,
        cost = 1,
        max_xp = 9, 
        fixed_amt = 1,
        OnPostResolve = function( self, battle, attack )
            local con = attack:AddCondition("fixed", self.fixed_amt, self)
            if con then
                con.applier = self.owner
            end
        end,
    },

    PC_ALAN_BE_PREPARED_plus =
    {
        name = "Boosted Be Prepared",
        desc = "Apply <#UPGRADE>{1}</> {fixed}",
        fixed_amt = 2,
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
        desc = "Draw 2 cards.",
        flavour = "'Always good to have a fallback.'",
        rarity = CARD_RARITY.COMMON,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.SELF,
        cost = 1,
        max_xp = 9, 
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(2)
        end,
    },

    PC_ALAN_BACKUP_WEAPON_plus =
    {
        name = "Lightweight Backup Weapon",
        desc = "Draw 2 cards.\n<#UPGRADE>{PC_ALAN_LIGHTWEIGHT}{1}: Draw additional card</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.light_thresh)
        end,
        light_thresh = 3,
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(2)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= self.light_thresh then
                battle:DrawCards(1)
            end
        end
    },

    PC_ALAN_BACKUP_WEAPON_plus2 =
    {
        name = "Weighted Backup Weapon",
        desc = "Draw 2 cards.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}: Gain 1 Action</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.weight_thresh)
        end,
        weight_thresh = 6,
        action_bonus = 1,
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(2)
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
        desc = "Gain 2 actions at next turn.\n<#UPGRADE>{PC_ALAN_WEIGHTED}{1}</>: Gain 1 bonus action at next turn.",
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
            self.owner:AddCondition("NEXT_TURN_CARD",1 , self)
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