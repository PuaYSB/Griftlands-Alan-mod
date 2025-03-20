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
    desc = "你的下一次攻击会对目标施加{1}层{lumin_burnt}以及{2}点{DEFEND}.",
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
        name = "拳打",
        icon = "battle/sucker_punch.tex",
        anim = "punch",
        flavour = "'没人规定我不能用拳头。'",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.MELEE,
        cost = 1,
        max_xp = 5,
        min_damage = 2,
        max_damage = 5,
    },

    PC_ALAN_PUNCH_plus2a =
    {
        name = "一次性拳打",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.CONSUME,
        min_damage = 8,
        max_damage = 10,
    },

    PC_ALAN_PUNCH_plus2b =
    {
        name = "强力拳打",
        flags = CARD_FLAGS.MELEE,
        min_damage = 4,
        max_damage = 5,
    },

    PC_ALAN_PUNCH_plus2c =
    {
        name = "透彻拳打",
        flags = CARD_FLAGS.MELEE | CARD_FLAGS.EXPEND,
        min_damage = 5,
        max_damage = 8,
    },

    PC_ALAN_PUNCH_plus2d =
    {
        name = "黯淡拳打",
        flags = CARD_FLAGS.MELEE ,
        cost = 0,
        min_damage = 4,
        max_damage = 5,
    },

    PC_ALAN_PUNCH_plus2e =
    {
        name = "远见拳打",
        flags = CARD_FLAGS.MELEE ,
        desc = "<#UPGRADE>抽取1张书页.</>",
        OnPostResolve = function( self, battle, attack)
            battle:DrawCards(1)
        end,
        min_damage = 2,
        max_damage = 5,
    },

    PC_ALAN_PUNCH_plus2f =
    {
        name = "火花拳打",
        flags = CARD_FLAGS.MELEE ,
        desc = "<#UPGRADE>施加{1}{SPARK_RESERVE}.",
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

    PC_ALAN_THROW_BOTTLE =
    {
        name = "丢空瓶",
        icon = "battle/right_in_the_face.tex",
        anim = "throw",
        flavour = "'作为一个胆汁贩子，我最好得准备多点瓶子，不管是用来装还是用来丢。'",
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.RANGED,
        cost = 0,
        max_xp = 6,
        min_damage = 3,
        max_damage = 3,
    },

    PC_ALAN_THROW_BOTTLE_plus2a =
    {
        name = "增强丢空瓶",
        flags = CARD_FLAGS.RANGED ,
        min_damage = 4,
        max_damage = 4,
    },

    PC_ALAN_THROW_BOTTLE_plus2b =
    {
        name = "一次性丢空瓶",
        flags = CARD_FLAGS.RANGED | CARD_FLAGS.CONSUME,
        min_damage = 10,
        max_damage = 10,
    },

    PC_ALAN_THROW_BOTTLE_plus2c =
    {
        name = "远见丢空瓶",
        flags = CARD_FLAGS.RANGED ,
        desc = "<#UPGRADE>抽取1张书页.",
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
        name = "沉重丢空瓶",
        flags = CARD_FLAGS.RANGED ,
        cost = 2,
        min_damage = 10,
        max_damage = 10,
    },

    PC_ALAN_THROW_BOTTLE_plus2e =
    {
        name = "蓝明丢空瓶",
        flags = CARD_FLAGS.RANGED ,
        desc = "<#UPGRADE>施加{1}{lumin_burnt}.",
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
        name = "重量丢空瓶",
        flags = CARD_FLAGS.RANGED ,
        desc = "<#UPGRADE>重量 3：造成两倍与手牌中花费最高的牌的花费的额外伤害.",
        min_damage = 3,
        max_damage = 3,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost >= 3 and max_cost > 0 then
                    local extra_damage = max_cost * 2
                    dmgt:AddDamage(extra_damage, extra_damage, self)
                end
            end
        end
    }
    },    

    PC_ALAN_READY_FOR_DODGE =
    {
        name = "准备躲闪",
        icon = "battle/feint.tex",
        anim = "step_back",
        flavour = "'注意一下敌人，似乎是要准备攻击了。'",
        desc = "施加{1}{DEFEND}.",
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
        name = "增强准备闪躲",
        desc = "<#UPGRADE>施加{1}{DEFEND}</>.",        
        flags = CARD_FLAGS.SKILL,
        defend_amount = 6,
    },

    PC_ALAN_READY_FOR_DODGE_plus2b =
    {
        name = "透彻准备闪躲",
        desc = "施加{1}{DEFEND}和<#UPGRADE>{1}{EVASION}</>.",       
        flags = CARD_FLAGS.SKILL | CARD_FLAGS.EXPEND,
        OnPostResolve = function( self, battle, attack )
            attack:AddCondition( "DEFEND", self.defend_amount, self )
            self.owner:AddCondition("EVASION", 1, self)
        end,
    },

    PC_ALAN_READY_FOR_DODGE_plus2c =
    {
        name = "蓝明准备闪躲",
        desc = "<#UPGRADE>施加{1}{DEFEND}和<#UPGRADE>{2}{LUMIN_RESERVE}</>.",        
        flags = CARD_FLAGS.SKILL,
        OnPostResolve = function(self, battle, attack)
            attack:AddCondition("DEFEND", self.defend_amount, self)
            attack:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
        end,
        lumin_res_amt = 10,
    },

    PC_ALAN_READY_FOR_DODGE_plus2d =
    {
        name = "火花准备闪躲",
        desc = "施加{1}{DEFEND}，<#UPGRADE>获得{1}{SPARK_RESERVE},花费1{SPARK_RESERVE}：使施加的{DEFEND}+4.</>.",        
        flags = CARD_FLAGS.SKILL,
        spark_amt = 2,
        OnPostResolve = function(self, battle, attack)
            if self.owner:GetConditionStacks("SPARK_RESERVE") > 0 then
                self.owner:RemoveCondition("SPARK_RESERVE", 1, self)
                self.defend_amount = 8
            end

            self.owner:AddCondition("DEFEND", self.defend_amount, self)
        end,
    },

    PC_ALAN_READY_FOR_DODGE_plus2e =
    {
        name = "重量准备闪躲",
        desc = "Apply{1}{DEFEND}，<#UPGRADE>重量 5：获得1点行动点</>.",        
        flags = CARD_FLAGS.SKILL,
        action_bonus = 1,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost >= 5 then
                self.engine:ModifyActionCount(self.action_bonus)
            end
        end,
    },

    PC_ALAN_READY_FOR_DODGE_plus2f =
    {
        name = "轻量准备闪躲",
        desc = "Apply{1}{DEFEND},轻量 3：额外施加3防御</>.",        
        flags = CARD_FLAGS.SKILL,
        OnPreResolve = function(self, battle)
            local total_cost, _ = CalculateTotalAndMaxCost(self.engine, self)
            if total_cost <= 2 then
                self.defend_amount = 7
            end
        end,
    },

    PC_ALAN_CHEMICAL_RESERVES =
    {
        name = "燃料储备",
        icon = "battle/auxiliary.tex",
        flavour = "'在决定好之前，我最好两者都准备一点，虽然双方应该都会有意见。'",
        desc = "手牌中加入{PC_ALAN_LUMIN}或者{PC_ALAN_SPARK}.",
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
        name = "蓝明",
        icon = "battle/lumin_canister.tex",
        anim = "taunt",
        flavour = "'蓝明，黑石教的人寻神的时候找到的，性质相对稳定，不过其伤害不容忽视。'",
        desc = "获得{1}{LUMIN_RESERVE}.",
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
        name = "火花",
        icon = "battle/sparkys_oppressor_cell.tex",
        flavour = "'火花，初次在口水湖周围被发现，不清楚是否易燃，但是能肯定其容易爆炸。'",
        anim = "throw",
        desc = "对目标施加{1}{SPARK_RESERVE}.",
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
        name = "蓝明储备",
        icon = "battle/lumin_canister.tex",
        flavour = "'还是囤积蓝明吧，我那地方可禁不起天天爆炸。'",
        desc = "手牌中加入{PC_ALAN_LUMIN_2a}或者{PC_ALAN_LUMIN_2b}.",
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
        name = "蓝明涂抹",
        icon = "battle/spear_head.tex",
        flavour = "'把它涂在武器上，然后轻轻地括一下敌人，然后你就能看到敌人开始求饶了。'",
        desc = "获得{1}{LUMIN_RESERVE}和{2}{DEFEND}.",
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
        name = "蓝明药剂",
        icon = "battle/status_lumin_burn.tex",
        flavour = "'或者你嫌麻烦的话可以直接扔过去就好了。'",
        anim = "throw",
        desc = "施加{1}{lumin_burnt}.",
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
        name = "火花储备",
        icon = "battle/sparkys_oppressor_cell.tex",
        anim = "taunt",
        flavour = "'还是用火花吧，我设备的密封性没那么好。'",
        desc = "手牌中加入{PC_ALAN_SPARK_2a}或者{PC_ALAN_SPARK_2b}.",
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
        name = "火花投掷",
        icon = "battle/twist.tex",
        anim = "throw",
        flavour = "'总之就是扔过去，然后等着它爆。'",
        desc = "获得{1}{SPARK_RESERVE},施加{2}{SPARK_RESERVE}.",
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
        name = "火花助推",
        icon = "battle/overloaded_spark_hammer_hatch.tex",
        anim = "throw",
        flavour = "'火花最好随拿随用，不然放一块太久了容易起反应。'",
        desc = "花费1{SPARK_RESERVE}:造成的伤害+4.",
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
        name = "药剂袋",
        icon = "battle/ammo_pouch.tex",
        desc = "从特殊牌堆中{IMPROVISE}一张牌.",
        flavour = "'药剂随身携带，这是个常识。'",
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
        name = "高级药剂袋",
        desc = "从<#UPGRADE>高级</>特殊牌堆中{IMPROVISE}一张牌.",
        pool_cards = {"PC_ALAN_MEDICINE_a_upgraded", "PC_ALAN_MEDICINE_b_upgraded", "PC_ALAN_MEDICINE_c_upgraded", "PC_ALAN_MEDICINE_d_upgraded", "PC_ALAN_MEDICINE_e_upgraded", "PC_ALAN_MEDICINE_f_upgraded", "PC_ALAN_MEDICINE_g_upgraded", "PC_ALAN_MEDICINE_h_upgraded"},
    },

    PC_ALAN_MEDICINE_BAG_plus2 = 
    {
        name = "增强药剂袋",
        desc = "从特殊牌堆中<#UPGRADE>{IMPROVISE_PLUS}</>一张牌.",
        pool_size = 5,
    },

    PC_ALAN_MEDICINE_a = 
    {
        name = "小型联合药剂",
        icon = "battle/bombard_bonded_elixir.tex",
        anim = "throw",
        flavour = "'为了便携而舍弃了剂量，不过无伤大雅。'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        min_damage = 1,
        max_damage = 2,
        features =
        {
            WOUND = 1,
        },
    },

    PC_ALAN_MEDICINE_a_upgraded =
    {
        name = "增强小型联合药剂",
        icon = "battle/bombard_bonded_elixir.tex",
        anim = "throw",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        min_damage = 1,
        max_damage = 2,
        features =
        {
            WOUND = 2,
        },
    },

    PC_ALAN_MEDICINE_b = 
    {
        name = "超负荷瓶",
        icon = "battle/bombard_noxious_vial.tex",    
        anim = "throw",
        desc = "重量 3：造成与手牌中花费最高的牌的花费的额外伤害.",
        flavour = "'为了保证能爆，我特地灌入大量气体'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        min_damage = 3,
        max_damage = 3,
        event_handlers =
        {
            [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
            if card == self then
                local total_cost, max_cost = CalculateTotalAndMaxCost(self.engine, self)
                if total_cost >= 3 and max_cost > 0 then
                    local extra_damage = max_cost
                    dmgt:AddDamage(extra_damage, extra_damage, self)
                end
            end
        end
    }

    },

    PC_ALAN_MEDICINE_b_upgraded = 
    {
        name = "增强超负荷瓶",
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
                if total_cost >= 3 and max_cost > 0 then
                    local extra_damage = max_cost
                    dmgt:AddDamage(extra_damage, extra_damage, self)
                end
            end
        end
    }   
    },

    PC_ALAN_MEDICINE_c = 
    {
        name = "弱化酊",
        icon = "battle/tincture.tex",
        flavour = "'至少现在可以一天服用多次了'",
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
        name = "黯淡弱化酊",
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
        name = "垃圾",
        icon = "battle/flekfis_junk.tex",
        anim = "taunt",
        flavour = "'......抱歉忘记扔垃圾了，现在扔给你'",
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
        name = "沉重垃圾",
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
        name = "灰尘弹",
        icon = "battle/gunsmoke.tex",
        anim = "throw",
        flavour = "'我承认这主意有那么点蠢。'",
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
        name = "增强灰尘弹",
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
        name = "应急太渍胶囊",
        icon = "battle/rugs_tidepool_pods.tex",    
        anim = "throw",
        desc = "轻量 3：造成的伤害+3.",
        flavour = "'主要是应急用（顺带提醒一下主要是用来丢不是用来吃）。'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        min_damage = 3,
        max_damage = 3,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
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

    PC_ALAN_MEDICINE_f_upgraded = 
    {
        name = "增强应急太渍胶囊",
        icon = "battle/rugs_bombard_noxious_vial.tex",    
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
                if total_cost >= 3 and max_cost > 0 then
                    dmgt:AddDamage(3, 3, self)
                end
            end
        end,
    }   
    },

    PC_ALAN_MEDICINE_g = 
    {
        name = "弱化蓝明手雷",
        icon = "battle/lumin_grenade.tex",
        anim = "throw",
        desc = "施加{1}{lumin_burnt}.",
        desc_fn = function(self, fmt_str)
        return loc.format(fmt_str, CalculateConditionText(self, "lumin_burnt", self.lumin_burnt_amt))
    end,
        flavour = "'我承认这主意有那么点蠢。'",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        max_xp = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        lumin_res_amt = 3,
        OnPostResolve = function(self, battle, attack)
            attack:AddCondition("lumin_burnt", self.lumin_res_amt, self)
        end,
    },

    PC_ALAN_MEDICINE_g_upgraded =
    {
        name = "增强弱化蓝明手雷",
        icon = "battle/lumin_grenade.tex",
        anim = "throw",
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        flags = CARD_FLAGS.EXPEND | CARD_FLAGS.RANGED,
        lumin_res_amt = 5,
    },

    PC_ALAN_MEDICINE_h = 
    {
        name = "火花混合物",
        icon = "battle/spark_grenade.tex",
        anim = "throw",
        desc = "获得{1}{SPARK_RESERVE},施加{1}{SPARK_RESERVE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, CalculateConditionText(self, "SPARK_RESERVE", self.spark_amt))
        end,
        flavour = "'我承认这主意有那么点蠢。'",
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
        name = "增强火花混合物",
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
    SPARK_RESERVE =
    {
        name = "火花储备",
        desc = "至多拥有15层，当拥有15层火花储备时便立即使层数清零并使承受体力上限20%的伤害",
    },

    LUMIN_RESERVE =
    {
        name = "蓝明储备",
        desc = "你的下一次攻击会对目标施加{1}层{lumin_burnt}以及{2}点{DEFEND}."
    }
}

for id, data in pairs( FEATURES ) do
    local def = BattleFeatureDef(id, data)
    Content.AddBattleCardFeature(id, def)
end