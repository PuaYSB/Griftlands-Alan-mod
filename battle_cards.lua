local battle_defs = require "battle/battle_defs"
local CARD_FLAGS = battle_defs.CARD_FLAGS
local EVENT = battle_defs.EVENT

local BATTLE_EVENT = ExtendEnum( battle_defs.EVENT,
{
    "SPARK_RESERVE",
})

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
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.stacks)
        end,

        icon = "battle/conditions/resonance.tex",
        ctype = CTYPE.DEBUFF,

        apply_sound = "event:/sfx/battle/status/system/Status_Buff_Attack",
        target_type = TARGET_TYPE.ENEMY,
        max_stacks = 15,

        OnApply = function(self)
            if not self.stacks then
                self.stacks = 0
            end
        end,

        event_handlers = 
        {
    [ BATTLE_EVENT.CONDITION_ADDED ] = function(self, owner, condition_id, stacks, battle)
        if condition_id == "SPARK_RESERVE" then
            self.stacks = math.min((self.stacks or 0) + stacks, self.max_stacks)

            if self.stacks >= self.max_stacks then
                if owner then
                    local max_health = owner:GetMaxHealth()
                    local damage = math.floor(max_health * 0.2)
                    owner:TakeDamage(damage)
                end

                owner:RemoveCondition("SPARK_RESERVE", self.stacks, self)
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
        icon = "battle/back_stretch.tex",
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
        name = "丢空瓶",
        icon = "LOSTPASSAGE:textures/vanish.png",
        anim = "bottle_throw_quick",
        desc = "施加 {SPARK_RESERVE}{10}",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText( self, "SPARK_RESERVE", self.spark_amt ))
        end,
        flavour = "我最好。",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.RANGED,
        cost = 1,
        max_xp = 4,
        min_damage = 3,
        max_damage = 3,
        spark_amt = 10,
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
        name = "远见丢空瓶",
        desc = "<#UPGRADE>抽取1张书页.</>",
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(1)
        end,
        min_damage = 3,
        max_damage = 3,
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