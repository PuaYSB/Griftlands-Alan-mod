local negotiation_defs = require "negotiation/negotiation_defs"
local CARD_FLAGS = negotiation_defs.CARD_FLAGS
local EVENT = negotiation_defs.EVENT

AddOpinionEvent("GENUINE", 
{
    delta = OPINION_DELTAS.OPINION_UP,
    txt = "Your genuine demeanor has touched their heart.",
})

AddOpinionEvent("RUDE", 
{
    delta = OPINION_DELTAS.OPINION_DOWN,
    txt = "Think you're being too rude.",
})


local function CountArguments(self)
    local count = 0
    for i, modifier in self.negotiator:Modifiers() do
        if modifier:GetResolve() ~= nil and modifier.modifier_type ~= MODIFIER_TYPE.CORE and modifier.modifier_type ~= MODIFIER_TYPE.INCEPTION then
            count = count + 1
        end
    end
    return count
end

local function DiscardPileCount(self)
    return self.engine:GetDeck( DECK_TYPE.DISCARDS ):CountCards() or 0
end

local function IsCardUnique(self)
    if not (self.owner and self.negotiator) then
        return true
    end

    local decks_to_check = {
        self.engine:GetDeck( DECK_TYPE.DISCARDS ),
        self.engine:GetDeck( DECK_TYPE.DRAW ),
        self.engine:GetDeck( DECK_TYPE.IN_HAND )
    }

    local self_core_id = self.base_id or self.id
    if not self_core_id then 
        return true 
    end
    for _, deck in ipairs(decks_to_check) do
        local cards = type(deck) == "table" and (deck.cards or deck) or {}
        for _, check_card in ipairs(cards) do
            if check_card ~= self then
                local check_core_id = check_card.base_id or check_card.id
                if check_core_id == self_core_id then
                    return false 
                end
            end
        end
    end

    return true
end

local function CountPositiveRelationsCPR(self)
    local rel = self.negotiator and self.negotiator.agent.social_connections
    local loved = 0
    local liked = 0
    if rel then
        loved = rel:GetNumberOfConnections(RELATIONSHIP.LOVED)
        liked = rel:GetNumberOfConnections(RELATIONSHIP.LIKED)
        return (loved + liked)
    end
    return 0
end

local function CountNegativeRelationsCNR(self)
    local rel = self.negotiator and self.negotiator.agent.social_connections
    local hated = 0
    local disliked = 0
    if rel then
        disliked = rel:GetNumberOfConnections(RELATIONSHIP.DISLIKED)
        hated = rel:GetNumberOfConnections(RELATIONSHIP.HATED)
        return (disliked + hated)
    end
    return 0
end

local MODIFIERS =
{
    PC_ALAN_CORE =
    {
        name = "Reorganize",
        desc = "Whenever you shuffle your deck, Gain 2 compure and deal 2 damage to a random opponent argument.",
        modifier_type = MODIFIER_TYPE.CORE,
        icon = "negotiation/modifiers/all_business.tex",
        icon_force_flip = true,
        target_enemy = TARGET_ANY_RESOLVE,
        target_mod = TARGET_MOD.RANDOM1,
        event_handlers = 
        {
            [ EVENT.BEGIN_NEGOTIATION ] = function( self, source, negotiator, minigame, target, agent )
                self.negotiator:AddModifier( "PA_DRAW_CARD", 1 )
            end,

            [ EVENT.SHUFFLE_DISCARDS ] = function( self, num_cards )
                self.negotiator:DeltaComposure( 2, self )
                self.min_persuasion, self.max_persuasion = 2, 2
                self.engine:ApplyPersuasion( self )
                self.min_persuasion, self.max_persuasion = nil, nil
            end
        },
    },

    PA_BASIC_SKILLS = 
    {
        name = "Basic skills",
        desc = "Basic cards deal <#HILITE>{1}</> bonus damage and apply additional <#HILITE>{2}</> {COMPOSURE}.\nThe latter increases by 1 every 3 stacks.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks, math.floor(self.stacks / 3) )
        end,
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        icon = "negotiation/modifiers/deadline.tex",
        sound = "event:/sfx/battle/cards/neg/create_argument/vulnerability",
        max_resolve = 2,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source.owner == self.owner and is_instance( source, Negotiation.Card ) and source.rarity == CARD_RARITY.BASIC then
                    if persuasion.preview or self.engine:IsResolving( source ) then
                        persuasion:AddPersuasion( self.stacks, self.stacks, self )
                    end
                end
            end,

            [ EVENT.CALC_DELTA_COMPOSURE ] = function( self, composure_acc, target, source )
                if source and source.negotiator == self.negotiator and is_instance(source, Negotiation.Card) and source.rarity == CARD_RARITY.BASIC and composure_acc.value > 0 then
                    composure_acc:AddValue(math.floor(self.stacks / 3), self)
                end
            end,
        },
    },

    PA_DRAW_CARD =
    {
        hidden = true,
        max_stacks = 999,
        event_handlers = 
        {
            [ EVENT.DRAW_CARD ] = function( self, engine, card, start_of_turn )
                if not start_of_turn then
                    self.negotiator:AddModifier( self, 1 )
                    self.negotiator:AddModifier( "PA_DRAW_CARD_ALT", 1 )
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                self.negotiator:RemoveModifier(self.id, self.stacks - 1, self)
            end,
        },
    },

    PA_DRAW_CARD_ALT =
    {
        hidden = true,
        max_stacks = 999,
    },

    PA_RAGE =
    {
        hidden = true,
        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source.owner == self.owner and is_instance( source, Negotiation.Card ) and (source.id == "PC_ALAN_RAGE" or source.base_id == "PC_ALAN_RAGE" ) then
                    if persuasion.preview or self.engine:IsResolving( source ) then
                        persuasion:ModifyPersuasion( persuasion.min_persuasion + (self.stacks * 3), persuasion.max_persuasion + (self.stacks * 3), self )
                    end
                end
            end,

            [ EVENT.CALC_ACTION_COST ] = function( self, cost_acc, source, target )
                if source.owner == self.owner and is_instance( source, Negotiation.Card ) and (source.id == "PC_ALAN_RAGE" or source.base_id == "PC_ALAN_RAGE" ) then
                    cost_acc:AddValue( self.stacks , self )
                end
            end,
        },
    },

    PA_SHUFFLE =
    {
        name = "Shuffle",
        desc = "Whenever you shuffle your deck, deal {1} damage to all opponent arguments.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks )
        end,
        icon = "negotiation/modifiers/stacked_deck.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        target_enemy = TARGET_ANY_RESOLVE,
        target_mod = TARGET_MOD.TEAM,
        max_resolve = 3,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        OnApply = function( self )
            self:PrepareTurn()
        end,
        event_handlers = 
        {
            [ EVENT.SHUFFLE_DISCARDS ] = function( self, num_cards )
                self.min_persuasion = self.stacks
                self.max_persuasion = self.stacks
                self:ApplyPersuasion()
                self.min_persuasion = nil
                self.max_persuasion = nil
            end
        },
    },

    PA_BREEZY =
    {
        name = "Breezy",
        desc = "At the end of your turn, give <#HILITE>{1}</> {COMPOSURE} to a random friendly argument.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks )
        end,
        icon = "negotiation/modifiers/airtight.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 4,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        target_self = TARGET_ANY_RESOLVE,
        event_handlers =
        {
            [ EVENT.END_PLAYER_TURN ] = function( self, minigame )
                local target = minigame:CollectPrimaryTarget(self)
                target:DeltaComposure(self.stacks, self)
                self:ClearTarget()
            end,
        },
    },

    PA_NONSTOP_DEBATE =
    {
        name = "Nonstop Debate",
        desc = "Increase the maximum damage of {PC_ALAN_DISCUSS} by {1}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks * 4 )
        end,
        icon = "negotiation/modifiers/formality.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 3,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source.owner == self.owner and is_instance( source, Negotiation.Card ) and (source.id == "PC_ALAN_DISCUSS" or source.base_id == "PC_ALAN_DISCUSS") then
                    if persuasion.preview or self.engine:IsResolving( source ) then
                        persuasion:AddPersuasion( 0, self.stacks * 4, self )
                    end
                end
            end,
        },
    },

    PA_ANTI_BASIC_SKILLS =
    {
        name = "Snap out of it",
        max_resolve = 2,
        sound = "event:/sfx/battle/cards/neg/create_argument/setup",
        icon = "negotiation/modifiers/go_between.tex",
        desc = "At the end of your turn, lose {1} {PA_BASIC_SKILLS}, then remove this argument.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks or 1)
        end,
        event_handlers =
        {
            [ EVENT.END_PLAYER_TURN ] = function( self, minigame )
                self.negotiator:RemoveModifier("PA_BASIC_SKILLS", self.stacks, self)
                self.negotiator:RemoveModifier( self )
            end,
        },
    },

    PA_STALL =
    {
        hidden = true,
            event_handlers =
            {
                [ EVENT.BEGIN_TURN ] = function( self, minigame, negotiator )
                    if negotiator == self.negotiator then
                        minigame:ShuffleDiscardToDraw()
                        minigame:DrawCards(2)
                        minigame:ModifyActionCount( 2, self )
                        self.negotiator:RemoveModifier(self.id, self.stacks, self)
                    end
                end,
            }
    },

    PA_APPLAUSE = 
    {
        name = "Applause",
        max_resolve = 4,
        sound = "event:/sfx/battle/cards/neg/create_argument/setup",
        icon = "negotiation/modifiers/setup.tex",
        desc = "When you shuffle your deck, deal {1} damage to random argument, then destroy this argument.",
        target_enemy = TARGET_ANY_RESOLVE,
        target_mod = TARGET_MOD.RANDOM1,
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks or 1)
        end,
        event_handlers =
        {
            [ EVENT.SHUFFLE_DISCARDS ] = function( self, num_cards )
                self.min_persuasion = self.stacks
                self.max_persuasion = self.stacks
                self:ApplyPersuasion()
                self.negotiator:DestroyModifier(self, self)
            end
        },
    },

    PC_ALAN_HOT_COFFEE =
    {
        hidden = true,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source.owner == self.owner and is_instance( source, Negotiation.Card ) then
                    if persuasion.preview or self.engine:IsResolving( source ) then
                        local min = persuasion.min_persuasion + self.stacks
                        local max = persuasion.max_persuasion + self.stacks
                        persuasion:ModifyPersuasion( min, max, self )
                    end
                end
            end,
        }
    },

    PA_TURN_THE_TABLES =
    {
        name = "Turn the Tables",
        desc = "Whenever you play a card, deal {1} damage to a random opponent argument.\nLose all stacks at the end of the turn.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks * 3 )
        end,
        icon = "negotiation/modifiers/quip.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 1,
        target_enemy = TARGET_ANY_RESOLVE,
        target_mod = TARGET_MOD.RANDOM1,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        event_handlers =
        {
            [ EVENT.PRE_RESOLVE ] = function( self, minigame, card )
                if card:GetNegotiator() == self.negotiator then
                    self.min_persuasion = 3 * self.stacks
                    self.max_persuasion = 3 * self.stacks
                    self:ApplyPersuasion()
                    self.min_persuasion = nil
                    self.max_persuasion = nil
                end
            end,

            [ EVENT.END_PLAYER_TURN ] = function( self, minigame )
                self.negotiator:RemoveModifier( "PA_TURN_THE_TABLES", self.stacks )
            end,
        }
    },

    PA_PUMP = 
    {
        name = "Pump",
        desc = "Whenever you play a card, move up to {1} cards from your draw pile to your discard.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks )
        end,
        icon = "negotiation/modifiers/obscurity.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 3,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        event_handlers =
        {
            [ EVENT.PRE_RESOLVE ] = function( self, minigame, card )
                if card:GetNegotiator() == self.negotiator then
                    local cards = ObtainWorkTable()
                        for i,card in minigame:GetDrawDeck():Cards() do
                                table.insert(cards, card)
                                if #cards >= self.stacks then
                                    break
                                end
                            end
                    if #cards > 0 then
                        for i,card in ipairs(cards) do
                            card:TransferCard(minigame:GetDiscardDeck())
                        end
                    end
                end
            end
        },
    },

    PA_BROKEN_RECORD =
    {
        name = "Broken Record",
        desc = "For every 7 cards played, Add a copy of 7th card to your discards.",
        icon = "negotiation/modifiers/bidder.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 4,
        sound = "event:/sfx/battle/cards/neg/create_argument/interrogate",
        event_handlers =
        {
            [ EVENT.PRE_RESOLVE ] = function( self, minigame, card )
                if card.owner == self.owner then
                    self.negotiator:AddModifier( self, 1 )
                end

                if self.negotiator:GetModifierStacks(self.id) > 7 and card.owner == self.owner then
                    local copy = card:Duplicate()
                    minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))
                    self.negotiator:RemoveModifier(self.id, self.stacks - 1, self)  
                end
            end
        }
    },

    PA_CAUSE_AND_EFFECT =
    {
        name = "Cause and Effect",
        desc = "After you play a card, draw a card and lose 1 stacks.",
        icon = "negotiation/modifiers/tactical_mind.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 3,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",

        event_handlers = 
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                if self.owner == card.owner then
                    minigame:DrawCards(1)
                    self.negotiator:RemoveModifier( "PA_CAUSE_AND_EFFECT", 1 )
                end 
            end
        }
    },

    PA_SQUARE_TABLE_MEETING =
    {
        name = "Square Table Meeting",
        desc = "Whenever you play {PC_ALAN_DISCUSS}, {EXPEND} it.\nAt the end of your turn, play all {PC_ALAN_DISCUSS} in your trash deck.",
        icon = "negotiation/modifiers/drunk.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 3,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        event_handlers = 
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                if self.owner == card.owner and (card.id == "PC_ALAN_DISCUSS" or card.base_id == "PC_ALAN_DISCUSS") then
                    card:SetFlags(CARD_FLAGS.EXPEND)
                end
            end,

            [ EVENT.END_PLAYER_TURN ] = function( self, minigame )
                local trash_cards = self.engine:GetTrashDeck().cards
                local to_play = {}

                for i, card in ipairs(trash_cards) do
                    if card.owner == self.owner and (card.id == "PC_ALAN_DISCUSS" or card.base_id == "PC_ALAN_DISCUSS") then
                        table.insert(to_play, card)
                    end
                end

                for _, card in ipairs(to_play) do
                    card:SetFlags(CARD_FLAGS.FREEBIE)
                    self.engine:PlayCard(card)
                end
            end
        },
    },

    PA_CHIME_IN =
    {
        name = "Chime In",
        desc = "Whenever you draw a basic card, gain {1} {COMPOSURE} and deal {1} damage to a random opponent argument.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.stacks)
        end,
        icon = "negotiation/modifiers/rumor_monger.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 2,
        target_enemy = TARGET_ANY_RESOLVE,
        target_mod = TARGET_MOD.RANDOM1,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        event_handlers = 
        {
            [ EVENT.DRAW_CARD ] = function( self, engine, card )
                if card.owner == self.owner and card.rarity == CARD_RARITY.BASIC then
                    self.negotiator:DeltaComposure( self.stacks, self )
                    self.min_persuasion = self.stacks
                    self.max_persuasion = self.stacks
                    self:ApplyPersuasion()
                    self.min_persuasion = nil
                    self.max_persuasion = nil
                end
            end,
        },
    },

    PA_TRUST =
    {
        name = "Trust",
        desc = "When the stacks of {PA_TRUST} reaches 10, win the negotiation.",
        icon = "negotiation/modifiers/compromise.tex",
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 1,
        event_handlers =
        {
            [ EVENT.END_TURN ] = function( self, minigame, agent )
                local trust = self.negotiator:GetModifierStacks("PA_TRUST")
                if genuine >= 10 then
                    minigame:Win()
                end
            end
        } 
    },

    PA_ECHO =
    {
        name = "Echo",
        desc = "After you play a card, copy it and lose 1 stacks.",
        icon = "negotiation/modifiers/influence.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 3,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",

        event_handlers = 
        {
            [ EVENT.PRE_RESOLVE ] = function( self, minigame, card )
                if self.owner == card.owner then
                    local clone = card:Duplicate()
                    minigame:DealCard( clone, minigame:GetDiscardDeck() )
                    self.negotiator:RemoveModifier( "PA_ECHO", 1 )
                end 
            end
        }
    },
}

