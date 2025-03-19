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
    name = "火花储备",
    desc = "至多拥有15层，当拥有15层火花储备时便立即使层数清零并使承受体力上限20%的伤害。",
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
    name = "蓝明储备",
    desc = "你的下一次攻击会对目标施加{1}层{lumin_burnt}以及{1}点{defend}.",
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
        [ BATTLE_EVENT.ON_HIT ] = function(self, card, hit)
            if card.owner == self.owner and card:IsAttackCard() then
                local stacks = self.stacks or 0
                if stacks > 0 then
                    local defend_amount = math.ceil(stacks / 5)

                    hit.target:AddCondition("lumin_burnt", stacks, self)

                    self.owner:AddCondition("defend", defend_amount, self)

                    self.owner:RemoveCondition(self.id)
                end
            end
        end
    }
}

}

for id, def in pairs( CONDITIONS ) do
    Content.AddBattleCondition( id, def )
end

local CARDS =
{
    deckers_rig = 
    {
        name = "Decker's Rig",
        rarity = CARD_RARITY.RARE,
        icon = "battle/sucker_punch.tex",
        cost = 1,
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.CONSUME,

        target_type = TARGET_TYPE.SELF,

        features =
        {
            EVASION = 3,
        }
    },

    berserk =
    {
        name = "准备躲闪",
        icon = "battle/feint.tex",
        anim = "step_back",
        flavour = "注意一下敌人，似乎是要准备攻击了。",
        desc = "施加 {1} {DEFEND}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateDefendText( self.defend_amount ))
        end,
        defend_amount = 4,
        OnPostResolve = function(self, battle, attack)
            attack:AddCondition("DEFEND", self.defend_amount, self)
        end,
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.SKILL,
        target_type = TARGET_TYPE.FRIENDLY_OR_SELF,
        cost = 0,
        max_xp = 6,
        action_bonus = 1,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= 2 then
                self.defend_amount = 7
            end
        end,
    },

        --[[
        name = "丢空瓶",
        icon = "LOSTPASSAGE:textures/vanish.png",
        anim = "bottle_throw_quick",
        desc = "施加 {1} {lumin_burnt}.",
        flavour = "我最好。",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.RANGED,
        cost = 0,
        max_xp = 4,
        min_damage = 3,
        max_damage = 3,
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.lumin_burnt_amt )
        end,

        lumin_burnt_amt = 5,

        OnPostResolve = function( self, battle, attack )
            attack:AddCondition("lumin_burnt", self.lumin_burnt_amt, self)
       end
    },

    berserk_plus2a =
    {
        name = "一次性丢空瓶",
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.CONSUME,
        min_damage = 10,
        max_damage = 10,
    },

    berserk_plus2b =
    {
        name = "强力丢空瓶",
        flags = CARD_FLAGS.RANGED ,
        min_damage = 4,
        max_damage = 4,
    },

    berserk_plus2c =
    {
        name = "火花丢空瓶",
        flags = CARD_FLAGS.RANGED ,
        desc = "<#UPGRADE>施加 {1} {SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "SPARK_RESERVE", self.spark_amt ))
        end,
        OnPostResolve = function(self, battle, attack)
            if attack and attack.target then
                attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
        end
    end,
        min_damage = 3,
        max_damage = 3,
        spark_amt = 10,
    },
    ]]--
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
    SPARK_RESERVE =
    {
        name = "火花储备",
        desc = "至多拥有15层，当拥有15层火花储备时便立即使层数清零并使承受体力上限20%的伤害",
    },
}

for id, data in pairs( FEATURES ) do
    local def = BattleFeatureDef(id, data)
    Content.AddBattleCardFeature(id, def)
end