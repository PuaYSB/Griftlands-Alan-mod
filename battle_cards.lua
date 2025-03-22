local battle_defs = require "battle/battle_defs"
local CARD_FLAGS = battle_defs.CARD_FLAGS
local EVENT = battle_defs.EVENT

local BATTLE_EVENT = ExtendEnum( battle_defs.EVENT,
{
    "SPARK_RESERVE",
})

local function CalculateTotalAndMaxCost(engine, self)
    local total_cost = 0
    local max_cost = 0
    
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
    desc = "Up to 15 stacks. At 15 stacks, clear all stack and dealing 20% max HP damage to the bearer.",
    desc_fn = function(self, fmt_str)
        return loc.format(fmt_str, self.stacks)
    end,

    icon = "battle/conditions/resonance.tex",
    ctype = CTYPE.DEBUFF,
    apply_sound = "event:/sfx/battle/status/system/Status_Buff_Attack",
    target_type = TARGET_TYPE.ANY,
    max_stacks = 15,

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
        name = "Stone Punch",
                flags = CARD_FLAGS.MELEE,
        desc = "<#UPGRADE>Apply {1} {DEFEND}</>.",
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
        flavour = "'As a bilebroker, I'd better prepare more bottles, whether for storing or throwing.'",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.RANGED,
        cost = 0,
        max_xp = 6,
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
        desc = "Apply {1} {DEFEND}\n<#UPGRADE>Gain {2} {SPARK_RESERVE}\nSpend 1 {SPARK_RESERVE}: Gain an additional {1} {DEFEND}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),CalculateConditionText(self, "SPARK_RESERVE", self.spark_amt))
        end,        
        flags = CARD_FLAGS.SKILL,
        OnPostResolve = function(self, battle, attack)
            if self.owner:GetConditionStacks("SPARK_RESERVE") > 0 then
                self.owner:RemoveCondition("SPARK_RESERVE", 1, self)
                self.defend_amount = 8
            end

            self.owner:AddCondition("DEFEND", self.defend_amount, self)
        end,
        spark_amt = 2,
        defend_amount = 4,
    },

    PC_ALAN_READY_FOR_DODGE_plus2e =
    {
        name = "Weighted Ready for Dodge",
        desc = "Apply {1} {DEFEND}\n<#UPGRADE>{PC_ALAN_WEIGHTED}{2}: Gain 1 Action</>.",   
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),self.weight_thresh)
        end,     
        flags = CARD_FLAGS.SKILL,
        action_bonus = 1,
        weight_thresh = 5,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= 5 then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_READY_FOR_DODGE_plus2f =
    {
        name = "Lightweight Ready for Dodge",
        desc = "Apply {1}{DEFEND}\n<#UPGRADE>{PC_ALAN_LIGHTWEIGHT}{2}: Apply additional 3 {DEFEND}</>.",  
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str,self:CalculateDefendText( self.defend_amount ),self.light_thresh)
        end,      
        flags = CARD_FLAGS.SKILL,
        light_thresh = 2,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= 2 then
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
        desc = "Gain {1} {SPARK_RESERVE}\nApply {2} {SPARK_RESERVE}.",
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
        desc = "Spend 1 {SPARK_RESERVE}: Deal additional 4 damage.",
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
                if total_cost >= 3 and max_cost >= 0 then
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
        desc = "{PC_ALAN_LIGHTWEIGHT}{1}: deal additional 3 damage.",
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
                if total_cost <= 3 then
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
        desc = "Gain {1} {SPARK_RESERVE}\nApply {1} {SPARK_RESERVE}.",
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