for i, id, def in sorted_pairs( MODIFIERS ) do
    Content.AddNegotiationModifier( id, def )
end

local CARDS =
{
    PC_ALAN_DISCUSS = 
    {
        name = "Discuss",
        icon = "negotiation/decency.tex",
        flavour = "'Let’s try looking at our current problem from a different angle.'",
        cost = 1,
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.DIPLOMACY,
        min_persuasion = 1,
        max_persuasion = 3,
        max_xp = 6,
        wild = true,
    },

    PC_ALAN_DISCUSS_plus2a =
    {
        name = "Visionary Discuss",
        desc = "<#UPGRADE>Draw a card</>.",
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_DISCUSS_plus2b =
    {
        name = "Tall Discuss",
        max_persuasion = 5,
    },

    PC_ALAN_DISCUSS_plus2c =
    {
        name = "Discuss of Clarity",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.CONSUME,
        min_persuasion = 5,
        max_persuasion = 7,
    },

    PC_ALAN_DISCUSS_plus2d =
    {
        name = "Stone Discuss",
        desc = "<#UPGRADE>Gain {1} {COMPOSURE}</>.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ))
        end,
        composure_amt = 3,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:DeltaComposure( self.composure_amt, self )
        end,
    },

    PC_ALAN_DISCUSS_plus2e =
    {
        name = "Pale Discuss",
        cost = 0,
        max_persuasion = 2,
    },

    PC_ALAN_DISCUSS_plus2f =
    {
        name = "Tentative Discuss",
        desc = "<#UPGRADE>{PA_TENTATIVE} {1}: deal 2 bonus damage.</>.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.tentative_amt)
        end,
        tentative_amt = 1,
        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self and self.negotiator:GetModifierStacks("PA_DRAW_CARD") > self.tentative_amt then
                    persuasion:AddPersuasion( 2, 2, self )
                end
            end,
        },
    },

    PC_ALAN_BLUFF =
    {
        name = "Bluff",
        icon = "negotiation/debate.tex",
        flavour = "'Trust me, this one's perfect!'",
        cost = 1,
        min_persuasion = 1,
        max_persuasion = 3,
        max_xp = 6,
        wild = true,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.BASIC,
    },

    PC_ALAN_BLUFF_plus2a =
    {
        name = "Rooted Bluff",
        min_persuasion = 3,
    },

    PC_ALAN_BLUFF_plus2b =
    {
        name = "Bluff of Clarity",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.CONSUME,
        min_persuasion = 6,
        max_persuasion = 6,
    },

    PC_ALAN_BLUFF_plus2c =
    {
        name = "Boosted Bluff",
        desc = "<#UPGRADE>{BRAVADO}</>.",
        bonus_damage = 1,
        event_handlers = 
        {
            [ EVENT.END_RESOLVE ] = function( self, minigame, card )
                if card.negotiator == self.negotiator then
                    if CheckBits(card.flags, CARD_FLAGS.HOSTILE) then
                        self.bonus = (self.bonus or 0) + self.bonus_damage
                    else
                        self.bonus = 0
                    end
                end
            end,

            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self and self.bonus and self.bonus > 0 then
                    persuasion:AddPersuasion(self.bonus, self.bonus, self)
                end
            end,

            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                self.bonus = 0
            end,
        },
    },

    PC_ALAN_BLUFF_plus2d =
    {
        name = "Visionary Bluff",
        desc = "<#UPGRADE>Draw a card</>.",
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_BLUFF_plus2e =
    {
        name = "Lucid Bluff",
        desc = "<#UPGRADE>Gain 2 {DOMINANCE}.</>.",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("DOMINANCE", 2, self)
        end
    },

    PC_ALAN_BLUFF_plus2f =
    {
        name = "Fluent Bluff",
        desc = "<#UPGRADE>{EVOKE}: Play a same-named cards</>.",
        evoke_max = 1,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        event_handlers = 
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                if card.owner == self.owner then
                    if card.base_id == self.base_id or card.id == "PC_ALAN_BLUFF" then
                        self:Evoke( self.evoke_max )
                    end
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self:ResetEvoke()
                end
            end,
        },
    },

    PC_ALAN_GUIDANCE =
    {
        name = "Guidance",
        desc = "Apply {1} {COMPOSURE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ))
        end,
        icon = "negotiation/rationale.tex",
        flavour = "'Start here, then maybe consider if my suggestion actually makes sense?'",
        max_xp = 6,
        wild = true,
        cost = 1,
        composure_amt = 3,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.BASIC,
        target_self = TARGET_ANY_RESOLVE,
        OnPostResolve = function( self, minigame, targets )
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
            end
        end
    },

    PC_ALAN_GUIDANCE_plus2a =
    {
        name = "Boosted Guidance",
        desc = "Apply <#UPGRADE>{1}</> {COMPOSURE}.",
        composure_amt = 4,
    },

    PC_ALAN_GUIDANCE_plus2b =
    {
        name = "Guidance of Clarity",
        desc = "Apply <#UPGRADE>{1}</> {COMPOSURE}.",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.CONSUME,
        composure_amt = 10,
    },

    PC_ALAN_GUIDANCE_plus2c =
    {
        name = "Pale Guidance",
        desc = "Apply <#DOWNGRADE>{1}</> {COMPOSURE}.",
        cost = 0,
        composure_amt = 1,
    },

    PC_ALAN_GUIDANCE_plus2d =
    {
        name = "Wide Guidance",
        desc = "Apply <#UPGRADE>{1} {COMPOSURE} to all friendly arguments</>.",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        target_mod = TARGET_MOD.TEAM,
        auto_target = true,
        composure_amt = 4,
    },

    PC_ALAN_GUIDANCE_plus2e =
    {
        name = "Visionary Guidance",
        desc = "Apply {1} {COMPOSURE}.\n<#UPGRADE>Draw a card</>.",
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_GUIDANCE_plus2f =
    {
        name = "Tentative Guidance",
        desc = "Apply {1} {COMPOSURE}.\n<#UPGRADE>{PA_TENTATIVE} {2}: Apply 3 bonus {COMPOSURE}.</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ) , self.tentative_amt)
        end,
        tentative_amt = 1,
        OnPostResolve = function( self, minigame, targets )
            local draw_cards = self.negotiator:GetModifierStacks("PA_DRAW_CARD")
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
                if draw_cards > self.tentative_amt then
                    target:DeltaComposure(self.composure_amt, self)
                end
            end
        end,
        
    },

    PC_ALAN_BASIC_SKILLS =
    {
        name = "Basic skills",
        icon = "negotiation/negotiation_wild.tex",
        desc = "Gain {1} {PA_BASIC_SKILLS}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.basic_amt)
        end,
        flavour = "'Wanna win a negotiation? It’s all about the hand you play.'",
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.BASIC,
        max_xp = 6,
        cost = 1,
        basic_amt = 1,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_BASIC_SKILLS", self.basic_amt, self)
        end,
    },

    PC_ALAN_BASIC_SKILLS_plus =
    {
        name = "Stone Basic skills",
        desc = "Gain {1} {PA_BASIC_SKILLS}.\n<#UPGRADE>Apply {2} {COMPOSURE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.basic_amt, self:CalculateComposureText( self.composure_amt ))
        end,
        composure_amt = 3,
        target_self = TARGET_ANY_RESOLVE,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_BASIC_SKILLS", self.basic_amt, self)
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
            end
        end,
    },

    PC_ALAN_BASIC_SKILLS_plus2 =
    {
        name = "Only Basic skills",
        desc = "Gain {1} {PA_BASIC_SKILLS}.\n<#UPGRADE>{PA_UNIQUE}: Gain additional {2} {PA_BASIC_SKILLS}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.basic_amt, self.alt_basic_amt)
        end,
        alt_basic_amt = 2,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS, DECK_TYPE.RESOLVE, DECK_TYPE.IN_HAND },
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_BASIC_SKILLS", self.basic_amt, self)
            
            local is_unique = IsCardUnique(self)
            if is_unique then
                self.negotiator:AddModifier("PA_BASIC_SKILLS", self.alt_basic_amt, self)
            end
        end,
    },

    PC_ALAN_BRAINSTORM =
    {
        name = "Brainstorm",
        icon = "negotiation/brainstorm.tex",
        desc = "{IMPROVISE} a card from a pool of special cards.",
        flavour = "'Thanks to you, I've got a whole swarm of new ideas now..'",
        cost = 1,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.BASIC,
        sound = "event:/sfx/battle/cards/gen/play_card/promoted_thinking",
        pool_size = 3,
        pool_cards = {"improvise_gruff", "improvise_carry_over", "improvise_options", "improvise_withdrawn", "PC_ALAN_INFLUENCE", "PC_ALAN_DOMINANCE", "improvise_wide_composure", "improvise_sleight", "improvise_vulnerability"},
        OnPostResolve = function( self, minigame, targets)
            local cards = ObtainWorkTable()

            cards = table.multipick( self.pool_cards, self.pool_size )
            for k,id in pairs(cards) do
                cards[k] = Negotiation.Card( id, self.owner  )
            end
            minigame:ImproviseCards( cards, 1, nil, nil, nil, self )
            ReleaseWorkTable(cards)
        end,
    },

    PC_ALAN_BRAINSTORM_plus =
    {
        name = "Promoted Brainstorm",
        desc = "{IMPROVISE} a card from a pool of <#UPGRADE>upgraded</> special cards.",
        pool_cards = {"improvise_gruff_upgraded", "improvise_carry_over_upgraded", "improvise_options_upgraded", "improvise_withdrawn_upgraded", "PC_ALAN_INFLUENCE_upgraded", "PC_ALAN_DOMINANCE_upgraded", "improvise_wide_composure_upgraded", "improvise_sleight_upgraded", "improvise_vulnerability_upgraded"},
    },

    PC_ALAN_BRAINSTORM_plus2 = 
    {
        name = "Boosted Brainstorm",
        desc = "<#UPGRADE>{IMPROVISE_PLUS}</> a card from a pool of special cards.",
        pool_size = 5,
    },

    PC_ALAN_INFLUENCE =
    {
        name = "Explain",
        icon = "negotiation/elucidate.tex",
        flavour = "'Trust me—I swear I’m not trying to screw you over.'",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        max_xp = 0,
        cost = 0,
        features =
        {
            INFLUENCE = 1,
        },
    },

    PC_ALAN_INFLUENCE_upgraded =
    {
        name = "Boosted Explain",
        min_persuasion = 0,
        max_persuasion = 4,
    },

    PC_ALAN_DOMINANCE =
    {
        name = "Doubt",
        icon = "negotiation/threaten.tex",
        desc = "Gain 1 {DOMINANCE}.",
        flavour = "'Are you sure?'",
        max_xp = 0,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("DOMINANCE", 1, self)
        end
    },

    PC_ALAN_DOMINANCE_upgraded =
    {
        name = "Boosted Doubt",
        desc = "Gain <#UPGRADE>2</> {DOMINANCE}.",
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("DOMINANCE", 2, self)
        end
    },

    PC_ALAN_AGREEMENT =
    {
        name = "Agreement",
        icon = "negotiation/improvise_compliment.tex",
        desc = "Gain {1} {INFLUENCE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.influence)
        end,
        flavour = "'As expected of you—what a thorough explanation.'",
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 1,
        max_persuasion = 3,
        max_xp = 9,
        cost = 1,
        influence = 1,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("INFLUENCE", self.influence, self)
        end
    },

    PC_ALAN_AGREEMENT_plus =
    {
        name = "Visionary Agreement",
        desc = "Gain {1} {INFLUENCE}.\n<#UPGRADE>Draw a card</>.",
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("INFLUENCE", self.influence, self)
            minigame:DrawCards( 1 )
        end
    },

    PC_ALAN_AGREEMENT_plus2 =
    {
        name = "Tall Agreement",
        max_persuasion = 5,
    },

    PC_ALAN_SMALL_TALK =
    {
        name = "Small Talk",
        icon = "negotiation/pleasantries.tex",
        desc = "{PA_TENTATIVE} {1}: Deal an additional {2} damage.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.tentative_amt, self.bonus_damage )
        end,
        flavour = "How have you been lately?",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 3,
        tentative_amt = 2,
        bonus_damage = 3,
        OnPostResolve = function( self, minigame, targets )
            local draw_cards = self.negotiator:GetModifierStacks("PA_DRAW_CARD")
            if draw_cards > self.tentative_amt then
                minigame:ApplyPersuasion( self, nil, self.bonus_damage, self.bonus_damage )
            end
        end,

    },

    PC_ALAN_SMALL_TALK_plus =
    {
        name = "Boosted Small Talk",
        desc = "{PA_TENTATIVE} {1}: Deal an additional <#UPGRADE>{2}</> damage.",
        bonus_damage = 5,
    },

    PC_ALAN_SMALL_TALK_plus2 =
    {
        name = "Pale Small Talk",
        desc = "{PA_TENTATIVE} <#UPGRADE>{1}</>: Deal an additional {2} damage.",
        tentative_amt = 1,
    },

    PC_ALAN_PERSENTATION =
    {
        name = "Presentation",
        icon = "negotiation/agency.tex",
        desc = "Draw a card.",
        flavour = "'Take a look at this.'",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.REPLENISH,
        rarity = CARD_RARITY.COMMON,
        max_xp = 10,
        cost = 0,
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_PERSENTATION_plus =
    {
        name = "Sticky Presentation",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.REPLENISH | CARD_FLAGS.STICKY,
    },

    PC_ALAN_PERSENTATION_plus2 =
    {
        name = "Only Presentation",
        desc = "Draw a card.\n<#UPGRADE>{PA_UNIQUE}: Draw additional 2 cards</>.",
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)

            local is_unique = IsCardUnique(self)
            if is_unique then
                minigame:DrawCards(2)
            end
        end,
    },

    PC_ALAN_ELABORATION =
    {
        name = "Elaboration",
        icon = "negotiation/setup.tex",
        desc = "Add a copy of {PC_ALAN_DISCUSS} to your hand.",
        flavour = "'I feel I need to dive a bit deeper into this point.'",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 1,
        max_persuasion = 4,
        max_xp = 9,
        cost = 1,
        OnPostResolve = function( self, minigame, targets )
            local cards = {}
            for i = 1, 1 do
                local card = Negotiation.Card( "PC_ALAN_DISCUSS", self.owner )
                if self.upgraded then
                    card:UpgradeCard()
                end
                card:ClearXP()
                card:MakeTemporary()
                table.insert( cards, card )
            end
            minigame:DealCards( cards, minigame:GetHandDeck() )
        end,
    },

    PC_ALAN_ELABORATION_plus =
    {
        name = "Tall Elaboration",
        max_persuasion = 6,
    },

    PC_ALAN_ELABORATION_plus2 =
    {
        name = "Boosted Elaboration",
        desc = "Add a copy of <#UPGRADE>randomly upgraded</> {PC_ALAN_DISCUSS} to your hand.",
        upgraded = true,
    },

    PC_ALAN_GOODWILL =
    {
        name = "Goodwill",
        icon = "negotiation/subtlety.tex",
        desc = "{PA_TENTATIVE} X: Costs 1 less for each X.",
        flavour = "*wink*",
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 6,
        max_xp = 3,
        cost = 3,
        event_priorities =
        {
            [ EVENT.CALC_ACTION_COST ] = EVENT_PRIORITY_PRESETTOR
        },
        deck_handlers = ALL_DECKS,
        event_handlers =
        {
            [ EVENT.CALC_ACTION_COST ] = function( self, cost_acc, card, target )
                if card == self then
                    cost_acc:ModifyValue( card.def.cost - (self.negotiator:GetModifierStacks("PA_DRAW_CARD") - 1), self )
                end
            end,
        },
    },

    PC_ALAN_GOODWILL_plus =
    {
        name = "Rooted Goodwill",
        min_persuasion = 6,
    },

    PC_ALAN_GOODWILL_plus2 =
    {
        name = "Tall Rebuttal",
        max_persuasion = 8,
    },

    PC_ALAN_FINGER_SNAP =
    {
        name = "Finger Snap",
        icon = "negotiation/blank.tex",
        desc = "{PA_UNIQUE}: Attack with this card three times.",
        flavour = "'Don't do it too often, or you'll start getting on people's nerves.'",
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 4,
        max_xp = 9,
        cost = 2,
        OnPostResolve = function( self, minigame )
            local is_unique = IsCardUnique(self)
            if is_unique then
                for i = 1, 2 do
                    minigame:ApplyPersuasion( self )
                end
            end
        end,
    },

    PC_ALAN_FINGER_SNAP_plus =
    {
        name = "Pale Finger Snap",
        cost = 1,
    },

    PC_ALAN_FINGER_SNAP_plus2 =
    {
        name = "Rooted Finger Snap",
        max_persuasion = 6,
    },

    PC_ALAN_RAGE =
    {
        name = "Rage",
        icon = "negotiation/seethe.tex",
        desc = "Add two copy of this card to your discards.\nIncreases the cost of all same-named cards by 1 and gain 3 bonus damage.",
        flavour = "'Ennggggggggg……'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 1,
        max_persuasion = 3,
        OnPostResolve = function( self, minigame )
            self.negotiator:AddModifier("PA_RAGE", 1, self)
            for i = 1, 2 do
                local copy = self:Duplicate()
                minigame:DealCard( copy, minigame:GetDiscardDeck() )
            end
        end,
    },

    PC_ALAN_RAGE_plus =
    {
        name = "Visionary Rage",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_RAGE_plus2 =
    {
        name = "Pale Rage",
        cost = 0,
        min_persuasion = 1,
        max_persuasion = 1,
    },

    PC_ALAN_MISFIRE =
    {
        name = "Misfire",
        icon = "negotiation/burn.tex",
        desc = "{PA_PRECURSUR} {1}: Hits all opponent arguments.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.precursor_amt)
        end,
        flavour = "'Sorry, this gun acts up sometimes.'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 2,
        precursor_amt = 8,
        event_handlers = 
        {
            [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
            local discards_count = DiscardPileCount(self)
                if card == self and discards_count ~= nil then
                    if discards_count >= self.precursor_amt then
                        self.target_mod = TARGET_MOD.TEAM
                        self.auto_target = true
                    else
                        self.target_mod = TARGET_MOD.SINGLE
                        self.auto_target = nil
                    end
                end
            end,

            [ EVENT.SHUFFLE_DISCARDS ] = function( self, num_cards )
                self.target_mod = TARGET_MOD.SINGLE
                self.auto_target = nil
            end
        },
    },

    PC_ALAN_MISFIRE_plus =
    {
        name = "Tall Misfire",
        max_persuasion = 4,
    },

    PC_ALAN_MISFIRE_plus2 =
    {
        name = "Boosted Misfire",
        min_persuasion = 3,
        max_persuasion = 3,
    },

    PC_ALAN_PREPARE =
    {
        name = "Prepare",
        icon = "negotiation/notion.tex",
        desc = "Gain 1 {DOMINANCE} for each {PC_ALAN_BLUFF} in your hand.",
        loc_strings = 
        {
            ALT_DESC = "Gain 1 {DOMINANCE} for each {PC_ALAN_BLUFF} in your hand.\n({1} {DOMINANCE})",
        },
        desc_fn = function(self, fmt_str)
            if self.engine then
                local count = 0
                for i,card in self.engine:GetHandDeck():Cards() do
                    if card.base_id == "PC_ALAN_BLUFF" or card.id == "PC_ALAN_BLUFF" then
                        count = count + 1
                    end
                end
                return loc.format(self.def:GetLocalizedString("ALT_DESC"), (self.dominance_amt * count) + self.dominance_bonus)
            else
                return loc.format(fmt_str, 0)
            end
        end,
        flavour = "'Alright, settle in. Time for my blu—... brilliant analysis!.'",
        cost = 1,
        max_xp = 9,
        dominance_amt = 1,
        dominance_bonus = 0,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        PreReq = function( self, minigame )
            local count = 0
            for i,card in self.engine:GetHandDeck():Cards() do
                if card.base_id == "PC_ALAN_BLUFF" or card.id == "PC_ALAN_BLUFF" then
                    count = count + 1
                end
            end
            return count > 0
        end,
        
        OnPostResolve = function( self, minigame, targets )
            local count = 0
            for i,card in self.engine:GetHandDeck():Cards() do
                if card.base_id == "PC_ALAN_BLUFF" or card.id == "PC_ALAN_BLUFF" then
                    count = count + 1
                end
            end
            self.negotiator:AddModifier("DOMINANCE", (self.dominance_amt * count) + self.dominance_bonus, self)
            if self.lose_dominance then
                self.negotiator:AddModifier( "notion", (self.dominance_amt * count) + self.dominance_bonus, self )
            end
        end,
    },

    PC_ALAN_PREPARE_plus =
    {
        name = "Boosted Prepare",
        desc = "Gain 1 {DOMINANCE}<#UPGRADE>+1</> for each {PC_ALAN_BLUFF} in your hand.",
        dominance_bonus = 1,
    },

    PC_ALAN_PREPARE_plus2 =
    {
        name = "Tactless Prepare",
        desc = "Gain <#UPGRADE>2</> {DOMINANCE} for each {PC_ALAN_BLUFF} in your hand.\n<#DOWNGRADE>At the end of your turn, lose those {DOMINANCE} that gain by this card</>.",
        loc_strings = 
        {
            ALT_DESC = "Gain 2 {DOMINANCE} for each {PC_ALAN_BLUFF} in your hand.\nAt the end of your turn, lose those {DOMINANCE} that gain by this card.\n({1} {DOMINANCE})",
        },
        dominance_amt = 2,
        lose_dominance = true,
    },

    PC_ALAN_STRAIGHT_FORWARD =
    {
        name = "Straight forward",
        icon = "negotiation/invective.tex",
        desc = "{EVOKE}: Play a same-named cards.",
        flavour = "'You Idiot!'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 3,
        evoke_max = 1,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        event_handlers = 
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                if card.owner == self.owner then
                    if card.id == "PC_ALAN_STRAIGHT_FORWARD" or card.base_id == "PC_ALAN_STRAIGHT_FORWARD" then
                        self:Evoke( self.evoke_max )
                    end
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self:ResetEvoke()
                end
            end,
        },
    },

    PC_ALAN_STRAIGHT_FORWARD_plus =
    {
        name = "Tall Straight forward",
        max_persuasion = 4,
    },

    PC_ALAN_STRAIGHT_FORWARD_plus2 =
    {
        name = "Rooted Straight forward",
        min_persuasion = 3,
    },

    PC_ALAN_SEIZE =
    {
        name = "Seize",
        icon = "negotiation/dig.tex",
        desc = "{PA_PRECURSUR} {1}: This card costs 0.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.precursor_amt )
        end,
        flavour = "'Seriously, why are there so many snails around here?!'",
        cost = 1,
        max_xp = 10,
        min_persuasion = 2,
        max_persuasion = 3,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        precursor_amt = 5,
        event_priorities =
        {
            [ EVENT.CALC_ACTION_COST ] = EVENT_PRIORITY_SETTOR,
        },

        event_handlers =
        {
            [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                local discards_count = DiscardPileCount(self)
                if card == self and discards_count ~= nil then
                    if discards_count >= self.precursor_amt then
                        self.precursor_active = true
                    else
                        self.precursor_active = false
                    end
                end
            end,

            [ EVENT.SHUFFLE_DISCARDS ] = function( self, num_cards )
                self.precursor_active = false
            end,

            [ EVENT.CALC_ACTION_COST ] = function( self, acc, card, target )
                if card == self then
                    if self.precursor_active then
                        acc:ModifyValue(0)
                    end
                end
            end
        }
    },

    PC_ALAN_SEIZE_plus =
    {
        name = "Boosted Seize",
        min_persuasion = 4,
        max_persuasion = 5,
    },

    PC_ALAN_SEIZE_plus2 =
    {
        name = "Twisted Seize",
        desc = "<#UPGRADE>{PA_TENTATIVE} {1}</>: This card costs 0.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.tentative_amt )
        end,
        min_persuasion = 4,
        max_persuasion = 5,
        tentative_amt = 1,
        event_handlers = 
        {
            [ EVENT.CALC_ACTION_COST ] = function( self, acc, card, target )
                if card == self then
                    if self.negotiator:GetModifierStacks("PA_DRAW_CARD") > self.tentative_amt then
                        acc:ModifyValue(0)
                    end
                end
            end
        },
    },

    PC_ALAN_PROVOKE =
    {
        name = "Provoke",
        icon = "negotiation/grumble.tex",
        desc = "{PA_UNIQUE}: Gain {1} {COMPOSURE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ))
        end,
        flavour = "'Tsk. And here I thought it’d be something special. Guess that’s it?'",
        cost = 2,
        max_xp = 7,
        min_persuasion = 2,
        max_persuasion = 6,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        composure_amt = 4,
        bonus_damage = false,
        OnPostResolve = function( self, minigame )
            local is_unique = IsCardUnique(self)
            if is_unique then
                self.negotiator:DeltaComposure( self.composure_amt, self )
                if self.bonus_damage then
                    minigame:ApplyPersuasion( self, nil, 3, 3 )
                end
            end
        end,
    },

    PC_ALAN_PROVOKE_plus =
    {
        name = "Stone Provoke",
        desc = "{PA_UNIQUE}: Gain <#UPGRADE>{1}</> {COMPOSURE}.",
        composure_amt = 6,
    },

    PC_ALAN_PROVOKE_plus2 =
    {
        name = "Boosted Provoke",
        desc = "{PA_UNIQUE}: Gain {1} {COMPOSURE} <#UPGRADE>and deal 3 bonus damage</>.",
        bonus_damage = true,
    },

    PC_ALAN_SHOWTIME = 
    {
        name = "Showtime",
        icon = "negotiation/pure_style.tex",
        desc = "Draw a card.\n{IMPROVISE} a card from your draw pile.",
        flavour = "'Watch closely—this is how it’s done.'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.COMMON,
        draw = 1,
        pool_size = 3,
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(self.draw)
            local cards = {}
            for i, card in minigame:GetDrawDeck():Cards() do
                table.insert(cards, card)
            end
            if #cards == 0 then
                minigame:ShuffleDiscardToDraw()
                for i, card in minigame:GetDrawDeck():Cards() do
                    table.insert(cards, card)
                end
            end

            minigame:ImproviseCards(table.multipick(cards, self.pool_size), 1, nil, nil, nil, self)
        end
    },

    PC_ALAN_SHOWTIME_plus =
    {
        name = "Boosted Showtime",
        desc = "Draw <#UPGRADE>2</> card.\n{IMPROVISE} a card from your draw pile.",
        draw = 2,
    },

    PC_ALAN_SHOWTIME_plus2 =
    {
        name = "Wide Showtime",
        desc = "Draw {1} card.\n<#UPGRADE>{IMPROVISE_PLUS}</> a card from your draw pile.",
        pool_size = 5,
    },

    PC_ALAN_ARCHIVE =
    {
        name = "Archive",
        icon = "negotiation/stool_pigeon.tex",
        desc = "Draw a card and duplicate it, the copy have {EXPEND}.",
        flavour = "'Don't ask why there's a pigeon here. That's our court reporter!'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.COMMON,
        draw = 1,
        OnPostResolve = function( self, minigame, targets )
            local cards = minigame:DrawCards(self.draw)
            for i,card in ipairs(cards) do
                local clone = card:Duplicate()
                clone:SetFlags(CARD_FLAGS.EXPEND)
                clone:TransferCard( minigame:GetHandDeck() )
            end
        end
    },

    PC_ALAN_ARCHIVE_plus =
    {
        name = "Improvised Archive",
        desc = "<#UPGRADE>{IMPROVISE} a card from your draw pile</> and duplicate it, the copy have {EXPEND}.",
        OnPostResolve = function( self, minigame, targets )
            local cards = {}
            for i, card in minigame:GetDrawDeck():Cards() do
                table.insert(cards, card)
            end
            if #cards == 0 then
                minigame:ShuffleDiscardToDraw()
                for i, card in minigame:GetDrawDeck():Cards() do
                    table.insert(cards, card)
                end
            end

            local chosen_cards = minigame:ImproviseCards(table.multipick(cards, 3), 1, nil, nil, nil, self)
            if chosen_cards[1] then
                local clone = chosen_cards[1]:Duplicate()
                clone:SetFlags(CARD_FLAGS.EXPEND)
                clone:TransferCard( minigame:GetHandDeck() )
            end
        end
    },

    PC_ALAN_ARCHIVE_plus2 =
    {
        name = "Visionary Archive",
        desc = "Draw <#UPGRADE>2</> card and duplicate it, the copy have {EXPEND}.",
        cost = 2,
        draw = 2,
    },

    PC_ALAN_BREEZY =
    {
        name = "Breezy",
        icon = "negotiation/standing.tex",
        desc = "{PA_BREEZY|}Create: At the end of the turn, apply 1 {COMPOSURE} to a random friendly argument.",
        flavour = "'The wind’s a bit rowdy today.'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.COMMON,
        count = 1,
        OnPostResolve = function( self, minigame, targets )
            for i=1,self.count do
                self.negotiator:CreateModifier("PA_BREEZY", 1, self)
            end
        end
    },

    PC_ALAN_BREEZY_plus =
    {
        name = "Pale Breezy",
        cost = 0,
    },

    PC_ALAN_BREEZY_plus2 =
    {
        name = "Mirrored Breezy",
        desc = "{PA_BREEZY|}Create <#UPGRADE>2</>: At the end of the turn, apply 1 {COMPOSURE} to a random friendly argument.",
        count = 2,
    },

    PC_ALAN_SHUFFLE =
    {
        name = "Shuffle",
        icon = "negotiation/stacked_deck.tex",
        desc = "{PA_SHUFFLE|}Gain {1} {PA_SHUFFLE}.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.count)
        end,
        flavour = "'Don't worry, my shuffling is top-tier. Not a single card will be harmed.'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.COMMON,
        count = 2,
        OnPostResolve = function( self, minigame, targets )
            for i=1,self.count do
                self.negotiator:AddModifier("PA_SHUFFLE", 1, self)
            end
        end
    },

    PC_ALAN_SHUFFLE_plus =
    {
        name = "Boosted Shuffle",
        desc = "{PA_SHUFFLE|}Gain <#UPGRADE>{1}</> {PA_SHUFFLE}.",
        count = 3,
    },

    PC_ALAN_SHUFFLE_plus2 =
    {
        name = "Pale Shuffle",
        desc = "{PA_SHUFFLE|}Gain <#DOWNGRADE>{1}</> {PA_SHUFFLE}.",
        count = 1,
        cost = 0,
        
    },

    PC_ALAN_FACADE =
    {
        name = "Facade",
        icon = "negotiation/back_pedal.tex",
        desc = "Discard {1} cards from your hand.\nDraw {2} cards.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.discard_count, self.draw_count)
        end,
        flavour = "'Um... well...'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.COMMON,
        draw_count = 2,
        discard_count = 2,
        OnPostResolve = function( self, minigame, targets )
            minigame:DiscardCards(self.discard_count, self.discard_count, self)
            minigame:DrawCards(self.draw_count)
        end
    },

    PC_ALAN_FACADE_plus =
    {
        name = "Pale Facade",
        desc = "Discard <#UPGRADE>{1}</> cards from your hand.\nDraw <#DOWNGRADE>{2}</> cards.",
        cost = 0,
        draw_count = 1,
        discard_count = 1,
    },

    PC_ALAN_FACADE_plus2 =
    {
        name = "Visionary Facade",
        desc = "Discard {1} cards from your hand.\nDraw <#UPGRADE>{2}</> cards.",
        draw_count = 3,
    },

    PC_ALAN_WINDBAG =
    {
        name = "Windbag",
        icon = "negotiation/prattle.tex",
        desc = "Apply {1} {COMPOSURE}.\n{PA_PRECURSUR} {2}: Double {COMPOSURE} on all arguments.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ), self.precursor_amt)
        end,
        flavour = "'And then there's this, and that, and—honestly, you get the point. Yadda yadda yadda.'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.COMMON,
        target_self = TARGET_ANY_RESOLVE,
        composure_amt = 2,
        precursor_amt = 10,
        discard = false,
        event_handlers =
        {
            [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                local discards_count = DiscardPileCount(self)
                if card == self and discards_count ~= nil then
                    if discards_count >= self.precursor_amt then
                        self.precursor_active = true
                    else
                        self.precursor_active = false
                    end
                end
            end,

            [ EVENT.SHUFFLE_DISCARDS ] = function( self, num_cards )
                self.precursor_active = false
            end,
        },
        OnPostResolve = function( self, minigame, targets )
            if self.discard then
                minigame:DiscardCards(2, 2, self)
            end
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
            end
            if self.precursor_active then
                for i, modifier in self.negotiator:ModifierSlots() do
                    if modifier:GetComposure() > 0 then
                        modifier:DeltaComposure(modifier:GetComposure())
                    end
                end
            end
        end
    },

    PC_ALAN_WINDBAG_plus =
    {
        name = "Strained Windbag",
        desc = "<#DOWNGRADE>Discard 2 cards</>.\nApply <#UPGRADE>{1}</> {COMPOSURE}.\n{PA_PRECURSUR} {2}: Double {COMPOSURE} on all arguments.",
        flavour = "'And then there's this, and that, and—honestly, i hope you get the point, right? Yadda yadda yadda.'",
        discard = true,
        composure_amt = 4,
    },

    PC_ALAN_WINDBAG_plus2 =
    {
        name = "Boosted Windbag",
        desc = "Apply <#UPGRADE>{1}</> {COMPOSURE}.\n{PA_PRECURSUR} {2}: Double {COMPOSURE} on all arguments.",
        composure_amt = 3,
    },

    PC_ALAN_PLEAD = 
    {
        name = "Plead",
        desc = "Treat the damage dealt by this card as cards drawn.",
        icon = "negotiation/plead.tex",
        flavour = "'Please, this is really important to me.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 1,
        max_persuasion = 3,
        max_xp = 9,
        draw_card = false,
        event_handlers =
        {
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                if source == self and damage > 0 then
                    if self.draw_card then
                        self.engine:DrawCards(damage)
                    else
                        self.negotiator:AddModifier("PA_DRAW_CARD", damage, self)
                        self.negotiator:AddModifier("PA_DRAW_CARD_ALT", damage, self)
                    end                    
                end
            end
        },
    },

    PC_ALAN_PLEAD_plus =
    {
        name = "Boosted Plead",
        min_persuasion = 3,
        max_persuasion = 5,
    },

    PC_ALAN_PLEAD_plus2 =
    {
        name = "Visionary Plead",
        desc = "<#UPGRADE>Draw cards equal to the damage dealt by this card</>.",
        draw_card = true,
    },

    PC_ALAN_NONSTOP_DEBATE =
    {
        name = "Nonstop Debate",
        icon = "negotiation/level_playing_field.tex",
        desc = "{PA_NONSTOP_DEBATE|}Gain: increase the maximum damage of {PC_ALAN_DISCUSS} by 4.",
        flavour = "'Let's put the guns away and discuss things normally.'",
        cost = 2,
        max_xp = 7,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        influence = false,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_NONSTOP_DEBATE", 1, self)
            if self.influence then
                self.negotiator:AddModifier("INFLUENCE", 1, self)
            end
        end
    },

    PC_ALAN_NONSTOP_DEBATE_plus =
    {
        name = "Boosted Nonstop Debate",
        desc = "{PA_NONSTOP_DEBATE|}Gain: increase the maximum damage of {PC_ALAN_DISCUSS} by 4.\n<#UPGRADE>Gain 1 {INFLUENCE}</>.",
        influence = true,
    },

    PC_ALAN_NONSTOP_DEBATE_plus2 =
    {
        name = "Initial Nonstop Debate",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_CONTRACT = 
    {
        name = "Contract",
        desc = "Double your {PA_BASIC_SKILLS}.\nAt the end of your turn, lose those {PA_BASIC_SKILLS} that gain by this card.",
        icon = "negotiation/compel.tex",
        flavour = "'Just a very simple contract and no catches inside.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        OnPostResolve = function( self, minigame, targets )
            local stacks = self.negotiator:GetModifierStacks("PA_BASIC_SKILLS")
            self.negotiator:AddModifier("PA_BASIC_SKILLS", stacks, self)
            self.negotiator:AddModifier("PA_ANTI_BASIC_SKILLS", stacks, self)
        end,
    },

    PC_ALAN_CONTRACT_plus =
    {
        name = "Boosted Argument",
        desc = "<#UPGRADE>Gain 1 {PA_BASIC_SKILLS}, then</> Double your {PA_BASIC_SKILLS}.\nAt the end of your turn, lose those {PA_BASIC_SKILLS} that gain by this card.",
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_BASIC_SKILLS", 1, self)
            self.negotiator:AddModifier("PA_ANTI_BASIC_SKILLS", 1, self)
            local stacks = self.negotiator:GetModifierStacks("PA_BASIC_SKILLS")
            self.negotiator:AddModifier("PA_BASIC_SKILLS", stacks, self)
            self.negotiator:AddModifier("PA_ANTI_BASIC_SKILLS", stacks, self)
        end,
    },

    PC_ALAN_CONTRACT_plus2 =
    {
        name = "Sticky Argument",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.STICKY,
    },

    PC_ALAN_OBSERVE = 
    {
        name = "Observe",
        desc = "{PA_TENTATIVE} X: gains 2X bonus damage until the end of your turn.",
        icon = "negotiation/swift_rebuttal.tex",
        flavour = "'Objection!'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 1,
        max_persuasion = 3,
        max_xp = 9,
        bonus_damage = 2,
        deck_handlers = ALL_DECKS,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
            local draw_cards = (self.negotiator:GetModifierStacks("PA_DRAW_CARD") - 1)
                if source == self then
                    persuasion:AddPersuasion( draw_cards * self.bonus_damage, draw_cards * self.bonus_damage, self )
                end
            end
        }
    },

    PC_ALAN_OBSERVE_plus =
    {
        name = "Boosted Observe",
        min_persuasion = 3,
        max_persuasion = 5,
    },

    PC_ALAN_OBSERVE_plus2 =
    {
        name = "Enduring Observe",
        desc = "{PA_TENTATIVE} X: gains <#DOWNGRADE>X</> bonus damage until the end of <#UPGRADE>this negotiation</>.",
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self then
                    local bonus = self.negotiator:GetModifierStacks("PA_DRAW_CARD_ALT") or 0
                    persuasion:AddPersuasion( bonus, bonus, self )
                end
            end
        },
    },

    PC_ALAN_NOTES = 
    {
        name = "Notes",
        desc = "Gain {PA_BASIC_SKILLS} equal to damage dealt by this card.",
        icon = "negotiation/contacts.tex",
        flavour = "'Hold on, let me write this down!'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 0,
        max_persuasion = 2,
        max_xp = 9,
        event_handlers =
        {
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                if source == self and damage > 0 then
                    self.negotiator:AddModifier("PA_BASIC_SKILLS", damage, self)
                end
            end
        },
    },

    PC_ALAN_NOTES_plus =
    {
        name = "Boosted Notes",
        min_persuasion = 1,
        max_persuasion = 3,
    },

    PC_ALAN_NOTES_plus2 =
    {
        name = "Only Notes",
        desc = "Gain {PA_BASIC_SKILLS} equal to damage dealt by this card.\n<#DOWNGRADE>{PA_UNIQUE}: This card is able to deal damage</>.",
        min_persuasion = 2,
        max_persuasion = 4,
        event_handlers =
        {
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                if source == self and damage > 0 then
                    self.negotiator:AddModifier("PA_BASIC_SKILLS", damage, self)
                end
            end,

            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self then
                    local is_unique = IsCardUnique(self)
                    if not is_unique then
                        persuasion:AddPersuasion(-999, -999, self)
                    end
                end
            end,
        },
    },

    PC_ALAN_STRATEGY_CONFIRMED = 
    {
        name = "Strategy Confirmed",
        desc = "Replace all {PC_ALAN_BLUFF} in your deck with {PC_ALAN_DISCUSS} and add them to your draw pile.",
        icon = "negotiation/instincts_diplomatic.tex",
        flavour = "'Great, let's go with this.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        OnPostResolve = function( self, minigame, targets )
            local cards_to_remove = {}
            for i,card in minigame:GetDrawDeck():Cards() do
                if card.id == "PC_ALAN_BLUFF" or card.base_id == "PC_ALAN_BLUFF" then
                    table.insert(cards_to_remove, card)
                end 
            end
            for i,card in minigame:GetDiscardDeck():Cards() do
                if card.id == "PC_ALAN_BLUFF" or card.base_id == "PC_ALAN_BLUFF" then
                    table.insert(cards_to_remove, card)
                end 
            end
            for i,card in minigame:GetHandDeck():Cards() do
                if card.id == "PC_ALAN_BLUFF" or card.base_id == "PC_ALAN_BLUFF" then
                    table.insert(cards_to_remove, card)
                end 
            end

            if #cards_to_remove > 0 then
                local change = Negotiation.Card("PC_ALAN_DISCUSS", self.owner)
                for i=1, #cards_to_remove do
                    minigame:DealCard( change:Duplicate(), minigame:GetDrawDeck())
                end
                for i,card in ipairs(cards_to_remove) do
                    minigame:ExpendCard(card)
                end
            end
        end,
    },

    PC_ALAN_STRATEGY_CONFIRMED_plus =
    {
        name = "Boosted Strategy Confirmed",
        desc = "Replace all {PC_ALAN_BLUFF} in your deck with <#UPGRADE>randomly upgraded</> {PC_ALAN_DISCUSS} and add them to your draw pile.",
        OnPostResolve = function( self, minigame, targets )
            local cards_to_remove = {}
            for i,card in minigame:GetDrawDeck():Cards() do
                if card.id == "PC_ALAN_BLUFF" or card.base_id == "PC_ALAN_BLUFF" then
                    table.insert(cards_to_remove, card)
                end 
            end
            for i,card in minigame:GetDiscardDeck():Cards() do
                if card.id == "PC_ALAN_BLUFF" or card.base_id == "PC_ALAN_BLUFF" then
                    table.insert(cards_to_remove, card)
                end 
            end
            for i,card in minigame:GetHandDeck():Cards() do
                if card.id == "PC_ALAN_BLUFF" or card.base_id == "PC_ALAN_BLUFF" then
                    table.insert(cards_to_remove, card)
                end 
            end

            if #cards_to_remove > 0 then
                local change = Negotiation.Card("PC_ALAN_DISCUSS", self.owner)
                for i=1, #cards_to_remove do
                    local card = Negotiation.Card(table.arraypick(change.def.upgrade_ids), self.owner)
                    minigame:DealCard( card:Clone(), minigame:GetDrawDeck())
                end
                for i,card in ipairs(cards_to_remove) do
                    minigame:ExpendCard(card)
                end
            end
        end,
    },

    PC_ALAN_STRATEGY_CONFIRMED_plus2 =
    {
        name = "Twisted Strategy Confirmed",
        desc = "Replace all <#UPGRADE>{PC_ALAN_DISCUSS}</> in your deck with <#UPGRADE>randomly upgraded {PC_ALAN_BLUFF}</> and add them to your draw pile.",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
        icon = "negotiation/instincts_hostile.tex",
        OnPostResolve = function( self, minigame, targets )
            local cards_to_remove = {}
            for i,card in minigame:GetDrawDeck():Cards() do
                if card.id == "PC_ALAN_DISCUSS" or card.base_id == "PC_ALAN_DISCUSS" then
                    table.insert(cards_to_remove, card)
                end 
            end
            for i,card in minigame:GetDiscardDeck():Cards() do
                if card.id == "PC_ALAN_DISCUSS" or card.base_id == "PC_ALAN_DISCUSS" then
                    table.insert(cards_to_remove, card)
                end 
            end
            for i,card in minigame:GetHandDeck():Cards() do
                if card.id == "PC_ALAN_DISCUSS" or card.base_id == "PC_ALAN_DISCUSS" then
                    table.insert(cards_to_remove, card)
                end 
            end

            if #cards_to_remove > 0 then
                local change = Negotiation.Card("PC_ALAN_BLUFF", self.owner)
                for i=1, #cards_to_remove do
                    local card = Negotiation.Card(table.arraypick(change.def.upgrade_ids), self.owner)
                    minigame:DealCard( card:Clone(), minigame:GetDrawDeck())
                end
                for i,card in ipairs(cards_to_remove) do
                    minigame:ExpendCard(card)
                end
            end
        end,
    },

    PC_ALAN_GOOD_POINT = 
    {
        name = "Good Point",
        desc = "When this card is drawn, gain 1 {INFLUENCE} and let it gain 2 resolve.",
        icon = "negotiation/solid_point.tex",
        flavour = "'You couldn't help but appreciate that argument too, right?'",
        cost = 0,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.BURNOUT,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        event_handlers =
        {
           [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                 if card == self then
                    self.engine:PushPostHandler( function()
                        self:NotifyTriggeredPre()
                        local influence = self.negotiator:AddModifier("INFLUENCE", 1, self)
                        if influence then
                            influence:ModifyResolve( 2, self )
                        end
                        self:AddXP(1)
                        self:NotifyTriggeredPost()
                    end )
                end
            end,
        }
    },

    PC_ALAN_GOOD_POINT_plus =
    {
        name = "Visionary Good Point",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.BURNOUT | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_GOOD_POINT_plus2 =
    {
        name = "Twisted Good Point",
        desc = "When this card is drawn, gain <#UPGRADE>2 {DOMINANCE}</> and let it gain 2 resolve.",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.BURNOUT | CARD_FLAGS.REPLENISH,
        event_handlers =
        {
           [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                 if card == self then
                    self.engine:PushPostHandler( function()
                        self:NotifyTriggeredPre()
                        local dominance = self.negotiator:AddModifier("DOMINANCE", 2, self)
                        if dominance then
                            dominance:ModifyResolve( 2, self )
                        end
                        self:AddXP(1)
                        self:NotifyTriggeredPost()
                    end )
                end
            end,
        }
    },

    PC_ALAN_PAPERWORK = 
    {
        name = "Paperwork",
        desc = "Whenever you play a basic card, reduce the cost of this card by 1 until played.",
        icon = "negotiation/hard_facts.tex",
        flavour = "'I've got a whole stack here, take your time reading.'",
        cost = 6,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 6,
        max_persuasion = 8,
        max_xp = 3,
        bonus = 0,
        deck_handlers = ALL_DECKS,
        OnPostResolve = function( self, minigame, targets )
            self.bonus = 0
        end,
        event_handlers =
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card, targets )
                if self.owner == card.owner then
                    if card.rarity == CARD_RARITY.BASIC then
                        self.bonus = self.bonus + 1
                    end
                end
            end,

            [ EVENT.CALC_ACTION_COST ] = function( self, acc, card, target )
                if self.bonus and card == self then
                    acc:AddValue(-self.bonus, self)
                end
            end
        },
    },

    PC_ALAN_PAPERWORK_plus =
    {
        name = "Boosted Paperwork",
        min_persuasion = 8,
        max_persuasion = 10,
    },

    PC_ALAN_PAPERWORK_plus2 =
    {
        name = "Visionary Paperwork",
        desc = "Whenever you play a basic card, reduce the cost of this card by 1 until played.\n<#UPGRADE>Draw a card</>.",
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)
            self.bonus = 0
        end,
    },

    PC_ALAN_STALL = 
    {
        name = "Stall",
        desc = "On your next turn, shuffle your deck, then draw 2 cards and gain 2 actions.",
        icon = "negotiation/buying_time.tex",
        flavour = "'Oh, I'll explain it to you later.'",
        cost = 2,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_STALL", 1, self)
        end,
    },

    PC_ALAN_STALL_plus =
    {
        name = "Pale Stall",
        cost = 1,
    },

    PC_ALAN_STALL_plus2 =
    {
        name = "Stone Stall",
        desc = "<#UPGRADE>Gain {1} {COMPOSURE}</>.\nOn your next turn, shuffle your deck, then draw 2 cards and gain 2 actions.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ))
        end,
        composure_amt = 4,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_STALL", 1, self)
            self.negotiator:DeltaComposure( self.composure_amt, self )
        end,
    },

    PC_ALAN_APPLAUSE = 
    {
        name = "Applause",
        desc = "{PA_APPLAUSE|}Create: When you shuffle your deck, deal {1} damage to random argument, then destroy this argument.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.stacks)
        end,
        icon = "negotiation/praise.tex",
        flavour = "'Perfect!'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        stacks = 7,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PA_APPLAUSE", self.stacks, self)
        end,
    },

    PC_ALAN_APPLAUSE_plus =
    {
        name = "Visionary Applause",
        desc = "{PA_APPLAUSE|}Gain: When you shuffle your deck, deal {1} damage to random argument, then destroy this argument.\n<#UPGRADE>Draw a card</>.",
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_APPLAUSE", self.stacks, self)
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_APPLAUSE_plus2 =
    {
        name = "Boosted Applause",
        desc = "{PA_APPLAUSE|}Gain: When you shuffle your deck, deal <#UPGRADE>{1}</> damage to random argument, then destroy this argument.",
        stacks = 10,
    },

    PC_ALAN_CATCHPHRASE = 
    {
        name = "Catchphrase",
        desc = "For each turn, Whenever you draw a card after your initial hand for the first time, put this card back in your hand.",
        icon = "negotiation/influencer.tex",
        flavour = "'Anyway, that’s just how it is.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 2,
        max_persuasion = 4,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        max_xp = 10,
        back_to_hand = false,
        event_handlers =
        {
            [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                if not start_of_turn and not self.back_to_hand then
                    self:TransferCard( self.engine:GetHandDeck() )
                    self.back_to_hand = true
                end    
            end,

            [ EVENT.POST_RESOLVE ] = function(self, minigame, card)
                if card.negotiator == self.negotiator and (card.id == "PC_ALAN_PLEAD" or card.id == "PC_ALAN_PLEAD_plus") and not self.back_to_hand then
                    self:TransferCard( self.engine:GetHandDeck() )
                    self.back_to_hand = true
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self.negotiator:RemoveModifier( self )
                    self.back_to_hand = false
                end
            end,
        },
    },

    PC_ALAN_CATCHPHRASE_plus =
    {
        name = "Boosted Catchphrase",
        min_persuasion = 3,
        max_persuasion = 5,
    },

    PC_ALAN_CATCHPHRASE_plus2 =
    {
        name = "Reckless Catchphrase",
        desc = "<#UPGRADE>Whenever you</> <#DOWNGRADE>shuffle your deck</>, put this card back in your hand.",
        min_persuasion = 3,
        max_persuasion = 5,
        event_handlers =
        {
            [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                    
            end,

            [ EVENT.POST_RESOLVE ] = function(self, minigame, card)
                
            end,

            [ EVENT.SHUFFLE_DISCARDS ] = function( self, num_cards )
                self:TransferCard( self.engine:GetHandDeck() )
            end,
        },
    },

    PC_ALAN_FACEPALM = 
    {
        name = "Facepalm",
        desc = "Draw 3 cards.\n{PREPARED}: This card costs 1 less.",
        icon = "negotiation/dogged.tex",
        flavour = "'Give me a second to process this.'",
        cost = 2,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.STICKY,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        action_bonus = 1,
        draw_count = 3,
        PreReq = function( self, minigame )
            return self:IsPrepared()
        end,

        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(self.draw_count)
        end,

        event_priorities =
        {
            [ EVENT.CALC_ACTION_COST ] = EVENT_PRIORITY_ADDITIVE,
        },

        event_handlers = 
        {
            [ EVENT.CALC_ACTION_COST ] = function( self, acc, card, target )
                if card == self and self:IsPrepared() then
                    acc:AddValue(-self.action_bonus, self)
                end
            end,
        },
    },

    PC_ALAN_FACEPALM_plus =
    {
        name = "Visionary Argument",
        desc = "Draw <#UPGRADE>4</> cards.\n{PREPARED}: This card costs 1 less.",
        draw_count = 4,
    },

    PC_ALAN_FACEPALM_plus2 =
    {
        name = "Pale Argument",
        desc = "Draw 3 cards.\n{PREPARED}: <#UPGRADE>This card costs 0</>.",
        action_bonus = 999,
    },
    
    PC_ALAN_ENDURANCE =
    {
        name = "Endurance",
        icon = "negotiation/steamroll.tex",
        desc = "When drawn, Add a copy of this card to your discards.\n{EVOKE}: Play a same-named cards.",
        flavour = "'Don't push me!'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND | CARD_FLAGS.REPLENISH,
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 2,
        max_persuasion = 2,
        evoke_max = 1,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        event_handlers = 
        {
            [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                if self == card then
                    self.engine:PushPostHandler( function()
                        self:NotifyTriggeredPre()
                        local copy = self:Duplicate()
                        minigame:DealCard( copy, minigame:GetDiscardDeck() )
                        self:NotifyTriggeredPost()
                    end )
                end
            end,

            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                if card.owner == self.owner then
                    if card.id == "PC_ALAN_ENDURANCE" or card.base_id == "PC_ALAN_ENDURANCE" then
                        self:Evoke( self.evoke_max )
                    end
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self:ResetEvoke()
                end
            end,
        },
    },

    PC_ALAN_ENDURANCE_plus =
    {
        name = "Boosted Endurance",
        min_persuasion = 4,
        max_persuasion = 4,
    },

    PC_ALAN_ENDURANCE_plus2 =
    {
        name = "Enduring Endurance",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.REPLENISH,
        min_persuasion = 1,
        max_persuasion = 1,
    },

    PC_ALAN_TURN_THE_TABLES =
    {
        name = "Turn the Tables",
        icon = "negotiation/bulldoze.tex",
        desc = "Until the end of this turn, whenever you play a card, deal 3 damage to a random opponent argument.",
        flavour = "'You started it!'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_TURN_THE_TABLES", 1, self)
        end,
    },

    PC_ALAN_TURN_THE_TABLES_plus =
    {
        name = "Pale Turn the Tables",
        cost = 0,
    },

    PC_ALAN_TURN_THE_TABLES_plus2 =
    {
        name = "Enduring Turn the Tables",
        cost = 2,
        flags = CARD_FLAGS.HOSTILE,
    },

    PC_ALAN_HOT_COFFEE =
    {
        name = "Hot Coffee",
        icon = "negotiation/simmer.tex",
        desc = "While this is in your hand, all cards deal {1} bonus damage.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.bonus_damage )
        end,
        flavour = "'Still piping hot. Hope your face doesn’t need to feel it.'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.UNPLAYABLE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        bonus_damage = 1,
        deck_handlers = ALL_DECKS,
        event_handlers =
        {
            [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self then
                    if target_deck and target_deck:GetDeckType() == DECK_TYPE.IN_HAND and not (source_deck and source_deck:GetDeckType() == DECK_TYPE.IN_HAND) then
                        self.negotiator:AddModifier( "PC_ALAN_HOT_COFFEE", self.bonus_damage )

                    elseif source_deck and source_deck:GetDeckType() == DECK_TYPE.IN_HAND and not (target_deck and target_deck:GetDeckType() == DECK_TYPE.IN_HAND) then
                        self.negotiator:RemoveModifier( "PC_ALAN_HOT_COFFEE", self.bonus_damage )
                    end
                end
            end,

            [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                 if card == self then
                    self:AddXP(1)
                end
            end
        }
    },

    PC_ALAN_HOT_COFFEE_plus =
    {
        name = "Boosted Hot Coffee",
        desc = "While this is in your hand, all cards deal <#UPGRADE>{1}</> bonus damage.",
        bonus_damage = 2,
    },

    PC_ALAN_HOT_COFFEE_plus2 =
    {
        name = "Visionary Hot Coffee",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_DISTRACT_ATTENTION =
    {
        name = "Distract attention",
        icon = "negotiation/raw.tex",
        desc = "Move up to {1} cards from your draw pile to your discard.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.move_card_amt )
        end,
        flavour = "'Look, it's a coin!'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 1,
        max_persuasion = 4,
        move_card_amt = 3,
        OnPostResolve = function( self, minigame, targets )
            local cards = ObtainWorkTable()
                for i,card in minigame:GetDrawDeck():Cards() do
                        table.insert(cards, card)
                        if #cards >= self.move_card_amt then
                            break
                        end
                    end
            if #cards > 0 then
                for i,card in ipairs(cards) do
                    card:TransferCard(minigame:GetDiscardDeck())
                end
            end
        end
    },

    PC_ALAN_DISTRACT_ATTENTION_plus =
    {
        name = "Boosted Distract attention",
        desc = "Move up to <#UPGRADE>{1}</> cards from your draw pile to your discard.",
        move_card_amt = 5,
    },

    PC_ALAN_DISTRACT_ATTENTION_plus2 =
    {
        name = "Initial Distract attention",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_PUMP =
    {
        name = "Pump",
        icon = "negotiation/bolstered.tex",
        desc = "{PA_PUMP|}Create: Whenever you play a card, move up to {1} cards from your draw pile to your discard.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks )
        end,
        flavour = "'The Admiralty playing bodyguard? Now that's a rare sight.'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        stacks = 1,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PA_PUMP", self.stacks, self)
        end,
    },

    PC_ALAN_PUMP_plus =
    {
        name = "Boosted Pump",
        desc = "{PA_PUMP|}Create: Whenever you play a card, move up to <#UPGRADE>{1}</> cards from your draw pile to your discard.",
        stacks = 2,
    },

    PC_ALAN_PUMP_plus2 =
    {
        name = "Initial Pump",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_SOPHISTRY =
    {
        name = "Sophistry",
        icon = "negotiation/bluster.tex",
        desc = "{PA_UNIQUE}: Add 3 copies of this card to your discards.",
        flavour = "'Stop changing the subject! Just admit that's how it is!'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        min_persuasion = 3,
        max_persuasion = 4,
        count = 3,
        OnPostResolve = function( self, minigame )
            local is_unique = IsCardUnique(self)
            if is_unique then
                for i = 1, self.count do
                local copy = self:Duplicate()
                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))
                end
            end
        end,
    },

    PC_ALAN_SOPHISTRY_plus =
    {
        name = "Boosted Sophistry",
        min_persuasion = 5,
        max_persuasion = 6,
    },

    PC_ALAN_SOPHISTRY_plus2 =
    {
        name = "Fluent Sophistry",
        desc = "{PA_UNIQUE}: Add <#DOWNGRADE>2</> copies of this card to your discards.\n<#UPGRADE>{EVOKE}: Play a same-named cards</>.",
        count = 2,
        evoke_max = 1,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        event_handlers = 
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                if card.owner == self.owner then
                    if card.id == "PC_ALAN_SOPHISTRY" or card.base_id == "PC_ALAN_SOPHISTRY" then
                        self:Evoke( self.evoke_max )
                    end
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self:ResetEvoke()
                end
            end,
        },
    },

    PC_ALAN_ZINGER =
    {
        name = "Zinger",
        icon = "negotiation/quip.tex",
        desc = "Add 2 {silence} cards to your discard pile. \nCannot be played with {silence} in your hand.",
        flavour = "'Seriously, have you considered taking a trip to Roaloch? Roaloch might have your family waiting.'",
        loc_strings =
        {
            NO_INJURIES = "Cannot play with Silence in hand",
        },
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        min_persuasion = 7,
        max_persuasion = 9,
        count = 2,
        CanPlayCard = function( self, card, engine, target )
            local can_play = true
            for i,card in self.engine:GetHandDeck():Cards() do
                if card.id == "silence" then
                    can_play = false
                end
            end
            return can_play, self.def:GetLocalizedString( "NO_INJURIES" )
        end,
        OnPostResolve = function( self, minigame )
            local cards = {}
            for i=1, self.count do
                local card = Negotiation.Card('silence', self.owner)
                table.insert(cards, card)
            end
            minigame:DealCards( cards, minigame:GetDiscardDeck() )
        end,
    },

    PC_ALAN_ZINGER_plus =
    {
        name = "Tactless Zinger",
        desc = "Add <#DOWNGRADE>3</> {silence} cards to your discard pile. \nCannot be played with {silence} in your hand.",
        min_persuasion = 10,
        max_persuasion = 12,
        count = 3,
    },

    PC_ALAN_ZINGER_plus2 =
    {
        name = "Rooted Zinger",
        min_persuasion = 9,
    },

    PC_ALAN_INSULT =
    {
        name = "Insult",
        icon = "negotiation/reckless_insults.tex",
        desc = "Add a copy of this card to your discards. \n{PA_PRECURSUR} {1}: Draw a card.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.precursor_amt )
        end,
        flavour = "'Yo mama's so fat!'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        min_persuasion = 2,
        max_persuasion = 2,
        count = 1,
        precursor_amt = 10,
        OnPostResolve = function( self, minigame )
            for i=1, self.count do
                local copy = self:Duplicate()
                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))
            end

            local discards_count = DiscardPileCount(self)
            if discards_count >= self.precursor_amt then
                minigame:DrawCards(1)
            end
        end,
    },

    PC_ALAN_INSULT_plus =
    {
        name = "Tactless Insult",
        desc = "Add <#UPGRADE>2</> copy of this cards to your discards. \n{PA_PRECURSUR} <#DOWNGRADE>{1}</>: Draw a card.",
        min_persuasion = 3,
        max_persuasion = 3,
        count = 2,
        precursor_amt = 15,
    },

    PC_ALAN_INSULT_plus2 =
    {
        name = "Wide Insult",
        desc = "Add a copy of this card to your discards. \n{PA_PRECURSUR} <#UPGRADE>{1}</>: Draw a card.",
        precursor_amt = 7,
    },

    PC_ALAN_SUDDEN_OUTBURST =
    {
        name = "Sudden Outburst",
        icon = "negotiation/brute.tex",
        desc = "Deals {1} bonus damage for every {2} cards in discard pile.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.bonus_damage, self.count )
        end,
        flavour = "'Here, let me give you your f***ing reason!'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND | CARD_FLAGS.STICKY,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        min_persuasion = 0,
        max_persuasion = 0,
        bonus_damage = 4,
        count = 4,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self then
                    local discards_count = math.floor(DiscardPileCount(self) / self.count)
                    persuasion:AddPersuasion( self.bonus_damage * discards_count  , self.bonus_damage * discards_count, self)
                end
            end,
        },
    },

    PC_ALAN_SUDDEN_OUTBURST_plus =
    {
        name = "Softened Sudden Outburst",
        desc = "Deals <#DOWNGRADE>{1}</> bonus damage for every <#UPGRADE>{2}</> cards in discard pile.",
        bonus_damage = 1,
        count = 1,
    },

    PC_ALAN_SUDDEN_OUTBURST_plus2 =
    {
        name = "Boosted Sudden Outburst",
        desc = "Deals <#UPGRADE>{1}</> bonus damage for every 4 cards in discard pile.",
        bonus_damage = 5,
    },

    PC_ALAN_BROKEN_RECORD =
    {
        name = "Broken Record",
        icon = "negotiation/barrage.tex",
        desc = "{PA_BROKEN_RECORD|}Create: For every 7 cards played, Add a copy of 7th card to your discards.",
        flavour = "'Anyway, this is all you need to know. I can repeat it a hundred more times if I have to.'",
        cost = 2,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PA_BROKEN_RECORD", 1, self)
        end,
    },

    PC_ALAN_BROKEN_RECORD_plus =
    {
        name = "Pale Broken Record",
        cost = 1,
    },

    PC_ALAN_BROKEN_RECORD_plus2 =
    {
        name = "Initial Broken Record",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_BRINGING_UP_THE_PAST =
    {
        name = "Bringing Up the Past",
        icon = "negotiation/wild_rant.tex",
        desc = "For every {1} cards you have in your discard pile, play a random card in your discard pile.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.cards )
        end,
        flavour = "'That is NOT what you said two minutes ago!'",
        cost = 3,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 3,
        cards = 4,
        OnPostResolve = function( self, minigame )
            local discards_count = DiscardPileCount(self)
            local valid_cards = shallowcopy(self.engine:GetDiscardDeck().cards)
            for i,card in ipairs(valid_cards) do
                if card == self or card:IsFlagged( CARD_FLAGS.UNPLAYABLE ) then
                    table.remove(valid_cards, i)
                end
            end

            if #valid_cards > 0 then
                local times = math.floor(discards_count / self.cards)
                for i = 1, times do
                    local picked_card = table.arraypick(valid_cards)
                    picked_card:SetFlags(CARD_FLAGS.FREEBIE)
                    self.engine:PlayCard(picked_card)
                end
            end
        end,
    },

    PC_ALAN_BRINGING_UP_THE_PAST_plus =
    {
        name = "Enduring Bringing Up the Past",
        desc = "For every <#DOWNGRADE>{1}</> cards you have in your discard pile, play a random card in your discard pile.",
        flags = CARD_FLAGS.HOSTILE,
        cards = 6,
    },

    PC_ALAN_BRINGING_UP_THE_PAST_plus2 =
    {
        name = "Pale Bringing Up the Past",
        cost = 2,
    },

    PC_ALAN_SELF_PROCLAIMED_EXPERT =
    {
        name = "Self-Proclaimed Expert",
        icon = "negotiation/notion.tex",
        desc = "Add a copy of {PC_ALAN_BLUFF} to your hand for each action available. They cost 0 until played.",
        flavour = "'You don’t know how? Well, that’s just perfect.'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.VARIABLE_COST | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        upgraded = false,
        action_bonus = false,
        OnPostResolve = function( self, minigame, targets )
            local actions = minigame:GetActionCount()
            local cards = {}
            for i = 1, actions do
                local card = Negotiation.Card( "PC_ALAN_BLUFF", self.owner )
                if self.upgraded then
                    card:UpgradeCard()
                end
                card:SetFlags( CARD_FLAGS.FREEBIE )
                card:ClearXP()
                card:MakeTemporary()
                table.insert( cards, card )
            end
            minigame:DealCards( cards, minigame:GetHandDeck() )
            minigame:ModifyActionCount( -actions )
            if self.action_bonus then
                minigame:ModifyActionCount( 1 )
            end
        end,
    },

    PC_ALAN_SELF_PROCLAIMED_EXPERT_plus =
    {
        name = "Pale Self-Proclaimed Expert",
        desc = "Add a copy of {PC_ALAN_BLUFF} to your hand for each action available. They cost 0 until played.\n<#UPGRADE>Gain 1 action</>.",
        action_bonus = true,
    },

    PC_ALAN_SELF_PROCLAIMED_EXPERT_plus2 =
    {
        name = "Boosted Self-Proclaimed Expert",
        desc = "Add a copy of <#UPGRADE>randomly upgraded</> {PC_ALAN_BLUFF} to your hand for each action available. They cost 0 until played.",
        upgraded = true,
    },

    PC_ALAN_MEMO =
    {
        name = "Memo",
        icon = "negotiation/ransack.tex",
        desc = "Draw {1} cards. Gain {2} {PA_BASIC_SKILLS} for each basic card drawn.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.draw_count, self.basic_amt)
        end,
        flavour = "'Give me some time to look at the memo.'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.UNCOMMON,
        draw_count = 2,
        basic_amt = 1,
        OnPostResolve = function( self, minigame )
            local cards = minigame:DrawCards( self.draw_count )
            local basic = 0
            for i, card in ipairs( cards ) do
                if card.rarity == CARD_RARITY.BASIC then
                    basic = basic + 1
                end
            end
            self.negotiator:AddModifier( "PA_BASIC_SKILLS", (self.basic_amt * basic), self )
        end,
    },

    PC_ALAN_MEMO_plus =
    {
        name = "Visionary Memo",
        desc = "Draw <#UPGRADE>{1}</> cards. Gain {2} {PA_BASIC_SKILLS} for each basic card drawn.",
        draw_count = 3,
    },

    PC_ALAN_MEMO_plus2 =
    {
        name = "Boosted Memo",
        desc = "Draw {1} cards. Gain <#UPGRADE>{2}</> {PA_BASIC_SKILLS} for each basic card drawn.",
        basic_amt = 2,
    },

    PC_ALAN_HOLD_IT =
    {
        name = "Hold It",
        icon = "negotiation/reconsider.tex",
        desc = "Shuffle your deck, then draw {1} cards.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.draw_count)
        end,
        flavour = "'I need to regroup my thoughts.'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.UNCOMMON,
        draw_count = 3,
        OnPostResolve = function( self, minigame )
            minigame:ShuffleDiscardToDraw()
            minigame:DrawCards( self.draw_count )
        end,
    },

    PC_ALAN_HOLD_IT_plus =
    {
        name = "Visionary Hold It",
        desc = "Shuffle your deck, then draw <#UPGRADE>{1}</> cards.",
        draw_count = 4,
    },

    PC_ALAN_HOLD_IT_plus2 =
    {
        name = "Pale Hold It",
        desc = "Shuffle your deck, then draw <#DOWNGRADE>{1}</> cards.",
        cost = 0,
        draw_count = 2,
    },

    PC_ALAN_CAUSE_AND_EFFECT =
    {
        name = "Cause and Effect",
        icon = "negotiation/tactical_mind.tex",
        desc = "{PA_CAUSE_AND_EFFECT|}Gain {1} {PA_CAUSE_AND_EFFECT}.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.count)
        end,
        flavour = "'Smith squinted again—after all, nothing pairs with a full stomach quite like a nap.'",
        cost = 1,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MANIPULATE,
        max_xp = 9,
        count = 3,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_CAUSE_AND_EFFECT", self.count, self)
        end
    },

    PC_ALAN_CAUSE_AND_EFFECT_plus =
    {
        name = "Boosted Cause and Effect",
        desc = "{PA_CAUSE_AND_EFFECT|}Gain <#UPGRADE>{1}</> {PA_CAUSE_AND_EFFECT}.",
        count = 4,
    },

    PC_ALAN_CAUSE_AND_EFFECT_plus2 =
    {
        name = "Mirrored Cause and Effect",
        desc = "{PA_CAUSE_AND_EFFECT|}Gain <#UPGRADE>{1}</> {PA_CAUSE_AND_EFFECT}.",
        cost = 2,
        count = 7,
    },

    PC_ALAN_REDUNDANT_REMINDER =
    {
        name = "Redundant Reminder",
        icon = "negotiation/nonsequitur.tex",
        desc = "Deal 1 to 3 damage.\nShuffle your deck once per resolve lost.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.draw_count)
        end,
        flavour = "'So what exactly do you think the guns and blades are for? Or did you seriously think people go into the wild empty-handed?'",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.UNCOMMON,
        min = 1,
        max = 3,
        OnPostResolve = function( self, minigame, targets )
            for i,target in ipairs(targets) do
                minigame:ApplyPersuasion( self, target, self.min, self.max )
            end

            if self.damage_dealt then
                for i = 1, self.damage_dealt do
                    minigame:ShuffleDiscardToDraw()
                end
            end
            self.damage_dealt = nil
        end,
        event_handlers =
        {
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                if source == self then
                    self.damage_dealt = damage - defended
                end
            end,
        }, 
    },

    PC_ALAN_REDUNDANT_REMINDER_plus =
    {
        name = "Tall Redundant Reminder",
        desc = "Deal 1 to <#UPGRADE>5</> damage.\nShuffle your deck once per resolve lost.",
        max = 5,
    },

    PC_ALAN_REDUNDANT_REMINDER_plus2 =
    {
        name = "Rooted Redundant Reminder",
        desc = "Deal <#UPGRADE>3</> damage.\nShuffle your deck once per resolve lost.",
        min = 3,
    },

    PC_ALAN_NONSENSE =
    {
        name = "Nonsense",
        icon = "negotiation/gab.tex",
        desc = "Apply {1} {COMPOSURE}.\nAdd a copy of this card to your discards.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self:CalculateComposureText(self.composure_amt) )
        end,
        flavour = "'We have been talking for about 60 seconds, which is a minute, and roughly the same amount of time we've been talking.'",
        cost = 0,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        composure_amt = 3,
        target_self = TARGET_ANY_RESOLVE,
        OnPostResolve = function( self, minigame, targets )
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
            end
            local copy = self:Duplicate()
            minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))
        end
    },

    PC_ALAN_NONSENSE_plus =
    {
        name = "Stone Nonsense",
        desc = "Apply <#UPGRADE>{1}</> {COMPOSURE}.\nAdd a copy of this card to your discards.",
        composure_amt = 5,
    },

    PC_ALAN_NONSENSE_plus2 =
    {
        name = "Twisted Nonsense",
        desc = "Add a copy of this card to your discards.",
        min_persuasion = 3,
        max_persuasion = 5,
        composure_amt = 0,
        target_enemy = TARGET_ANY_RESOLVE,
        OnPostResolve = function( self, minigame, targets )
            local copy = self:Duplicate()
            minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))
        end
    },

    PC_ALAN_DEEP_BREATH =
    {
        name = "Deep Breath",
        icon = "negotiation/second_wind.tex",
        desc = "Remove one of your arguments, inceptions, or bounties.\nGain {1} {COMPOSURE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ))
        end,
        flavour = "'Just... give me a moment.'",
        cost = 0,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH | CARD_FLAGS.STICKY,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        composure_amt = 3,
        Reconsider = function( self, minigame, targets )
            for i, target in ipairs( targets ) do
                target:GetNegotiator():RemoveModifier( target )
            end
            self.negotiator:DeltaComposure( self.composure_amt, self )
        end,
        OnPostResolve = function( self, minigame, targets )
            self:Reconsider(minigame, targets)
        end,
    },

    PC_ALAN_DEEP_BREATH_plus =
    {
        name = "Visionary Deep Breath",
        desc = "Remove one of your arguments, inceptions, or bounties.\nGain {1} {COMPOSURE}<#UPGRADE>and draw a card</>.",
        OnPostResolve = function( self, minigame, targets )
            self:Reconsider(minigame, targets)
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_DEEP_BREATH_plus2 =
    {
        name = "Stone Deep Breath",
        desc = "Remove one of your arguments, inceptions, or bounties.\nGain <#UPGRADE>{1}</> {COMPOSURE}.",
        composure_amt = 6,
    },

    PC_ALAN_PRAY =
    {
        name = "Pray",
        icon = "negotiation/propaganda.tex",
        desc = "Apply {1} resolve and {2} {COMPOSURE}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.resolve_gain, self:CalculateComposureText(self.composure_amt) )
        end,
        flavour = "'The god of the Abyss manifests—not in grace nor in judgment, but as that which arises from the hearts of beings.'",
        cost = 1,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        resolve_gain = 2,
        composure_amt = 2,
        target_self = TARGET_ANY_RESOLVE,
        OnPostResolve = function( self, minigame, targets )
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
                target:ModifyResolve( self.resolve_gain, self )
            end
        end
    },

    PC_ALAN_PRAY_plus =
    {
        name = "Mending Pray",
        desc = "Apply <#UPGRADE>{1}</> resolve and {2} {COMPOSURE}.",
        resolve_gain = 4,
    },

    PC_ALAN_PRAY_plus2 =
    {
        name = "Stone Pray",
        desc = "Apply {1} resolve and <#UPGRADE>{2}</> {COMPOSURE}.",
        composure_amt = 4,
    },

    PC_ALAN_REITERATE =
    {
        name = "Reiterate",
        icon = "negotiation/recall.tex",
        desc = "Play a random card in your trash deck.\n{PA_UNIQUE}: This card cost 3 less.",
        flavour = "I’ve said this before, haven’t I? Do I need to repeat myself?",
        cost = 4,
        max_xp = 7,
        num_cards = 1,
        action_bonus = -3,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.UNCOMMON,
        OnPostResolve = function( self, minigame )
            for j = 1, self.num_cards do
                local valid_cards = shallowcopy(self.engine:GetTrashDeck().cards)
                for i,card in ipairs(valid_cards) do
                    if card == self or card:IsFlagged( CARD_FLAGS.UNPLAYABLE ) then
                        table.remove(valid_cards, i)
                    end
                end
                if #valid_cards > 0 then
                    local card = table.arraypick(valid_cards)
                    card:SetFlags(CARD_FLAGS.FREEBIE)
                    self.engine:PlayCard(card)
                end
            end
        end,
        event_handlers =
        {
            [ EVENT.CALC_ACTION_COST ] = function( self, acc, card, target )
            local is_unique = IsCardUnique(self)
                if card == self and is_unique then
                    acc:AddValue( self.action_bonus, self )
                end
            end,
        },
    },

    PC_ALAN_REITERATE_plus =
    {
        name = "Clarity Reiterate",
        desc = "Play <#UPGRADE>3 random cards</> in your trash deck.\n{PA_UNIQUE}: This card cost 3 less.",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        num_cards = 3,
    },

    PC_ALAN_REITERATE_plus2 =
    {
        name = "Pale Reiterate",
        desc = "Play a random card in your trash deck.\n{PA_UNIQUE}: This card cost <#UPGRADE>4</> less.",
        action_bonus = -4,
    },

    PC_ALAN_WITNESS =
    {
        name = "Witness",
        icon = "negotiation/placate.tex",
        desc = "Choose a card from your hand, then add a copy of that card in your hand.\n{PA_UNIQUE}: the copy costs 0.",
        loc_strings =
        {
            CHOOSE_CARD = "Choose a card to copy it" 
        },
        flavour = "'Don't touch that flower! It's the successor to the pigeon!'",
        cost = 2,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.BURNOUT,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        num_cards = 1,
        OnPostResolve = function( self, minigame, targets )
            for i=1,self.num_cards do
                local txt = loc.format( LOC"CARD_ENGINE.CHOOSE_MAX_CARDS_DUPLICATE", 1 )
                local chosen_card = minigame:ChooseCard( nil, txt )

                if chosen_card then
                    local copy = chosen_card:Duplicate()
                    copy.deck = nil
                    
                    local is_unique = IsCardUnique(self)
                    if is_unique then
                        copy.cost = 0
                    else
                        copy.cost = minigame:CalculateActionCost(chosen_card)
                    end

                    minigame:DealCard(copy, minigame:GetHandDeck())
                end
            end
        end,
    },

    PC_ALAN_WITNESS_plus =
    {
        name = "Stable Witness",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
    },

    PC_ALAN_WITNESS_plus2 =
    {
        name = "Wide Witness",
        cost = 3,
        desc = "Choose a card from your hand <#UPGRADE>twice</>, then add a copy of those cards in your hand.\n{PA_UNIQUE}: the copies costs 0.",
        num_cards = 2,
    },

    PC_ALAN_SQUARE_TABLE_MEETING =
    {
        name = "Square Table Meeting",
        icon = "negotiation/center_of_attention.tex",
        desc = "{PA_SQUARE_TABLE_MEETING|}Create: Whenever you play {PC_ALAN_DISCUSS}, {EXPEND} it. At the end of your turn, play all {PC_ALAN_DISCUSS} in your trash deck.",
        flavour = "'The more, the merrier!'",
        cost = 3,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 3,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PA_SQUARE_TABLE_MEETING", 1, self)
        end
    },

    PC_ALAN_SQUARE_TABLE_MEETING_plus =
    {
        name = "Initial Square Table Meeting",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_SQUARE_TABLE_MEETING_plus2 =
    {
        name = "Pale Square Table Meeting",
        cost = 2,
    },

    PC_ALAN_WITNESS =
    {
        name = "Witness",
        icon = "negotiation/placate.tex",
        desc = "Choose a card from your hand, then add a copy of that card in your hand.\n{PA_UNIQUE}: the copy costs 0.",
        loc_strings =
        {
            CHOOSE_CARD = "Choose a card to copy it" 
        },
        flavour = "'Don't touch that flower! It's the successor to the pigeon!'",
        cost = 2,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.BURNOUT,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        num_cards = 1,
        OnPostResolve = function( self, minigame, targets )
            for i=1,self.num_cards do
                local txt = loc.format( LOC"CARD_ENGINE.CHOOSE_MAX_CARDS_DUPLICATE", 1 )
                local chosen_card = minigame:ChooseCard( nil, txt )

                if chosen_card then
                    local copy = chosen_card:Duplicate()
                    copy.deck = nil
                    
                    local is_unique = IsCardUnique(self)
                    if is_unique then
                        copy.cost = 0
                    else
                        copy.cost = minigame:CalculateActionCost(chosen_card)
                    end

                    minigame:DealCard(copy, minigame:GetHandDeck())
                end
            end
        end,
    },

    PC_ALAN_WITNESS_plus =
    {
        name = "Stable Witness",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
    },

    PC_ALAN_WITNESS_plus2 =
    {
        name = "Wide Witness",
        cost = 3,
        desc = "Choose a card from your hand <#UPGRADE>twice</>, then add a copy of those cards in your hand.\n{PA_UNIQUE}: the copies costs 0.",
        num_cards = 2,
    },

    PC_ALAN_SQUARE_TABLE_MEETING =
    {
        name = "Square Table Meeting",
        icon = "negotiation/center_of_attention.tex",
        desc = "{PA_SQUARE_TABLE_MEETING|}Create: Whenever you play {PC_ALAN_DISCUSS}, {EXPEND} it. At the end of your turn, play all {PC_ALAN_DISCUSS} in your trash deck.",
        flavour = "'The more, the merrier!'",
        cost = 3,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 3,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PA_SQUARE_TABLE_MEETING", 1, self)
        end
    },

    PC_ALAN_SQUARE_TABLE_MEETING_plus =
    {
        name = "Initial Square Table Meeting",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_SQUARE_TABLE_MEETING_plus2 =
    {
        name = "Pale Square Table Meeting",
        cost = 2,
    },

    PC_ALAN_CONSENSUS =
    {
        name = "Consensus",
        icon = "negotiation/compromise.tex",
        desc = "{PA_TRUST|}Apply {1} {COMPOSURE}\n{PA_UNIQUE}: Gain 1 {PA_TRUST}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self:CalculateComposureText(self.composure_amt) )
        end,
        flavour = "'Trust me, nothing is going to go wrong.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.RARE,
        target_self = TARGET_ANY_RESOLVE,
        max_xp = 10,
        composure_amt = 2,
        OnPostResolve = function( self, minigame, targets )
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
            end
            local is_unique = IsCardUnique(self)
            if is_unique then
                self.negotiator:CreateModifier("PA_TRUST", 1, self)
            end
        end
    },

    PC_ALAN_CONSENSUS_plus =
    {
        name = "Stone Consensus",
        desc = "{PA_TRUST|}Apply <#UPGRADE>{1}</> {COMPOSURE}\n{PA_UNIQUE}: Gain 1 {PA_TRUST}.",
        composure_amt = 4,
        
    },

    PC_ALAN_CONSENSUS_plus2 =
    {
        name = "Initial Consensus",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_CHIME_IN =
    {
        name = "Chime In",
        icon = "negotiation/ipso_facto.tex",
        desc = "{PA_CHIME_IN|}Gain: Whenever you draw a basic card, gain {1} {COMPOSURE} and deal {1} damage to a random opponent argument.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.count)
        end,
        flavour = "'Exactly!'",
        cost = 2,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 7,
        count = 1,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_CHIME_IN", self.count, self)
        end
    },

    PC_ALAN_CHIME_IN_plus =
    {
        name = "Initial Chime In",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_CHIME_IN_plus2 =
    {
        name = "Boosted Chime In",
        desc = "{PA_CHIME_IN|}Gain: Whenever you draw a basic card, gain <#UPGRADE>{1}</> {COMPOSURE} and deal <#UPGRADE>{1}</> damage to a random opponent argument.",
        count = 2,
    },
    
    PC_ALAN_HYPE_UP =
    {
        name = "Hype Up",
        icon = "negotiation/flatter.tex",
        desc = "Gain {PA_SHUFFLE} twice to damage dealt by this card.",
        flavour = "'Well said!'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.RARE,
        min_persuasion = 1,
        max_persuasion = 2,
        max_xp = 9,
        event_handlers =
        {
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                if source == self and damage > 0 then
                    self.negotiator:AddModifier("PA_SHUFFLE", (2 * damage), self)
                end
            end
        },
    },

    PC_ALAN_HYPE_UP_plus =
    {
        name = "Boosted Hype Up",
        min_persuasion = 2,
        max_persuasion = 3,
    },

    PC_ALAN_HYPE_UP_plus2 =
    {
        name = "Tentative Hype Up",
        desc = "Gain {PA_SHUFFLE} twice to damage dealt by this card.\n<#UPGRADE>{PA_TENTATIVE} {1}: deal 2 bonus damage</>.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.tentative_amt)
        end,
        tentative_amt = 2,
        event_handlers = 
        {
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                if source == self and damage > 0 then
                    self.negotiator:AddModifier("PA_SHUFFLE", (2 * damage), self)
                end
            end,

            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self and self.negotiator:GetModifierStacks("PA_DRAW_CARD") > self.tentative_amt then
                    persuasion:AddPersuasion( 2, 2, self )
                end
            end,
        },
    },

    PC_ALAN_CARDS_ON_THE_TABLE =
    {
        name = "Cards on the Table",
        icon = "negotiation/airtight.tex",
        desc = "Draw cards until your hand is full.",
        flavour = "'Let me give it to you straight.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 9,
        OnPostResolve = function( self, minigame )
            minigame:DrawCards( 10 - self.engine:GetHandDeck():CountCards() )
        end,
    },

    PC_ALAN_CARDS_ON_THE_TABLE_plus =
    {
        name = "Sticky Cards on the Table",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.STICKY,
    },

    PC_ALAN_CARDS_ON_THE_TABLE_plus2 =
    {
        name = "Pale Cards on the Table",
        cost = 0,
    },

    PC_ALAN_TAUNT =
    {
        name = "Taunt",
        icon = "negotiation/degrade.tex",
        desc = "Gain 1 {COMPOSURE} and deal an additional 1 damage for every 4 cards in discard pile.\nAdd a copy of this card to your discards.",
        flavour = "'You're nothing but a loser.'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.RARE,
        max_xp = 10,
        min_persuasion = 2,
        max_persuasion = 4,
        discard = false,
        move_card = false,
        OnPostResolve = function( self, minigame )
            if self.discard then
                minigame:DiscardCards(2, 2, self)
            end

            if self.move_card then
                local cards = ObtainWorkTable()
                for i,card in minigame:GetDrawDeck():Cards() do
                    table.insert(cards, card)
                    if #cards >= 3 then
                        break
                    end
                end
                if #cards > 0 then
                    for i,card in ipairs(cards) do
                        card:TransferCard(minigame:GetDiscardDeck())
                    end
                end
            end

            local discards_count = math.floor(DiscardPileCount(self) / 4)
            self.negotiator:DeltaComposure( discards_count, self )
            minigame:ApplyPersuasion( self, nil, discards_count, discards_count )
            local copy = self:Duplicate()
            minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))
        end,
    },

    PC_ALAN_TAUNT_plus =
    {
        name = "Strained Taunt",
        desc = "<#DOWNGRADE>Discard 2 cards</>.\nGain 1 {COMPOSURE} and deal an additional 1 damage for every 4 cards in discard pile.\nAdd a copy of this card to your discards.",
        discard = true,
        min_persuasion = 4,
        max_persuasion = 6,
    },

    PC_ALAN_TAUNT_plus2 =
    {
        name = "Boosted Taunt",
        desc = "<#UPGRADE>Move up to 3 cards from your draw pile to your discard</>.\nGain 1 {COMPOSURE} and deal an additional 1 damage for every 4 cards in discard pile.\nAdd a copy of this card to your discards.",
        move_card = true,
    },

    PC_ALAN_TAKE_BACK =
    {
        name = "Take-Back",
        icon = "negotiation/refusal.tex",
        desc = "When this card is drawn, discard your hand and draw 5 cards, then {EXPEND}.",
        flavour = "'That didn't count!'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.UNPLAYABLE,
        rarity = CARD_RARITY.RARE,
        max_xp = 10,
        event_handlers =
        {
            [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                if card == self then
                    self:NotifyTriggeredPre()

                    local tbl = ObtainWorkTable()
                    for i, card in minigame:GetHandDeck():Cards() do
                        table.insert(tbl, card)
                    end

                    for i, card in ipairs(tbl) do
                        minigame:DiscardCard(card)
                    end

                    ReleaseWorkTable(tbl)

                    minigame:DrawCards(5)

                    if self.tentative and self.negotiator:GetModifierStacks("PA_DRAW_CARD") > self.tentative_amt then
                        minigame:DrawCards(2)
                    end

                    self:NotifyTriggeredPost()
                    self:AddXP(1)
                    minigame:ExpendCard( self )
                end
            end
        },
    },

    PC_ALAN_TAKE_BACK_plus =
    {
        name = "Enduring Take-Back",
        desc = "<#DOWNGRADE>Once per turn</>, when this card is drawn, discard your hand and draw 5 cards.",
        active = true,
        event_handlers =
        {
            [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                if card == self and self.active then
                    self:NotifyTriggeredPre()

                    local tbl = ObtainWorkTable()
                    for i, card in minigame:GetHandDeck():Cards() do
                        table.insert(tbl, card)
                    end

                    for i, card in ipairs(tbl) do
                        minigame:DiscardCard(card)
                    end

                    ReleaseWorkTable(tbl)

                    minigame:DrawCards(5)

                    self:NotifyTriggeredPost()

                    self.active = false
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self.active = true
                end
            end,
        },
    },

    PC_ALAN_TAKE_BACK_plus2 =
    {
        name = "Tentative Take-Back",
        desc = "When this card is drawn, discard your hand and draw 5 cards, then {EXPEND}.\n<#UPGRADE>{PA_TENTATIVE} {1}: Draw additional 2 cards</>.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.tentative_amt)
        end,
        tentative = true,
        tentative_amt = 1,
    },

    PC_ALAN_PROHIBIT =
    {
        name = "Prohibit",
        icon = "negotiation/domain.tex",
        desc = "Play this card twice.\n{BRAVADO}.",
        flavour = "'Yotes—and you—are not allowed in!'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.RARE,
        min_persuasion = 1,
        max_persuasion = 2,
        max_xp = 9,
        deck_handlers = ALL_DECKS,
        bonus_damage = 1,
        OnPostResolve = function( self, minigame, targets )
            if not self.ignore then
                self.ignore = true
                minigame:PlayCard(self)
            else
                self.ignore = false
            end
        end,
        event_handlers = 
        {
            [ EVENT.END_RESOLVE ] = function( self, minigame, card )
                if card.negotiator == self.negotiator then
                    if CheckBits(card.flags, CARD_FLAGS.HOSTILE) then
                        self.bonus = (self.bonus or 0) + self.bonus_damage
                    else
                        self.bonus = 0
                    end
                end
            end,

            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self and self.bonus and self.bonus > 0 then
                    persuasion:AddPersuasion(self.bonus, self.bonus, self)
                end
            end,

            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                self.bonus = 0
            end,
        },
    },

    PC_ALAN_PROHIBIT_plus =
    {
        name = "Sticky Prohibit",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.STICKY,
    },

    PC_ALAN_PROHIBIT_plus2 =
    {
        name = "Boosted Prohibit",
        min_persuasion = 2,
        max_persuasion = 3,
    },

    PC_ALAN_VICIOUS_WORDS =
    {
        name = "Vicious Words",
        icon = "negotiation/improvise_mean.tex",
        desc = "This card costs the absolute difference between its initial cost of this card and the number of cards in the discard pile.",
        flavour = "'Brainless idiot!'",
        cost = 13,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.RARE,
        min_persuasion = 13,
        max_persuasion = 13,
        max_xp = 3,
        event_priorities =
        {
            [ EVENT.CALC_ACTION_COST ] = EVENT_PRIORITY_PRESETTOR
        },
        deck_handlers = ALL_DECKS,
        event_handlers =
        {
            [ EVENT.CALC_ACTION_COST ] = function( self, cost_acc, card, target )
                if card == self then
                    local discards_count = DiscardPileCount(self)
                    cost_acc:ModifyValue( math.abs(card.def.cost - discards_count), self )
                end
            end,
        },
    },

    PC_ALAN_VICIOUS_WORDS_plus =
    {
        name = "Sticky Pressure",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.STICKY,
    },

    PC_ALAN_VICIOUS_WORDS_plus2 =
    {
        name = "Pale Pressure",
        cost = 7,
    },

    PC_ALAN_PRESSURE =
    {
        name = "Pressure",
        icon = "negotiation/overbear.tex",
        desc = "Gain {1} {DOMINANCE}.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.dominance_amt)
        end,
        flavour = "'You had better think twice.'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
        rarity = CARD_RARITY.RARE,
        max_xp = 10,
        dominance_amt = 2,
        draw_card = false,
        OnPostResolve = function( self, minigame )
            self.negotiator:AddModifier("DOMINANCE", self.dominance_amt, self)
            if self.draw_card then
                minigame:DrawCards(2)
            end
        end,
    },

    PC_ALAN_PRESSURE_plus =
    {
        name = "Boosted Pressure",
        desc = "Gain <#UPGRADE>{1}</> {DOMINANCE}.",
        dominance_amt = 3,
    },

    PC_ALAN_PRESSURE_plus2 =
    {
        name = "Visionary Pressure",
        desc = "Gain {1} {DOMINANCE}.\n<#UPGRADE>Draw 2 cards</>.",
        draw_card = true,
    },

    PC_ALAN_DEFLECTION =
    {
        name = "Deflection",
        icon = "negotiation/deflection.tex",
        desc = "Choose a friendly argument except core argument, {SHIELDED|Shield} it until the end of negotiation.",
        loc_strings =
        {
            AMNESTY_SHIELD_DESC = "{SHIELDED}. This argument is shielded!",
        },
        flavour = "'There's no need to discuss that point.'",
        cost = 3,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 3,
        target_self = TARGET_FLAG.ARGUMENT | TARGET_FLAG.BOUNTY,
        OnPostResolve = function( self, minigame, targets )
            for i,arg in ipairs(targets) do
                arg:SetShieldStatus(true, self.def:GetLocalizedString("AMNESTY_SHIELD_DESC"))
            end
        end,
    },

    PC_ALAN_DEFLECTION_plus =
    {
        name = "Initial Deflection",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_DEFLECTION_plus2 =
    {
        name = "Visionary Deflection",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_POWER_MOVE =
    {
        name = "Power Move",
        icon = "negotiation/fallout.tex",
        desc = "{INCEPT} {1} {FLUSTERED} and {VULNERABILITY}.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.stacks)
        end,
        flavour = "'Come on! Have a drink first!'",
        cost = 1,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 9,
        stacks = 3,
        OnPostResolve = function( self, minigame, card )
            self.anti_negotiator:InceptModifier("FLUSTERED", self.stacks, self )
            self.anti_negotiator:InceptModifier("VULNERABILITY", self.stacks, self )
        end,
    },

    PC_ALAN_POWER_MOVE_plus =
    {
        name = "Boosted Power Move",
        desc = "{INCEPT} <#UPGRADE>{1}</> {FLUSTERED} and {VULNERABILITY}.",
        stacks = 5,
    },

    PC_ALAN_POWER_MOVE_plus2 =
    {
        name = "Initial Power Move",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_ECHO =
    {
        name = "Echo",
        icon = "negotiation/ditch.tex",
        desc = "{PA_ECHO|}Gain {1} {PA_ECHO}.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.stacks)
        end,
        flavour = "'It’s like this, like this, this...'",
        cost = 1,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 9,
        stacks = 2,
        OnPostResolve = function( self, minigame, card )
            self.negotiator:CreateModifier("PA_ECHO", self.stacks, self)
        end,
    },

    PC_ALAN_ECHO_plus =
    {
        name = "Enduring Echo",
        desc = "{PA_ECHO|}Gain <#DOWNGRADE>{1}</> {PA_ECHO}.",
        flags = CARD_FLAGS.MANIPULATE,
        stacks = 1,
    },

    PC_ALAN_ECHO_plus2 =
    {
        name = "Initial Echo",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_INSPIRATION =
    {
        name = "Inspiration",
        icon = "negotiation/quick_thinking.tex",
        desc = "Draw {1} cards and gain 1 action.\n{PA_UNIQUE}: Whenever you shuffle your deck, this card costs 1 less until played.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.draw_count)
        end,
        flavour = "'Wait, I think you got one thing wrong there.'",
        cost = 3,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.RARE,
        max_xp = 3,
        draw_count = 2,
        action_bonus = 0,
        deck_handlers = ALL_DECKS,
        OnPostResolve = function( self, minigame, card )
            minigame:DrawCards(self.draw_count)
            minigame:ModifyActionCount(1)
            self.action_bonus = 0
        end,
        event_priorities =
        {
            [ EVENT.CALC_ACTION_COST ] = EVENT_PRIORITY_ADDITIVE,
        },
        event_handlers = 
        {
            [ EVENT.CALC_ACTION_COST ] = function( self, acc, card, target )
                if card == self then
                    acc:AddValue(-self.action_bonus, self)
                end
            end,

            [ EVENT.SHUFFLE_DISCARDS ] = function( self, num_cards )
                local is_unique = IsCardUnique(self)
                if is_unique then
                    self.action_bonus = self.action_bonus + 1
                end
            end
        },
    },

    PC_ALAN_INSPIRATION_plus =
    {
        name = "Sticky Inspiration",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.STICKY,
    },

    PC_ALAN_INSPIRATION_plus2 =
    {
        name = "Pale Inspiration",
        cost = 2,
    },
}

for i, id, carddef in sorted_pairs( CARDS ) do
    carddef.series = "SHEL"
    Content.AddNegotiationCard( id, carddef )
end

local FEATURES =
{
    PA_TENTATIVE =
    {
        name = "Tentative",
        desc = "Whenever the number of cards that you draw <#HILITE>after your initial hand</> reaches a certain amount , an additional effect will be triggered.",
    },

    PA_UNIQUE =
    {
        name = "Unique",
        desc = "If the card is the <#HILITE>only same-named cards</> in the deck, it gains an additional effect when played.\nCards that are <#HILITE>not upgraded</>, are <#HILITE>upgraded with different options</>, or are <#HILITE>duplicated in negotiation</> will all <#HILITE>be counted as same-named cards</>."
    },

    PA_PRECURSUR =
    {
        name = "Precursor",
        desc = "Whenever the number of cards that in <#HILITE>discard pile</> reaches a certain amount , an additional effect will be triggered."
    },
}

for id, data in pairs(FEATURES) do
    local def = NegotiationFeatureDef(id, data)
    Content.AddNegotiationCardFeature(id, def)
end
