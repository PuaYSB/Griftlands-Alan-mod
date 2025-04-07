local battle_defs = require "battle/battle_defs"

local CARD_FLAGS = battle_defs.CARD_FLAGS
local BATTLE_EVENT = battle_defs.BATTLE_EVENT

--------------------------------------------------------------------



local BATTLE_GRAFTS =
{
    PC_ALAN_LUMIN_FLASK = 
    {
        name = "Lumin Flask",
        flavour = "'The bug inside is dead—perfect for giving the enemy a little scare when you splash it.'",
        desc = "Start battle with {LUMIN_RESERVE 3}.",
        rarity = CARD_RARITY.COMMON,
        lumin_res_amt = 3,
        img = engine.asset.Texture("icons/items/graft_lumin_relic.tex"),
        OnActivateFighter = function(self, fighter)
            fighter:AddCondition( "LUMIN_RESERVE", self:GetDef().lumin_res_amt )
        end,
    },

    PC_ALAN_LUMIN_FLASK_plus =
    {
        name = "Boosted Lumin Flask",
        icon_override = "lumin_relic_plus",
        desc = "Start battle with <#UPGRADE>{LUMIN_RESERVE 5}</>.",
        lumin_res_amt = 5,
    },

    PC_ALAN_SHUFFLE_STEP =
    {
        name = "Shuffle Step",
        flavour = "'There’s another version of this implant that suits me much better.'",
        desc = "Whenever you play a 0-cost card, gain 1 {DEFEND}.",
        rarity = CARD_RARITY.COMMON,
        img = engine.asset.Texture("icons/items/graft_shuffle_step.tex"),
        defend_amt = 1,
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.END_RESOLVE ] = function( self, battle, card )
                    if card.owner == self.owner and card.cost == 0 then
                        self.owner:AddCondition("DEFEND", self.graft:GetDef().defend_amt, self)
                    end
                end
            },
        },
    },

    PC_ALAN_SHUFFLE_STEP_plus =
    {
        name = "Wide Shuffle Step",
        icon_override = "shuffle_step_plus",
        desc = "Whenever you play a 0-cost card <#UPGRADE>or a 1-cost card</>, gain 1 {DEFEND}.",
        defend_amt = 1,
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.END_RESOLVE ] = function( self, battle, card )
                    if card.owner == self.owner and (card.cost == 0 or card.cost == 1) then
                        self.owner:AddCondition("DEFEND", self.graft:GetDef().defend_amt, self)
                    end
                end
            },
        },
    },

    PC_ALAN_PROTECTIVE_GLOVES =
    {
        name = "Protective Gloves",
        flavour = "'With these on, you can haul cargo and throw punches all the same.'",
        desc = "At the beginning of your turn, if the total cost of cards on your hand at least 6, Gain {ADRENALINE 2}.",
        rarity = CARD_RARITY.COMMON,
        img = engine.asset.Texture("icons/items/graft_predictive_brawling.tex"),
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle, card )
                local total_cost = 0
                for _, hand_card in battle:GetHandDeck():Cards() do
                    local cost = battle:CalculateActionCost(hand_card)
                    total_cost = total_cost + cost
                end

                if total_cost >= 6 then
                    self.owner:AddCondition("ADRENALINE", 2, self)
                end
                end
            },
        },
    },

    PC_ALAN_PROTECTIVE_GLOVES_plus =
    {
        name = "Protective Gloves",
        icon_override = "predictive_brawling_plus",
        desc = "At the beginning of your turn, if the total cost of cards on your hand at least 6, Gain <#UPGRADE>{ADRENALINE 3}</>.",
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle, card )
                local total_cost = 0
                for _, hand_card in battle:GetHandDeck():Cards() do
                    local cost = battle:CalculateActionCost(hand_card)
                    total_cost = total_cost + cost
                end

                if total_cost >= 6 then
                    self.owner:AddCondition("ADRENALINE", 3, self)
                end
                end
            },
        },
    },

    PC_ALAN_CLOAK =
    {
        name = "Cloak",
        flavour = "'This cloak can deflect some attacks on its own, though the trigger’s a bit sluggish.'",
        desc = "At the end of your turn, gain 6 {DEFEND} if you have not any {DEFEND}.",
        rarity = CARD_RARITY.COMMON,
        img = engine.asset.Texture("icons/items/graft_dark_cowl.tex"),
        defend_amt = 6,
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.END_PLAYER_TURN ] = function( self, battle )
                    if not self.owner:HasCondition("DEFEND") then
                        self.owner:AddCondition("DEFEND", self.graft:GetDef().defend_amt, self)
                        battle:BroadcastEvent( BATTLE_EVENT.GRAFT_TRIGGERED, self.graft )
                    end
                end
            },
        },
    },

    PC_ALAN_CLOAK_plus =
    {
        name = "Stone Cloak",
        icon_override = "dark_cowl_plus",
        desc = "At the end of your turn, gain <#UPGRADE>10</> {DEFEND} if you have not any {DEFEND}.",
        defend_amt = 10,
    },

    PC_ALAN_SPARK_POUCH =
    {
        name = "Spark Pouch",
        desc = "Your first attack each battle applies and gains 2 {SPARK_RESERVE}.",
        flavour = "'This helps you think more clearly about your next move.'",
        img = engine.asset.Texture("icons/items/graft_flash_powder.tex"),
        rarity = CARD_RARITY.COMMON,
        battle_condition =
        {
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.POST_RESOLVE ] = function( self, battle, attack )
                    if attack.attacker == self.owner and attack.card:IsAttackCard() then
                        for i, hit in attack:Hits() do
                            hit.target:AddCondition("SPARK_RESERVE", 2, attack.card)
                            self.owner:AddCondition("SPARK_RESERVE", 2, attack.card)
                        end
                        battle:BroadcastEvent( BATTLE_EVENT.GRAFT_TRIGGERED, self.graft )
                        self.owner:RemoveCondition( self.id )
                    end
                end,
            },
        },
    },

    PC_ALAN_SPARK_POUCH_plus =
    {
        name = "Softened Spark Pouch",
        icon_override = "flash_powder_plus",
        desc = "Your first attack each battle <#UPGRADE>applies</> 2 {SPARK_RESERVE}.",
        battle_condition =
        {
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.POST_RESOLVE ] = function( self, battle, attack )
                    if attack.attacker == self.owner and attack.card:IsAttackCard() then
                        for i, hit in attack:Hits() do
                            hit.target:AddCondition("SPARK_RESERVE", 2, attack.card)
                        end
                        battle:BroadcastEvent( BATTLE_EVENT.GRAFT_TRIGGERED, self.graft )
                        self.owner:RemoveCondition( self.id )
                    end
                end,
            },
        },
    },

    PC_ALAN_SPLITTING_SHRAPNEL =
    {
        name = "Splitting Shrapnel",
        flavour = "'Make sure to remove those spikes before loading, they're just for show.'",
        desc = "At the beginning of your turn, if the total cost of cards on your hand at most 3, Apply {WOUND 1} to all enemies.",
        rarity = CARD_RARITY.COMMON,
        img = engine.asset.Texture("icons/items/graft_splintershot.tex"),
        wound_amt = 1,
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle, card, fighter )
                local total_cost = 0
                for _, hand_card in battle:GetHandDeck():Cards() do
                    local cost = battle:CalculateActionCost(hand_card)
                    total_cost = total_cost + cost
                end

                if total_cost <= 3 then
                    for _, enemy in ipairs(self.owner:GetEnemyTeam():GetFighters()) do
                        enemy:AddCondition("WOUND", self.graft:GetDef().wound_amt, self)
                    end
                end
                end
            },
        },
    },

    PC_ALAN_SPLITTING_SHRAPNEL_plus =
    {
        name = "Boosted Splitting Shrapnel",
        icon_override = "splintershot_plus",
        desc = "At the beginning of your turn, if the total cost of cards on your hand at most 3, Apply <#UPGRADE>{WOUND 2}</> to all enemies.",
        wound_amt = 2,
    },

    PC_ALAN_STABILIZER =
    {
        name = "Stabilizer",
        desc = "At the start of each turn, discard up to 1 cards and draw that many new cards.",
        flavour = "'This helps you think more clearly about your next move.'",
        img = engine.asset.Texture("icons/items/graft_second_opinion.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        max_cards = 1,
        battle_condition = 
        {
            hidden = true,
            event_priorities =
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = 10, -- happens AFTER warp_vial changes
            },

            event_handlers = 
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle )
                    local discarded_cards = battle:DiscardCards(0, self.graft:GetDef().max_cards, self)
                    if #discarded_cards > 0 then
                        battle:DrawCards(#discarded_cards)
                    end
                end
            },
        },
    },

    PC_ALAN_STABILIZER_plus =
    {
        name = "Wide Stabilizer",
        icon_override = "second_opinion_plus",
        desc = "At the start of each battle, discard up to <#UPGRADE>2</> cards and draw that many new cards.",
        max_cards = 2,
    },

    PC_ALAN_KNUCKLE_BLADE =
    {
        name = "Knuckle Blade",
        desc = "Apply 1 {BLEED} whenever you hit an enemy with an attack.",
        flavour = "'Careful, this one's meant for slashing, not pretending you're in a street brawl.'",
        img = engine.asset.Texture("icons/items/graft_heirloom_knucks.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        battle_condition = 
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.ON_HIT ] = function( self, battle, attack, hit )
                    if attack.card:IsAttackCard() and attack.attacker == self.owner then
                        if not hit.evaded then
                            hit.target:AddCondition( "BLEED", 1, attack.card )
                        end
                    end
                end,
            }
        },
    },

    PC_ALAN_KNUCKLE_BLADE_plus =
    {
        name = "Stone Knuckle Blade",
        icon_override = "heirloom_knucks_plus",
        desc = "Apply 1 {BLEED} <#UPGRADE>and Gain 1 {DEFEND}</> whenever you hit an enemy with an attack.",
        battle_condition = 
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.ON_HIT ] = function( self, battle, attack, hit )
                    if attack.card:IsAttackCard() and attack.attacker == self.owner then
                        if not hit.evaded then
                            hit.target:AddCondition( "BLEED", 1, attack.card )
                            self.owner:AddCondition( "DEFEND", 1 , self)
                        end
                    end
                end,
            }
        },
    },

    PC_ALAN_SPRING_KNIFE =
    {
        name = "Spring Knife",
        desc = "All attacks gain +2 to maximum damage.",
        flavour = "'Trigger it after landing a hit to make that wound go even deeper.'",
        img = engine.asset.Texture("icons/items/graft_first_blood.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        battle_condition = 
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                dmgt:AddDamage( 0, 2, self )
                end
            },
        },
    },

    PC_ALAN_SPRING_KNIFE_plus =
    {
        name = "Boosted Spring Knife",
        icon_override = "first_blood_plus",
        desc = "All attacks gain <#UPGRADE>+3</> to maximum damage <#UPGRADE>and +1 to minimum damage</>.",
        battle_condition = 
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                dmgt:AddDamage( 1, 3, self )
                end
            },
        },
    },

    PC_ALAN_STIMULANT =
    {
        name = "Stimulant",
        desc = "Whenever you play a card that it costs at least 3, gain 2 {ADRENALINE}.",
        flavour = "'Effectively boosts your potential—assuming you’re ready to unlock it.'",
        img = engine.asset.Texture("icons/items/graft_recycler.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        battle_condition = 
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.END_RESOLVE ] = function( self, battle, card )
                    if card.cost >= 3 then
                        self.owner:AddCondition("ADRENALINE", 2, self)
                    end
                end
            },
        },
    },

    PC_ALAN_STIMULANT_plus =
    {
        name = "Wide Stimulant",
        icon_override = "recycler_plus",
        desc = "Whenever you play a card that it costs at least <#UPGRADE>2</>, gain 2 {ADRENALINE}.",
        battle_condition = 
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.END_RESOLVE ] = function( self, battle, card )
                    if card.cost >= 2 then
                        self.owner:AddCondition("ADRENALINE", 2, self)
                    end
                end
            },
        },
    },

    PC_ALAN_SURVEYOR =
    {
        name = "Surveyor",
        desc = "Your attacks deal 2 bonus damage to targets with {lumin_burnt}.",
        flavour = "'Effectively boosts your potential—assuming you’re ready to unlock it.'",
        img = engine.asset.Texture("icons/items/graft_forecaster.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        bonus_damage = 2,
        battle_condition =
        {   
            event_handlers = 
            {
                [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                    if card.owner == self.owner and card:IsAttackCard() and target and target:HasCondition("lumin_burnt") then
                        self.bonus_damage = self.bonus_damage or self.graft:GetDef().bonus_damage or 1
                        dmgt:AddDamage(self.bonus_damage, self.bonus_damage, self)
                    end
                end
            },
        },
    },

    PC_ALAN_SURVEYOR_plus =
    {
        name = "Boosted Surveyor",
        icon_override = "forecaster_plus",
        desc = "Your attacks deal <#UPGRADE>4</> bonus damage to targets with {lumin_burnt}.",
        bonus_damage = 4,
    },

    PC_ALAN_TRENCH_KNIFE =
    {
        name = "Trench Knife",
        desc = "Whenever you gain {DEFEND} three times, gain 4 {RIPOSTE}.",
        flavour = "'Easy to grip and always ready for a sharp counter.'",
        img = engine.asset.Texture("icons/items/graft_trench_knife.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        riposte_amt = 4,
        display_number = function( self )
            return self.userdata.counter or 0
        end,

        battle_condition =
        {   
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.CONDITION_ADDED ] = function( self, battle, condition, stacks, source )
                if condition.id == "DEFEND" and source and source.owner == self.owner then
                    self.graft:IncrementCounter()

                    if self.graft:GetCounter() >= 3 then
                        self.owner:AddCondition("RIPOSTE", self.graft:GetDef().riposte_amt, self)
                        battle:BroadcastEvent( BATTLE_EVENT.GRAFT_TRIGGERED, self.graft )
                        self.graft:ResetCounter()
                    end
                    battle:BroadcastEvent( BATTLE_EVENT.REFRESH_GRAFTS )
                end
                end
            },
        },
    },

    PC_ALAN_TRENCH_KNIFE_plus =
    {
        name = "Spined Surveyor",
        icon_override = "trench_knife_plus",
        desc = "Whenever you gain {DEFEND} three times, gain <#UPGRADE>6</> {RIPOSTE}.",
        riposte_amt = 6,
    },

    PC_ALAN_TOTEM =
    {
        name = "Totem",
        desc = "Whenever you gain {LUMIN_RESERVE}, gain 4 {DEFEND}.",
        flavour = "'Once a symbol of a heretical Hesh cult branch, now it just reacts to Lumin.'",
        img = engine.asset.Texture("icons/items/graft_totem.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        defend_amt = 4,
        battle_condition =
        {   
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.CONDITION_ADDED ] = function( self, battle, condition, stacks, source )
                if condition.id == "LUMIN_RESERVE" and source and source.owner == self.owner then
                    self.owner:AddCondition("DEFEND", self.graft:GetDef().defend_amt, self)
                end
                end
            },
        },
    },

    PC_ALAN_TOTEM_plus =
    {
        name = "Stone Totem",
        icon_override = "totem_plus",
        desc = "Whenever you gain {LUMIN_RESERVE}, gain <#UPGRADE>6</> {DEFEND}.",
        defend_amt = 6,
    },

    PC_ALAN_BULLET_POUCH =
    {
        name = "Bullet Pouch",
        desc = "Apply {SPARK_RESERVE 1} to a random enemy at the beginning of your turn.",
        flavour = "'Packed with Spark rounds. Don’t drop it.'",
        img = engine.asset.Texture("icons/items/graft_spare_magazine.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        battle_condition =
        {   
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.BEGIN_TURN ] = function( self, fighter )
                    if fighter == self.owner then
                        local target_fighters = {}
                        fighter.battle:CollectRandomTargets( target_fighters, self.owner:GetEnemyTeam().fighters, 1 )

                        for i=1, #target_fighters do
                            local target = target_fighters[i]
                            target:AddCondition("SPARK_RESERVE", 1, self)
                        end
                    end
                end,
            },
        },
    },

    PC_ALAN_BULLET_POUCH_plus =
    {
        name = "Tactless Bullet Pouch",
        icon_override = "spare_magazine_plus",
        desc = "Apply <#UPGRADE>{SPARK_RESERVE 3}</> to a random enemy <#DOWNGRADE>and gain {SPARK_RESERVE 1}</> at the beginning of your turn.",
        battle_condition =
        {   
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.BEGIN_TURN ] = function( self, fighter )
                    if fighter == self.owner then
                        local target_fighters = {}
                        fighter.battle:CollectRandomTargets( target_fighters, self.owner:GetEnemyTeam().fighters, 1 )

                        for i=1, #target_fighters do
                            local target = target_fighters[i]
                            target:AddCondition("SPARK_RESERVE", 3, self)
                            self.owner:AddCondition("SPARK_RESERVE", 1, self)
                        end
                    end
                end,
            },
        },
    },

    PC_ALAN_SPARK_PUMP =
    {
        name = "Spark Pump",
        desc = "At the beginning of your turn, if you have at least {SPARK_RESERVE 2}, Spend {SPARK_RESERVE 2} and gain {ADRENALINE 2}.",
        flavour = "'Powered by Spark, it delivers critical bursts of strength when it counts most.'",
        img = engine.asset.Texture("icons/items/graft_critical_pump.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        adr_amt = 2,
        battle_condition =
        {   
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, fighter )
                if self.owner:GetConditionStacks("SPARK_RESERVE") >= 2 then
                    self.owner:RemoveCondition("SPARK_RESERVE", 2, self)
                    self.owner:AddCondition("ADRENALINE", self.graft:GetDef().adr_amt, self)
                end
                end
            },
        },
    },

    PC_ALAN_SPARK_PUMP_plus =
    {
        name = "Boosted Spark Pump",
        icon_override = "critical_pump_plus",
        desc = "At the beginning of your turn, if you have at least {SPARK_RESERVE 2}, Spend {SPARK_RESERVE 2} and gain <#UPGRADE>{ADRENALINE 3}</>.",
        adr_amt = 3,
    },

    PC_ALAN_LUMIN_RESERVE =
    {
        name = "Lumin Reserve",
        desc = "At the start of each turn, gain {LUMIN_RESERVE 1}.",
        flavour = "'Sealed vials of Lumin, just smash one when you need it.'",
        img = engine.asset.Texture("icons/items/graft_lucky_strike.tex"),
        rarity = CARD_RARITY.RARE,
        lumin_res_amt = 1,
        battle_condition =
        {   
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, fighter )
                self.owner:AddCondition( "LUMIN_RESERVE", self.graft:GetDef().lumin_res_amt )
                end
            },
        },
    },

    PC_ALAN_LUMIN_RESERVE_plus =
    {
        name = "Boosted Lumin Reserve",
        icon_override = "lucky_strike_plus",
        desc = "At the start of each turn, gain <#UPGRADE>{LUMIN_RESERVE 2}</>.",
        lumin_res_amt = 2,
    },

    PC_ALAN_SPIKED_KNUCKLE =
    {
        name = "Spiked Knuckle",
        desc = "Your 0-cost cards deals 2 bonus damage.",
        flavour = "'Not just for Derrick fighting pits, any underground fight pit’s likely seen a few of these.'",
        img = engine.asset.Texture("icons/items/graft_nailed_glove.tex"),
        rarity = CARD_RARITY.RARE,
        bonus_damage = 2,
        battle_condition =
        {   
            hidden = true,
            event_handlers = 
            {
                [ BATTLE_EVENT.CALC_DAMAGE ] = function( self, card, target, dmgt )
                    if card.owner == self.owner and card.cost == 0 then
                        self.bonus_damage = self.bonus_damage or self.graft:GetDef().bonus_damage or 1
                        dmgt:AddDamage(self.bonus_damage, self.bonus_damage, self)
                    end
                end
            },
        },
    },

    PC_ALAN_SPIKED_KNUCKLE_plus =
    {
        name = "Boosted Spiked Knuckle",
        icon_override = "nailed_glove_plus",
        desc = "Your 0-cost cards deals <#UPGRADE>4</> bonus damage.",
        bonus_damage = 4,
    },

    PC_ALAN_DUPLICATOR =
    {
        name = "Duplicator",
        desc = "At the start of each turn, insert 1 {PC_ALAN_QUICK_THROW} into your hand.",
        flavour = "'Technically it can copy other things, but mass-produced knives are just cheaper to make.'",
        img = engine.asset.Texture("icons/items/graft_synapse_board.tex"),
        rarity = CARD_RARITY.RARE,
        num_cards = 1,
        OnActivateFighter = function(self, fighter)
            fighter:AddCondition( "PA_THROWING_KNIFE_REPLICAROR", self:GetDef().num_cards )
        end,
    },

    PC_ALAN_DUPLICATOR_plus =
    {
        name = "Boosted Duplicator",
        icon_override = "synapse_board_plus",
        desc = "At the start of each turn, insert <#UPGRADE>2</> {PC_ALAN_QUICK_THROW} into your hand.",
        num_cards = 2,
    },

    PC_ALAN_BRACER =
    {
        name = "Bracer",
        flavour = "'Protects your wrist, and cracks a few skulls while it's at it.'",
        desc = "At the beginning of your turn, if the total cost of cards on your hand at least 8, Gain 1 action.",
        rarity = CARD_RARITY.RARE,
        img = engine.asset.Texture("icons/items/graft_counter_band.tex"),
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle, card )
                local total_cost = 0
                for _, hand_card in battle:GetHandDeck():Cards() do
                    local cost = battle:CalculateActionCost(hand_card)
                    total_cost = total_cost + cost
                end

                if total_cost >= 8 then
                    self.battle:ModifyActionCount(1)
                    battle:BroadcastEvent( BATTLE_EVENT.GRAFT_TRIGGERED, self.graft )
                end
                end
            },
        },
    },

    PC_ALAN_BRACER_plus =
    {
        name = "Wide Bracer",
        icon_override = "counter_band_plus",
        desc = "At the beginning of your turn, if the total cost of cards on your hand at least <#UPGRADE>7</>, Gain 1 action.",
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, battle, card )
                local total_cost = 0
                for _, hand_card in battle:GetHandDeck():Cards() do
                    local cost = battle:CalculateActionCost(hand_card)
                    total_cost = total_cost + cost
                end

                if total_cost >= 7 then
                    self.battle:ModifyActionCount(1)
                    battle:BroadcastEvent( BATTLE_EVENT.GRAFT_TRIGGERED, self.graft )
                end
                end
            },
        },
    },

    PC_ALAN_HAZARD_BULB =
    {
        name = "Hazard Bulb",
        flavour = "'A relic from the Spark Barons’ early days. The real miracle is that it hasn’t exploded yet.'",
        desc = "At the start of each turn, gain {SPARK_RESERVE 2} and {POWER 1}.",
        rarity = CARD_RARITY.RARE,
        img = engine.asset.Texture("icons/items/graft_dangerous_bulb.tex"),
        pwr_amt = 1,
        spark_amt = 2,
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.BEGIN_PLAYER_TURN ] = function( self, fighter )
                self.owner:AddCondition( "SPARK_RESERVE", self.graft:GetDef().spark_amt, self )
                self.owner:AddCondition( "POWER", self.graft:GetDef().pwr_amt, self )
                end
            },
        },
    },

    PC_ALAN_HAZARD_BULB_plus =
    {
        name = "Tactless Hazard Bulb",
        icon_override = "dangerous_bulb_plus",
        desc = "At the start of each turn, gain <#DOWNGRADE>{SPARK_RESERVE 3}</> and <#UPGRADE>{POWER 2}</>.",
        pwr_amt = 2,
        spark_amt = 3,
    },

    PC_ALAN_PROTOTYPR_CHARGER =
    {
        name = "Prototype Charger",
        flavour = "'An older model, phased out for producing too much waste too fast.'",
        desc = "Gain 1 action at the start of your turn. Whenever you shuffle your deck, insert 1 {PC_ALAN_MEDICINE_d} into your draw pile and 1 into your hand deck.",
        rarity = CARD_RARITY.BOSS,
        img = engine.asset.Texture("icons/items/graft_perpetual_recycler.tex"),
        card_draw = 0,
        battle_condition =
        {
            hidden = true,
            event_handlers =
            {
                [ BATTLE_EVENT.BEGIN_TURN ] = function( self, fighter )
                    if fighter == self.owner then
                        if self.owner.player_controlled then
                            self.battle:ModifyActionCount( self.stacks )
                            local draw = self.graft:GetDef().card_draw
                            if draw > 0 then self.battle:DrawCards(draw) end
                            self.battle:BroadcastEvent( BATTLE_EVENT.GRAFT_TRIGGERED, self.graft )
                        end
                    end
                end,

                [ BATTLE_EVENT.SHUFFLE_DISCARDS ] = function( self, battle, num_cards )
                local battle = self.battle or self.owner.battle
                local cards = {}
                for i = 1, 2 do
                    local incepted_card = Battle.Card( "PC_ALAN_MEDICINE_d", self:GetOwner() )
                    incepted_card.auto_deal = true
                    table.insert( cards, incepted_card )
                end
                battle:DealCards( cards )
                end
            },
        },
    },

    PC_ALAN_PROTOTYPR_CHARGER_plus =
    {
        name = "Visionary Prototype Charger",
        icon_override = "perpetual_recycler_plus",
        desc = "Gain 1 action <#UPGRADE>and draw a card</> at the start of your turn. Whenever you shuffle your deck, insert 1 {PC_ALAN_MEDICINE_d} into your draw pile and 1 into your hand deck.",
        card_draw = 1,
    },
}


---------------------------------------------------------------------------------------------

for i, id, graft in sorted_pairs( BATTLE_GRAFTS ) do
    graft.card_defs = battle_defs
    graft.type = GRAFT_TYPE.COMBAT
    graft.series = graft.series or "SHEL"
    Content.AddGraft( id, graft )
end
