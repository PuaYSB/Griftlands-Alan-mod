local negotiation_defs = require "negotiation/negotiation_defs"
local EVENT = negotiation_defs.EVENT
local CARD_FLAGS = negotiation_defs.CARD_FLAGS

local GRAFTS =
{
    PC_ALAN_FIDGET_TOY =
    {
        name = "Fidget Toy",
        flavour = "'Press it and watch the numbers tick up. Obviously, you can't take it to a casino as proof of a jackpot.'",
        desc = "Whenever you play 2 Hostility cards in a row, apply 1 {COMPOSURE} to a random argument.",
        img = engine.asset.Texture("icons/items/graft_bandit.tex"),
        rarity = CARD_RARITY.COMMON,
        composure_amt = 1,
        streak_count = 2,

        display_number = function( self )
            return self:GetCounter() or 0
        end,

        negotiation_modifier =
        {
            hidden = true,
            event_handlers = 
            {
                [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                    if card.negotiator == self.negotiator then
                        if CheckBits( card.flags, CARD_FLAGS.HOSTILE ) then
                            self.graft:IncrementCounter()
                            if self.graft:GetCounter() >= self.graft:GetDef().streak_count then
                                local targets = self.engine:CollectAlliedTargets(self.negotiator)
                                if #targets > 0 then
                                    local target = targets[math.random(#targets)]
                                    target:DeltaComposure(self.graft:GetDef().composure_amt, self)
                                    self.engine:BroadcastEvent( EVENT.GRAFT_TRIGGERED, self.graft )
                                end

                                self.graft:ResetCounter()
                            end
                            self:NotifyTriggered()

                        elseif (self.graft:GetCounter() or 0) > 0 then
                            self.graft:ResetCounter()
                            self:NotifyTriggered()
                        end
                    end
                end,
            },
        },
    },

    PC_ALAN_FIDGET_TOY_plus =
    {
        name = "Stone Fidget Toy",
        icon_override = "bandit_plus",
        desc = "Whenever you play 2 Hostility cards in a row, apply <#UPGRADE>2</> {COMPOSURE} to a random argument.",
        composure_amt = 2,
    },

    PC_ALAN_FAKE_COIN =
    {
        name = "Fake Coin",
        flavour = "'It might distract someone for maybe three seconds—sometimes only one.'",
        desc = "At the start of each turn, if your draw pile contains fewer or equal than 5 cards, move them to your discard.",
        img = engine.asset.Texture("icons/items/graft_weighted_coin.tex"),
        rarity = CARD_RARITY.COMMON,
        move_card_amt = 5,

        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.HAND_DRAWN ] = function( self, minigame )
                    local cards = ObtainWorkTable()
                    for i,card in minigame:GetDrawDeck():Cards() do
                        table.insert(cards, card)
                    end
                    if #cards <= self.graft:GetDef().move_card_amt then
                        for i,card in ipairs(cards) do
                            card:TransferCard(minigame:GetDiscardDeck())
                        end
                        minigame:BroadcastEvent( EVENT.GRAFT_TRIGGERED, self )
                    end
                end
            },
        },
    },

    PC_ALAN_FAKE_COIN_plus =
    {
        name = "Wide Fake Coin",
        icon_override = "slider_plus",
        desc = "At the start of each turn, if your draw pile contains fewer or equal than <#UPGRADE>8</> cards, move them to your discard.",
        move_card_amt = 8,
    },

    PC_ALAN_DISPOSABLE_SLIDER =
    {
        name = "Disposable Slider",
        flavour = "'Your free trial has expired. Please proceed to the nearest corporate counter to renew your subscription to continue usage.'",
        desc = "At the start of each negotiation, {IMPROVISE} a card from your draw pile.",
        img = engine.asset.Texture("icons/items/graft_slider.tex"),
        rarity = CARD_RARITY.COMMON,
        pool_size = 3,

        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.HAND_DRAWN ] = function( self, minigame )
                    local cards = ObtainWorkTable()
                    for i, card in minigame:GetDrawDeck():Cards() do
                        table.insert( cards, card )
                    end

                    cards = table.multipick(cards, self.graft:GetDef().pool_size)
                    minigame:BroadcastEvent( EVENT.GRAFT_TRIGGERED, self )
                    minigame:ImproviseCards(cards, 1, nil, nil, nil, self )
                    self.negotiator:RemoveModifier(self, self.stacks, self)
                end
            },
        },
    },

    PC_ALAN_DISPOSABLE_SLIDER_plus =
    {
        name = "Boosted Disposable Slider",
        icon_override = "slider_plus",
        desc = "At the start of each negotiation, <#UPGRADE>{IMPROVISE_PLUS}</> a card from your draw pile.",
        pool_size = 5,
    },

    PC_ALAN_SPRAY_BOTTLE =
    {
        name = "Spray Bottle",
        flavour = "'Give the area a quick spritz before you start. It helps distract everyone else, too.'",
        desc = "At the start of each negotiation, move up to 3 cards from your draw pile to your discard.",
        img = engine.asset.Texture("icons/items/graft_cranial_coolant.tex"),
        rarity = CARD_RARITY.COMMON,
        move_card_amt = 3,
        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.BEGIN_NEGOTIATION ] = function( self, minigame )
                    local cards = ObtainWorkTable()
                    for i,card in minigame:GetDrawDeck():Cards() do
                        table.insert(cards, card)
                        if #cards >= self.graft:GetDef().move_card_amt then
                            break
                        end
                    end
                    if #cards > 0 then
                        for i,card in ipairs(cards) do
                            card:TransferCard(minigame:GetDiscardDeck())
                        end
                    end
                    minigame:BroadcastEvent( EVENT.GRAFT_TRIGGERED, self )
                    self.negotiator:RemoveModifier(self, self.stacks, self)
                end
            },
        },
    },

    PC_ALAN_SPRAY_BOTTLE_plus =
    {
        name = "Boosted Disposable Slider",
        icon_override = "cranial_coolant_plus",
        desc = "At the start of each negotiation, move up to <#UPGRADE>5</> cards from your draw pile to your discard.",
        move_card_amt = 5,
    },

    PC_ALAN_DATAPAD =
    {
        name = "Datapad",
        flavour = "'Pretty handy for keeping track of things. The decorations are a bit flashy, though—hope you don't mind.'",
        desc = "At the start of each turn, gain 1 {PA_OBSERVATION_RECORD}.",
        img = engine.asset.Texture("icons/items/graft_chemical_regulator.tex"),
        rarity = CARD_RARITY.COMMON,
        basic_amt = 1,
        negotiation_modifier = 
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.BEGIN_TURN ] = function( self, minigame, negotiator )
                    if negotiator == self.negotiator then
                        minigame:GetPlayerNegotiator():AddModifier("PA_OBSERVATION_RECORD", self.graft:GetDef().basic_amt, self)
                        minigame:BroadcastEvent( EVENT.GRAFT_TRIGGERED, self.graft )
                    end
                end
            },
        },
    },

    PC_ALAN_DATAPAD_plus =
    {
        name = "Boosted Datapad",
        icon_override = "chemical_regulator_plus",
        desc = "At the start of each turn, gain <#UPGRADE>2</> {PA_OBSERVATION_RECORD}.",
        basic_amt = 2,
    },

    PC_ALAN_NECKLACE =
    {
        name = "Necklace",
        flavour = "'This effect feels incredibly familiar, though I have no clue why.'",
        desc = "When you have at least 3 friendly argument, all cards deal 2 bonus damage.",
        img = engine.asset.Texture("icons/items/graft_clan_chain.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        bonus_damage = 2,
        negotiation_modifier = 
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                    if source.owner == self.owner and is_instance( source, Negotiation.Card ) and source:IsAttack() then
                        local count = 0
                        for i, modifier in self.negotiator:Modifiers() do
                            if modifier.modifier_type == MODIFIER_TYPE.BOUNTY or modifier.modifier_type == MODIFIER_TYPE.ARGUMENT then
                                count = count + 1
                            end
                        end
                        if count >= 3 then
                            persuasion:AddPersuasion( self.graft:GetDef().bonus_damage, self.graft:GetDef().bonus_damage, self )
                        end
                    end
                end,
            }
        },
    },

    PC_ALAN_NECKLACE_plus =
    {
        name = "Boosted Necklace",
        icon_override = "clan_chain_plus",
        desc = "When you have at least 3 friendly argument, all cards deal <#UPGRADE>3</> bonus damage.",
        bonus_damage = 3,
    },

    PC_ALAN_HEADPHONES =
    {
        name = "Headphones",
        flavour = "'Helps block out a bit of the outside noise.'",
        desc = "At the start of each negotiation, Create 2 {PA_BREEZY}.",
        img = engine.asset.Texture("icons/items/graft_easy_listening.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        OnStartNegotiation = function(self, minigame)
            for i=1,2 do
                self.negotiator:CreateModifier("PA_BREEZY", 1, self)
            end
        end,
    },

    PC_ALAN_HEADPHONES_plus =
    {
        name = "Visionary Headphones",
        icon_override = "easy_listening_plus",
        desc = "At the start of each negotiation, Create 2 {PA_BREEZY} <#UPGRADE>and gain 3 {PA_CAUSE_AND_EFFECT}</>.",
        OnStartNegotiation = function(self, minigame)
            for i=1,2 do
                self.negotiator:CreateModifier("PA_BREEZY", 1, self)
            end
            self.negotiator:AddModifier("PA_CAUSE_AND_EFFECT", 3, self)
        end,
    },

    PC_ALAN_PROSTHETIC_TONGUE =
    {
        name = "Prosthetic Tongue",
        flavour = "'Heavily modified. You can't actually install it right now, but it can still talk on its own based on its programming.'",
        desc = "When you have drawn a total of 10 cards after your initial hand, deal 5 damage to all opponent arguments.",
        img = engine.asset.Texture("icons/items/graft_silver_tongue.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 5,
        max_persuasion = 5,
        display_number = function( self )
            return self:GetCounter() or 0
        end,
        negotiation_modifier =
        {
            hidden = true,
            min_persuasion = 5,
            max_persuasion = 5,
            target_enemy = TARGET_ANY_RESOLVE,
            target_mod = TARGET_MOD.TEAM,
            event_handlers =
            {
                [ EVENT.DRAW_CARD ] = function( self, engine, card, start_of_turn )
                    if not start_of_turn then
                        self.graft:IncrementCounter()
                        self:NotifyTriggered()
                    end
                end,

                [ EVENT.MODIFIER_CHANGED ] = function( self, modifier, negotiator )
                    if self.negotiator:GetModifierStacks("PA_DRAW_CARD_ALT") >= 10 then
                        self.min_persuasion = self.graft:GetDef().min_persuasion
                        self.max_persuasion = self.graft:GetDef().max_persuasion
                        self:ApplyPersuasion()
                        self.graft:ResetCounter()
                        self.engine:BroadcastEvent( EVENT.GRAFT_TRIGGERED, self.graft )
                        self.negotiator:RemoveModifier(self, self.stacks, self)
                    end
                end,
            }
        }
    },

    PC_ALAN_PROSTHETIC_TONGUE_plus =
    {
        name = "Boosted Prosthetic Tongue",
        icon_override = "silver_tongue_plus",
        desc = "When you have drawn a total of 10 cards after your initial hand, deal <#UPGRADE>7</> damage to all opponent arguments.",
        min_persuasion = 7,
        max_persuasion = 7,
    },

    PC_ALAN_REAL_TIME_TRANSLATOR =
    {
        name = "Real-time Translator",
        flavour = "'Of course it takes voice input! You can't exactly expect those big shots to type on a tablet the entire time, can you?!'",
        desc = "2 times per turn, whenever you play a basic card, gain 1 {PA_OBSERVATION_RECORD}.",
        img = engine.asset.Texture("icons/items/graft_scan_code.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        streak_count = 2,
        display_number = function( self )
            return self.userdata.counter or 0
        end,
        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                    if card.negotiator == self.negotiator then
                        if card.rarity == CARD_RARITY.BASIC and self.graft.userdata.counter < self.graft:GetDef().streak_count then
                            self.graft.userdata.counter = (self.graft.userdata.counter or 0) + 1
                            self:NotifyTriggered()
                            minigame:GetPlayerNegotiator():AddModifier("PA_OBSERVATION_RECORD", 1, self)
                        end
                    end
                end,

                [ EVENT.BEGIN_TURN ] = function( self, minigame, negotiator )
                    if negotiator == self.negotiator then
                        self.graft.userdata.counter = 0
                        self:NotifyTriggered()
                    end
                end,
            }
        }
    },

    PC_ALAN_REAL_TIME_TRANSLATOR_plus =
    {
        name = "Boosted Prosthetic Tongue",
        icon_override = "scan_code_plus",
        desc = "<#UPGRADE>4</> times per turn, whenever you play a basic card, gain 1 {PA_OBSERVATION_RECORD}.",
        streak_count = 4,
    },

    PC_ALAN_TWO_BOTTLES =
    {
        name = "Two Bottles",
        flavour = "'Chugging two bottles at once yields the best results. I mean, it tastes great.'",
        desc = "At the start of each negotiation, if your deck have card that have 'Evoke: Play a same-named cards', add a copy of that card to your discard.",
        img = engine.asset.Texture("icons/items/graft_two_fisted.tex"),
        rarity = CARD_RARITY.UNCOMMON,
        count = 1,
        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame, card )
                    local cards = ObtainWorkTable()
                    for i,card in minigame:GetDrawDeck():Cards() do
                        table.insert(cards, card)
                    end
                    for i,card in minigame:GetHandDeck():Cards() do
                        table.insert(cards, card)
                    end
                        for i,card in ipairs(cards) do
                            for i = 1, self.graft:GetDef().count do
                            if card.id == "PC_ALAN_BLUFF_plus2f" then
                                local copy = Negotiation.Card("PC_ALAN_BLUFF_plus2f", self.owner)
                                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))

                            elseif card.id == "PC_ALAN_STRAIGHT_FORWARD" then
                                local copy = Negotiation.Card("PC_ALAN_STRAIGHT_FORWARD", self.owner)
                                copy:ClearXP()
                                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))

                            elseif card.id == "PC_ALAN_STRAIGHT_FORWARD_plus" then
                                local copy = Negotiation.Card("PC_ALAN_STRAIGHT_FORWARD_plus", self.owner)
                                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))

                            elseif card.id == "PC_ALAN_STRAIGHT_FORWARD_plus2" then
                                local copy = Negotiation.Card("PC_ALAN_STRAIGHT_FORWARD_plus2", self.owner)
                                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))

                            elseif card.id == "PC_ALAN_ENDURANCE" then
                                local copy = Negotiation.Card("PC_ALAN_ENDURANCE", self.owner)
                                copy:ClearXP()
                                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))

                            elseif card.id == "PC_ALAN_ENDURANCE_plus" then
                                local copy = Negotiation.Card("PC_ALAN_ENDURANCE_plus", self.owner)
                                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))

                            elseif card.id == "PC_ALAN_ENDURANCE_plus2" then
                                local copy = Negotiation.Card("PC_ALAN_ENDURANCE_plus2", self.owner)
                                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))

                            elseif card.id == "PC_ALAN_SOPHISTRY_plus2" then
                                local copy = Negotiation.Card("PC_ALAN_SOPHISTRY_plus2", self.owner)
                                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))
                            end
                        end
                        self:NotifyTriggered()
                        self.negotiator:RemoveModifier(self, self.stacks, self)
                    end
                end
            }
        }
    },

    PC_ALAN_TWO_BOTTLES_plus =
    {
        name = "Boosted Two Bottles",
        icon_override = "two_fisted_plus",
        desc = "At the start of each negotiation, if your deck have card that have 'Evoke: Play a same-named cards', add <#UPGRADE>2 copies</> of that card to your discard.",
        count = 2,
    },

    PC_ALAN_AMULET =
    {
        name = "Amulet",
        flavour = "'I swear by this amulet to Hesh: you can absolutely trust me. If not, may Hesh smash me dead right on the beach!'",
        desc = "At the end of each turn, gain 1 {PA_TRUST}.",
        img = engine.asset.Texture("icons/items/graft_finely_crafted_amulet.tex"),
        rarity = CARD_RARITY.RARE,
        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.END_PLAYER_TURN ] = function( self, minigame)
                    self.negotiator:AddModifier("PA_TRUST", 1, self)
                end,
            },
        },
    },

    PC_ALAN_AMULET_plus =
    {
        name = "Boosted Amulet",
        icon_override = "finely_crafted_amulet_plus",
        desc = "At the end of each turn, gain 1 {PA_TRUST}.\n<#UPGRADE>At the start of each negotiation, gain 1 {PA_TRUST}</>.",
        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.END_PLAYER_TURN ] = function( self, minigame)
                    self.negotiator:AddModifier("PA_TRUST", 1, self)
                end,

                [ EVENT.BEGIN_NEGOTIATION ] = function( self, minigame)
                    self.negotiator:AddModifier("PA_TRUST", 1, self)
                end,
            },
        },
    },

    PC_ALAN_GANG_BADGE =
    {
        name = "Gang Badge",
        flavour = "'Stolen. Absolutely perfect for bluffing.'",
        desc = "At the end of each negotiation, insert a {card.known_thug} card with replenish into your draw pile.",
        img = engine.asset.Texture("icons/items/graft_gang_pendant.tex"),
        rarity = CARD_RARITY.RARE,
        count = 1,
        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.BEGIN_NEGOTIATION ] = function( self, minigame )
                    for i = 1, self.graft:GetDef().count do
                        local card = Negotiation.Card("known_thug", self.owner)
                        card:SetFlags( CARD_FLAGS.REPLENISH )
                        minigame:DealCard(card, minigame:GetDrawDeck())
                    end
                    minigame:GetPlayerNegotiator():RemoveModifier(self.id, self.stacks, self)
                end,
            },
        },
    },

    PC_ALAN_GANG_BADGE_plus =
    {
        name = "Boosted Gang Badge",
        icon_override = "gang_pendant_plus",
        desc = "At the end of each negotiation, insert <#UPGRADE>2 {card.known_thug} cards</> with replenish into your draw pile.",
        count = 2,
    },

    PC_ALAN_STICK =
    {
        name = "Stick",
        flavour = "'Extremely simple and straightforward, just like the time it came from.'",
        desc = "While you have at most 1 argument, all your card deal 50% bonus damage.",
        img = engine.asset.Texture("icons/items/graft_truncheon.tex"),
        rarity = CARD_RARITY.RARE,
        max = 1,
        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                    if source.owner == self.owner and is_instance( source, Negotiation.Card ) and source:IsAttack() then
                        local count = 0
                        for i, modifier in self.negotiator:Modifiers() do
                            if modifier.modifier_type == MODIFIER_TYPE.BOUNTY or modifier.modifier_type == MODIFIER_TYPE.ARGUMENT then
                                count = count + 1
                            end
                        end
                        if count <= self.graft:GetDef().max then
                            persuasion:ModifyPersuasion( math.round(persuasion.min_persuasion * 1.50), math.round(persuasion.max_persuasion * 1.50), self)
                        end
                    end
                end,
            },
        },
    },

    PC_ALAN_STICK_plus =
    {
        name = "Boosted Gang Badge",
        icon_override = "truncheon_plus",
        desc = "At the end of each negotiation, insert <#UPGRADE>2 {card.known_thug} cards</> with replenish into your draw pile.",
        max = 2,
    },

    PC_ALAN_NEURAL_BRAID =
    {
        name = "Defective Neural Braid",
        flavour = "'This takes a while to boot up. You might need to be a little patient.'",
        desc = "After this graft upgrade, Gain 1 action at the start of your turn.",
        img = engine.asset.Texture("icons/items/graft_neural_braid.tex"),
        rarity = CARD_RARITY.RARE,
        bonus_cost = 0,
        negotiation_modifier =
        {
            hidden = true,
            event_handlers =
            {
                [ EVENT.CALC_ACTIONS_PER_TURN ] = function( self, acc )
                    local cost = self.graft:GetDef().bonus_cost
                    if cost > 0 then
                        self.engine:BroadcastEvent( EVENT.GRAFT_TRIGGERED, self.graft )
                        acc:AddValue( cost )
                    end
                end,
            },
        },
    },

    PC_ALAN_NEURAL_BRAID_plus =
    {
        name = "Neural Braid",
        icon_override = "neural_braid_plus",
        desc = "<#UPGRADE>Gain 1 action at the start of your turn</>.",
        bonus_cost = 1,
    },

    PC_ALAN_HARD_LIQUOR =
    {
        name = "Hard Liquor",
        flavour = "'The first sip might be hard to stomach, but once you've had enough, you'll start to appreciate the flavor.'",
        desc = "Gain 1 action at the start of your turn. At the start of each negotiation, lose 2 action.",
        img = engine.asset.Texture("icons/items/graft_speed_shot.tex"),
        rarity = CARD_RARITY.BOSS,
        card_draw = 0,
        negotiation_modifier =
        {
            hidden = true,
            before_trigger = true,
            event_handlers =
            {
                [ EVENT.CALC_ACTIONS_PER_TURN ] = function( self, acc )
                    self.engine:BroadcastEvent( EVENT.GRAFT_TRIGGERED, self.graft )

                    if self.before_trigger then
                        acc:AddValue( -2 )
                        self.before_trigger = false
                    end

                    acc:AddValue( 1 )
                end,

                [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                    local draw = self.graft:GetDef().card_draw
                    if draw > 0 then minigame:DrawCards(draw) end
                end,
            },
        },
    },

    PC_ALAN_HARD_LIQUOR_plus =
    {
        name = "Visionary Hard Liquor",
        icon_override = "speed_shot_plus",
        desc = "Gain 1 action <#UPGRADE>and draw a card</> at the start of your turn. At the start of each negotiation, lose 2 action.",
        card_draw = 1,
    },
}

---------------------------------------------------------------------------------------------

for i, id, graft in sorted_pairs( GRAFTS ) do
    graft.card_defs = negotiation_defs
    graft.type = GRAFT_TYPE.NEGOTIATION
    graft.series = graft.series or "ALAN"
    Content.AddGraft( id, graft )
end

