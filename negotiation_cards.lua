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
        name = "Well-reasoned",
        desc = "All friendly arguments deal 1 bonus damage.",
        modifier_type = MODIFIER_TYPE.CORE,
        icon = "negotiation/modifiers/deadline.tex",
        icon_force_flip = true,
        event_priorities =
        {
            [ EVENT.CALC_PERSUASION ] = EVENT_PRIORITY_ADDITIVE,
        },

        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source.owner == self.owner
                and is_instance( source, Negotiation.Modifier )
                and source.modifier_type ~= MODIFIER_TYPE.INCEPTION
                and source.modifier_type ~= MODIFIER_TYPE.BOUNTY
                and source:IsAttack() then
                    persuasion:AddPersuasion( 1, 1, self )
                end
            end
        }
    },

    PC_ALAN_TRUTH =
    {
        name = "Truth",
        desc = "For every 3 modifiers, deal 1 bonus damage.",
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        icon = "negotiation/modifiers/rumor_monger.tex",
        sound = "event:/sfx/battle/cards/neg/create_argument/vulnerability",
        max_resolve = 4,
        min_persuasion = 1,
        max_persuasion = 1,
        target_enemy = TARGET_ANY_RESOLVE,
        IsValidTarget = function( target )
            return target:GetResolve() ~= nil
        end,

        OnApply = function( self )
            self:PrepareTurn()
        end,

        event_handlers =
        {
            [ EVENT.MODIFIER_ADDED ] = function( self, modifier, source )
            self.min_persuasion = self.def.min_persuasion
            self.max_persuasion = self.def.max_persuasion
            local mod_num = CountArguments(self)
            local bonus_damage = math.floor(mod_num / 3)
                self.min_persuasion, self.max_persuasion = (self.stacks + bonus_damage), (self.stacks + bonus_damage)
            end,

            [ EVENT.MODIFIER_REMOVED ] = function( self, modifier, source )
            self.min_persuasion = self.def.min_persuasion
            self.max_persuasion = self.def.max_persuasion
            local mod_num = CountArguments(self)
            local bonus_damage = math.floor(mod_num / 3)
                self.min_persuasion, self.max_persuasion = (self.stacks + bonus_damage), (self.stacks + bonus_damage)
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
            self.min_persuasion = self.def.min_persuasion
            self.max_persuasion = self.def.max_persuasion
            local mod_num = CountArguments(self)
            local bonus_damage = math.floor(mod_num / 3)
            self.min_persuasion, self.max_persuasion = (self.stacks + bonus_damage), (self.stacks + bonus_damage)
                if negotiator == self.negotiator then
                    self:ApplyPersuasion()
                end
            end,
        },
    },

    PC_ALAN_GENUINE = 
    {
        name = "Genuine",
        desc = "At the end of the turn, if the stacks of {PC_ALAN_GENUINE} is more than opponent's core resovle, win the negotiation and upgrade their opinion of you by one level.",
        icon = "negotiation/modifiers/puppy_snail_eyes.tex",
        sound = "event:/sfx/battle/cards/neg/create_argument/vulnerability",
        modifier_type = MODIFIER_TYPE.INCEPTION,
        event_handlers =
        {
            [ EVENT.END_TURN ] = function( self, minigame, agent )
            local genuine = self.negotiator:GetModifierStacks("PC_ALAN_GENUINE")
            local enemy_resolve = self.anti_negotiator:GetResolve()
            if genuine > enemy_resolve then
                minigame:Win()
                self.anti_negotiator.agent:OpinionEvent( OPINION.GENUINE )
            end
            end
        } 
    },

    PC_ALAN_RUDE =
    {
        name = "Rude",
        desc = "All resolve loss is increased by 2. Remove 1 stack at the start of your turn. At the end of the negotiation, if opponent still having this inception, downgrade their opinion of you by one level.",
        icon = "negotiation/modifiers/animosity.tex",
        sound = "event:/sfx/battle/cards/neg/create_argument/vulnerability",
        modifier_type = MODIFIER_TYPE.INCEPTION,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion, minigame, target )
                if target and target.owner == self.owner then
                    persuasion:AddPersuasion( 2, 2, self )
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self.negotiator:RemoveModifier(self, 1, self)
                end
            end,

            [ EVENT.END_NEGOTIATION ] = function( self, source, negotiator, minigame, target, agent )
                self.negotiator.agent:OpinionEvent( OPINION.ARRRESSIVE )
            end
        }
    },

    PC_ALAN_FALLACY =
    {
        name = "Fallacy",
        desc = "At the end of your turn, deal 3 damage to a random opponent arguments for every stack of {PC_ALAN_FALLACY}.\nAt the begin of your turn, clear all stacks.",
        icon = "negotiation/modifiers/hostility.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        min_persuasion = 3,
        max_persuasion = 3,
        max_resolve = 1,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        OnSetStacks = function( self, old_stacks )
            self.min_persuasion, self.max_persuasion = self.min_persuasion, self.max_persuasion
        end,

        OnApply = function( self )
            self:PrepareTurn()
        end,
        event_handlers =
        {
            [ EVENT.END_PLAYER_TURN ] = function( self, minigame )
            self.target_enemy = TARGET_ANY_RESOLVE
                for i = 1, self.negotiator:GetModifierStacks("PC_ALAN_FALLACY") do
                    minigame:ApplyPersuasion( self )
                end
                self.target_enemy = nil
            end,

            [ EVENT.BEGIN_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self.negotiator:RemoveModifier( self, self.stacks, self )
                end
            end,
        },
    },

    PA_BREEZY =
    {
        name = "Breezy",
        desc = "At the end of your turn, give <#HILITE>{1}</> {COMPOSURE} to a random friendly argument.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks * 2 )
        end,
        icon = "negotiation/modifiers/airtight.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 3,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        target_self = TARGET_ANY_RESOLVE,
        event_handlers =
        {
            [ EVENT.END_PLAYER_TURN ] = function( self, minigame )
                local target = minigame:CollectPrimaryTarget(self)
                target:DeltaComposure(self.stacks * 2, self)
                self:ClearTarget()
            end,
        },
    },

    PA_NONSTOP_DEBATE =
    {
        name = "Nonstop Debate",
        desc = "At the Start of the turn, if your amount of arguments before reaches the maximum, create <#HILITE>{1}</> {PC_ALAN_TRUTH}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks )
        end,
        icon = "negotiation/modifiers/formality.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 2,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        event_handlers =
        {
            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                local mod_num = CountArguments(self)
                if mod_num < (12 - self.stacks) then
                    for i=1,self.stacks do
                        self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
                    end
                elseif mod_num < 12 then
                    for i=1,math.min(self.stacks, 12 - mod_num) do
                        self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
                    end
                end
            end,
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
        desc = "Whenever you play a card, gain {1} {PC_ALAN_FALLACY}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks )
        end,
        icon = "negotiation/modifiers/quip.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 1,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        event_handlers =
        {
            [ EVENT.PRE_RESOLVE ] = function( self, minigame, card )
                if card:GetNegotiator() == self.negotiator then
                    self.negotiator:AddModifier("PC_ALAN_FALLACY", self.stacks, self)
                end
            end,

            [ EVENT.END_PLAYER_TURN ] = function( self, minigame )
                self.negotiator:RemoveModifier( "PA_TURN_THE_TABLES", self.stacks )
            end,
        }
    },

    PA_INTERROGATE =
    {
        name = "Interrogate",
        desc = "When this argument destroys another argument, restore 3 core argument resolve.",
        icon = "negotiation/modifiers/interrogate.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 2,
        sound = "event:/sfx/battle/cards/neg/create_argument/interrogate",
        event_handlers =
        {
            [ EVENT.MODIFIER_REMOVED ] = function ( self, modifier, source )
                if source == self then
                    local core = self.negotiator:FindCoreArgument()
                    if core then
                        core:RestoreResolve( 3, self )
                    end
                end
            end
        }
    },

    PA_DEEP_BREATH =
    {
        hidden = true,
        event_priorities = 
        {
            [ EVENT.CALC_PERSUASION ] = EVENT_PRIORITY_MULTIPLIER,
        },
        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source.owner == self.owner
                and is_instance( source, Negotiation.Modifier )
                and source.modifier_type ~= MODIFIER_TYPE.INCEPTION
                and source.modifier_type ~= MODIFIER_TYPE.BOUNTY
                and source:IsAttack() then
                    persuasion:AddPersuasion( persuasion.min_persuasion * self.stacks, persuasion.max_persuasion * self.stacks, self )
                end
            end,

            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                self.negotiator:RemoveModifier(self.id, self.stacks, self)
            end
        },
    },

    PA_GOSSIP =
    {
        name = "Gossip",
        desc = "All friendly arguments deal <#HILITE>{1}</> bonus damage.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks )
        end,
        icon = "negotiation/modifiers/ad_hominem.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 4,
        sound = "event:/sfx/battle/cards/neg/create_argument/enforcement",
        event_priorities =
        {
            [ EVENT.CALC_PERSUASION ] = EVENT_PRIORITY_ADDITIVE,
        },

        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source.owner == self.owner
                and is_instance( source, Negotiation.Modifier )
                and source.modifier_type ~= MODIFIER_TYPE.INCEPTION
                and source.modifier_type ~= MODIFIER_TYPE.BOUNTY
                and source:IsAttack() then
                    persuasion:AddPersuasion( self.stacks, self.stacks, self )
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
}

for i, id, def in sorted_pairs( MODIFIERS ) do
    Content.AddNegotiationModifier( id, def )
end

local CARDS =
{
    PC_ALAN_DISCUSS = 
    {
        name = "Discuss",
        desc = "{PA_REASON} {1}: increase the maximum damage of this card by 2.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.reason_amt)
        end,
        icon = "negotiation/decency.tex",
        flavour = "'Let’s try looking at our current problem from a different angle.'",
        cost = 1,
        rarity = CARD_RARITY.BASIC,
        flags = CARD_FLAGS.DIPLOMACY,
        min_persuasion = 1,
        max_persuasion = 3,
        max_xp = 6,
        wild = true,
        reason_amt = 1,
        bonus_damage = 2,
        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                local mod_num = CountArguments(self)
                if source == self and mod_num >= self.reason_amt then
                    persuasion:AddPersuasion( 0, self.bonus_damage, self )
                end
            end,
        },
    },

    PC_ALAN_DISCUSS_plus2a =
    {
        name = "Visionary Discuss ",
        desc = "<#UPGRADE>Draw a card</>.\n{PA_REASON} {1}: increase the maximum damage of this card by 2.",
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_DISCUSS_plus2b =
    {
        name = "Rooted Discuss",
        min_persuasion = 3,
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
        desc = "<#UPGRADE>Gain {1} {COMPOSURE}</>.\n{PA_REASON} {2}: increase the maximum damage of this card by 2.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ), self.reason_amt)
        end,
        composure_amt = 3,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:DeltaComposure( self.composure_amt, self )
        end,
    },

    PC_ALAN_DISCUSS_plus2e =
    {
        name = "Friendly Discuss",
        desc = "<#UPGRADE>{PA_FRIENDLY} {1}: increase the maximum damage of this card by 2</>.\n{PA_REASON} {2}: increase the maximum damage of this card by 2.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.friend_need, self.reason_amt)
        end,
        friend_need = 2,
        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                local mod_num = CountArguments(self)
                if source == self and mod_num >= self.reason_amt then
                    persuasion:AddPersuasion( 0, self.bonus_damage, self )
                end

                local friend = CountPositiveRelationsCPR(self)
                if source == self and friend >= self.friend_need then
                    persuasion:AddPersuasion( 0, self.bonus_damage, self )
                end
            end
        },
    },

    PC_ALAN_DISCUSS_plus2f =
    {
        name = "Truthful Discuss",
        desc = "<#UPGRADE>{PC_ALAN_TRUTH|}Create 1 {PC_ALAN_TRUTH}</>.\n{PA_REASON} {1}: increase the maximum damage of this card by 2.",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
        end,
    },

    PC_ALAN_DISCUSS_plus2g =
    {
        name = "Genuine Discuss",
        desc = "<#UPGRADE>Gain {1} {PC_ALAN_GENUINE}</>.\n{PA_REASON} {2}: increase the maximum damage of this card by 2.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.genuine_amt, self.reason_amt)
        end,
        genuine_amt = 2,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", self.genuine_amt, self)
        end,
    },

    PC_ALAN_BLUFF =
    {
        name = "Bluff",
        desc = "{PA_UNREASON}: deal 1 bonus damage.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.reason_amt)
        end,
        icon = "negotiation/debate.tex",
        flavour = "'Who needs logic? I’ve never used it anyway.'",
        cost = 1,
        min_persuasion = 1,
        max_persuasion = 3,
        max_xp = 6,
        wild = true,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.BASIC,
        bonus_damage = 1,
        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                local mod_num = CountArguments(self)
                if source == self and mod_num == 0 then
                    persuasion:AddPersuasion( self.bonus_damage, self.bonus_damage, self )
                end
            end,
        },
    },

    PC_ALAN_BLUFF_plus2a =
    {
        name = "Tall Bluff",
        max_persuasion = 5,
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
        name = "Rooted Bluff",
        min_persuasion = 3,
    },

    PC_ALAN_BLUFF_plus2d =
    {
        name = "Visionary Bluff",
        desc = "<#UPGRADE>Draw a card</>.\n{PA_UNREASON} {1}: deal 1 bonus damage.",
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_BLUFF_plus2e =
    {
        name = "Rude Bluff",
        desc = "<#UPGRADE>{INCEPT} 1 {PC_ALAN_RUDE}</>.\n{PA_UNREASON} {2}: deal 1 bonus damage.",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rude_amt = 1,
        OnPostResolve = function( self, minigame, targets )
            self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", self.rude_amt, self)
        end,
    },

    PC_ALAN_BLUFF_plus2f =
    {
        name = "Violent Bluff",
        desc = "<#UPGRADE>{PA_VIOLENT} {1}: deal 1 bonus damage</>.\n{PA_UNREASON} {2}: deal 1 bonus damage.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.enemy_need, self.reason_amt)
        end,
        enemy_need = 2,
        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                local mod_num = CountArguments(self)
                if source == self and mod_num == 0 then
                    persuasion:AddPersuasion( self.bonus_damage, self.bonus_damage, self )
                end

                local enemy = CountNegativeRelationsCNR(self)
                if source == self and enemy >= self.enemy_need then
                    persuasion:AddPersuasion( self.bonus_damage, self.bonus_damage, self )
                end
            end
        },
    },

    PC_ALAN_BLUFF_plus2g =
    {
        name = "Warped Bluff",
        desc = "<#UPGRADE>Gain 1 {PC_ALAN_FALLACY}</>.\n{PA_UNREASON} {1}: deal 1 bonus damage.",
        max_persuasion = 2,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PC_ALAN_FALLACY", 1, self)
        end,
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
        cost = 0,
    },

    PC_ALAN_GUIDANCE_plus2d =
    {
        name = "Wide Guidance",
        desc = "Apply <#DOWNGRADE>{1}</> {COMPOSURE} <#UPGRADE>to all friendly arguments</>.",
        target_mod = TARGET_MOD.TEAM,
        auto_target = true,
        composure_amt = 2,
    },

    PC_ALAN_GUIDANCE_plus2e =
    {
        name = "Reasonable Guidance",
        desc = "Apply {1} {COMPOSURE}.\n<#UPGRADE>{PA_REASON} {2}: Apply {1} {COMPOSURE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ), self.reason_amt)
        end,
        reason_amt = 2,
        OnPostResolve = function( self, minigame, targets )
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
                local mod_num = CountArguments(self)
                if mod_num >= self.reason_amt then
                    target:DeltaComposure(self.composure_amt, self)
                end
            end
        end
    },

    PC_ALAN_GUIDANCE_plus2f =
    {
        name = "Rude Guidance",
        desc = "Apply {1} {COMPOSURE}.\n<#UPGRADE>{INCEPT} 1 {PC_ALAN_RUDE}</>",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rude_amt = 1,
        OnPostResolve = function( self, minigame, targets )
            self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", self.rude_amt, self)
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
            end
        end
    },

    PC_ALAN_GUIDANCE_plus2g =
    {
        name = "Genuine Guidance",
        desc = "Apply {1} {COMPOSURE}.\n<#UPGRADE>Gain 2 {PC_ALAN_GENUINE}</>",
        genuine_amt = 2,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", self.genuine_amt, self)
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
            end
        end
    },

    PC_ALAN_NEGOTIATION_SKILLS =
    {
        name = "Negotiation Skills",
        desc = "Insert {PC_ALAN_DIPLOMACY} or {PC_ALAN_HOSTILE} into your hand.",
        icon = "negotiation/negotiation_wild.tex",
        flavour = "'If you want to survive out here, you'd better know how to strike a deal.'",
        max_xp = 8,
        cost = 1,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.BASIC,
        OnPostResolve = function( self, minigame, targets )
            local cards = {
                Negotiation.Card( "PC_ALAN_DIPLOMACY", self.owner ),
                Negotiation.Card( "PC_ALAN_HOSTILE", self.owner ),
            }

            minigame:ImproviseCards( cards, 1, nil, nil, nil, self )
        end,
    },

    PC_ALAN_DIPLOMACY =
    {
        name = "Friendly Negotiation",
        desc = "{PC_ALAN_TRUTH|}Gain {1} {PC_ALAN_GENUINE}\nCreate {2} {PC_ALAN_TRUTH}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.genuine_amt, self.truth_amt)
        end,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        genuine_amt = 2,
        truth_amt = 1,
        icon = "negotiation/solid_point.tex",
        flavour = "'A few simple tricks—keep your tone friendly, remember the common truths, and above all, be patient.'",
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PC_ALAN_TRUTH", self.truth_amt, self)
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", self.genuine_amt, self) 
        end,
    },

    PC_ALAN_HOSTILE =
    {
        name = "Unfriendly Negotiation",
        desc = "{INCEPT} {1} {PC_ALAN_RUDE}\nGain {2} {PC_ALAN_FALLACY}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.rude_amt, self.fallacy_amt)
        end,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        rude_amt = 1,
        fallacy_amt = 1,
        icon = "negotiation/overwhelm.tex",
        flavour = "'Or, spout something they’ve never heard and probably isn’t right anyway. The goal? Make 'em give up thinking altogether.'",
        OnPostResolve = function( self, minigame, targets )
            self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", self.rude_amt, self)
            self.negotiator:AddModifier("PC_ALAN_FALLACY", self.fallacy_amt, self)
        end,
    },

    PC_ALAN_NEGOTIATION_SKILLS_plus =
    {
        name = "Diplomacy Skills",
        desc = "Insert {PC_ALAN_DIPLOMACY_a}, {PC_ALAN_DIPLOMACY_b} or {PC_ALAN_DIPLOMACY_c} into your hand.",
        icon = "negotiation/negotiation_wild.tex",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        OnPostResolve = function( self, minigame, targets )
            local cards = {
                Negotiation.Card( "PC_ALAN_DIPLOMACY_a", self.owner ),
                Negotiation.Card( "PC_ALAN_DIPLOMACY_b", self.owner ),
                Negotiation.Card( "PC_ALAN_DIPLOMACY_c", self.owner ),
            }

            minigame:ImproviseCards( cards, 1, nil, nil, nil, self )
        end,
    },

    PC_ALAN_DIPLOMACY_a =
    {
        name = "Genuine",
        icon = "negotiation/pleasantries.tex",
        desc = "Gain {1} {PC_ALAN_GENUINE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.genuine_amt)
        end,
        flavour = "'Tone alone won’t cut it—add a bit of body language if you want folks to let their guard down.'",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        genuine_amt = 5,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", self.genuine_amt, self) 
        end,
    },

    PC_ALAN_DIPLOMACY_b =
    {
        name = "Truth",
        icon = "negotiation/compromise.tex",
        desc = "If has no {PC_ALAN_TRUTH}, {PC_ALAN_TRUTH|}Create {1} {PC_ALAN_TRUTH}. Otherwise, gain {2} {INFLUENCE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.truth_amt, self.influence)
        end,
        flavour = "'The best kind of persuasion? The kind where everyone walks away feeling like they won.'",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        truth_amt = 2,
        influence = 1,
        OnPostResolve = function( self, minigame, targets )
            if not self.negotiator:HasModifier("PC_ALAN_TRUTH") then
                for i=1,self.truth_amt do
                self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
            end
            else
                self.negotiator:AddModifier("INFLUENCE", self.influence, self)
            end
        end
    },

    PC_ALAN_DIPLOMACY_c =
    {
        name = "Friendly",
        icon = "negotiation/name_drop.tex",
        desc = "{PA_FRIENDLY} {1}: This card deals double damage.\n{PA_FRIENDLY} {2}: Hits all opponent arguments.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.friend_need, self.friend_need_alt)
        end,
        flavour = "'When needed, drop a few familiar names. Helps people believe you're someone worth listening to.'",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        min_persuasion = 2,
        max_persuasion = 3,
        friend_need = 3,
        friend_need_alt = 6,
        event_priorities =
        {
            [ EVENT.CALC_PERSUASION ] = EVENT_PRIORITY_ADDITIVE,
        },

        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
            local friend = CountPositiveRelationsCPR(self)
            if source == self and friend >= self.friend_need then
                persuasion:AddPersuasion( persuasion.min_persuasion, persuasion.max_persuasion, self )
            end

            if friend >= self.friend_need_alt then
                self.auto_target = true
            else
                self.auto_target = false
            end
            end,


            [ EVENT.START_RESOLVE ] = function( self, minigame, card )
            local friend = CountPositiveRelationsCPR(self)
                if card == self and friend >= self.friend_need_alt then
                    card.target_mod = TARGET_MOD.TEAM
                end
            end
        },
    },

    PC_ALAN_NEGOTIATION_SKILLS_plus2 =
    {
        name = "Hostility Skills",
        desc = "Insert {PC_ALAN_HOSTILE_a}, {PC_ALAN_HOSTILE_b} or {PC_ALAN_HOSTILE_c} into your hand.",
        icon = "negotiation/negotiation_wild.tex",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        OnPostResolve = function( self, minigame, targets )
            local cards = {
                Negotiation.Card( "PC_ALAN_HOSTILE_a", self.owner ),
                Negotiation.Card( "PC_ALAN_HOSTILE_b", self.owner ),
                Negotiation.Card( "PC_ALAN_HOSTILE_c", self.owner ),
            }

            minigame:ImproviseCards( cards, 1, nil, nil, nil, self )
        end,
    },

    PC_ALAN_HOSTILE_a =
    {
        name = "Rude",
        icon = "negotiation/invective.tex",
        desc = "{INCEPT} {1} {PC_ALAN_RUDE} and Gain {2} {COMPOSURE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.rude_amt, self:CalculateComposureText( self.composure_amt ))
        end,
        flavour = "'Negotiation gets a lot easier once you're okay with being the bad guy.'",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        rude_amt = 1,
        composure_amt = 3,
        OnPostResolve = function( self, minigame, targets )
            self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", self.rude_amt, self) 
            self.negotiator:DeltaComposure( self.composure_amt, self )
        end,
    },

    PC_ALAN_HOSTILE_b =
    {
        name = "Fallacy",
        icon = "negotiation/barrage.tex",
        desc = "{PC_ALAN_FALLACY|}Gain {1} {PC_ALAN_FALLACY}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.fallacy_amt)
        end,
        flavour = "'Can’t remember the right arguments? Sometimes overwhelming them with nonsense works just as well.'",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        fallacy_amt = 2,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PC_ALAN_FALLACY", self.fallacy_amt, self)
        end
    },

    PC_ALAN_HOSTILE_c =
    {
        name = "Violent",
        icon = "negotiation/bluster.tex",
        desc = "{BLIND}.\n{PA_VIOLENT} {1}: Attack with this card 2 times.\n{PA_VIOLENT} {2}: Attack with this card 3 times.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.enemy_need, self.enemy_need_alt)
        end,
        flavour = "'Say the roughest thing you can think of—whatever makes them believe you’re not to be messed with.'",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        min_persuasion = 3,
        max_persuasion = 3,
        enemy_need = 2,
        enemy_need_alt = 5,
        auto_target = true,
        extra_targets = 0,
        event_handlers =
        {
            [ EVENT.START_RESOLVE ] = function( self, minigame, card )
            if card == self then
                local enemy = CountNegativeRelationsCNR(self)
                if enemy >= self.enemy_need_alt then
                    self.extra_targets = 2
                elseif enemy >= self.enemy_need then
                    self.extra_targets = 1
                end
            end
            end
        },
        OnPostResolve = function( self, minigame, targets )
            for i=1, self.extra_targets do
                minigame:ApplyPersuasion(self)
            end
        end
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
        pool_cards = {"improvise_gruff", "improvise_carry_over", "improvise_options", "improvise_withdrawn", "PC_ALAN_GENUINE_CARD", "PC_ALAN_FALLACY_CARD", "improvise_wide_composure", "improvise_bait", "improvise_vulnerability"},
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
        pool_cards = {"improvise_gruff_upgraded", "improvise_carry_over_upgraded", "improvise_options_upgraded", "improvise_withdrawn_upgraded", "PC_ALAN_GENUINE_CARD_upgraded", "PC_ALAN_FALLACY_CARD_upgraded", "improvise_wide_composure_upgraded", "improvise_bait_upgraded", "improvise_vulnerability_upgraded"},
    },

    PC_ALAN_BRAINSTORM_plus2 = 
    {
        name = "Boosted Brainstorm",
        desc = "<#UPGRADE>{IMPROVISE_PLUS}</> a card from a pool of special cards.",
        pool_size = 5,
    },

    PC_ALAN_GENUINE_CARD =
    {
        name = "Explain",
        icon = "negotiation/elucidate.tex",
        desc = "Gain {1} {PC_ALAN_GENUINE}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.genuine_amt)
        end,
        flavour = "'Trust me—I swear I’m not trying to screw you over.'",
        genuine_amt = 2,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", self.genuine_amt, self) 
        end,
    },

    PC_ALAN_GENUINE_CARD_upgraded =
    {
        name = "Boosted Explain",
        genuine_amt = 4,
    },

    PC_ALAN_FALLACY_CARD =
    {
        name = "Doubt",
        icon = "negotiation/threaten.tex",
        desc = "Gain 1 {PC_ALAN_FALLACY}.",
        flavour = "'You sure about that?'",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 1,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PC_ALAN_FALLACY", 1, self)
        end
    },

    PC_ALAN_FALLACY_CARD_upgraded =
    {
        name = "Pale Doubt",
        cost = 0,
    },

    PC_ALAN_CONFIDENCE =
    {
        name = "Confidence",
        icon = "negotiation/upright.tex",
        desc = "{PA_REASON} {1}: Attack with this card twice.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.reason_amt)
        end,
        flavour = "'Let’s get started.'",
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 1,
        max_persuasion = 4,
        max_xp = 9,
        cost = 1,
        reason_amt = 2,
        event_handlers = 
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
            local mod_num = CountArguments(self)
                if source == self and mod_num >= self.reason_amt then
                    persuasion:ModifyPersuasion( persuasion.max_persuasion, persuasion.max_persuasion, self )
                end
            end,
        },
    },

    PC_ALAN_CONFIDENCE_plus =
    {
        name = "Rooted Confidence",
        max_persuasion = 6,
    },

    PC_ALAN_CONFIDENCE_plus2 =
    {
        name = "Pale Confidence",
        desc = "{PA_REASON} <#UPGRADE>{1}</>: Attack with this card twice.",
        reason_amt = 1,
    },

    PC_ALAN_PERSENTATION =
    {
        name = "Presentation",
        icon = "negotiation/agency.tex",
        desc = "{PA_REASON} X: Reduce the cost of this card by X.",
        flavour = "'Take a look at this, sir.'",
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 5,
        max_xp = 3,
        cost = 3,
        cost_reduction = 0,
        OnPostResolve = function( self, minigame, targets )
            self.cost_reduction = 0
        end,

        event_priorities =
        {
            [EVENT.CALC_ACTION_COST ] = 999,
        },

        event_handlers =
        {
            [ EVENT.MODIFIER_ADDED ] = function( self, modifier, source )
            self.cost_reduction = self.cost_reduction + 1
            end,

            [ EVENT.CALC_ACTION_COST ] = function( self, acc, card, target )
                if card == self then
                    acc:AddValue( -self.cost_reduction, self )
                end
            end,
        },
    },

    PC_ALAN_PERSENTATION_plus =
    {
        name = "Rooted Presentation",
        max_persuasion = 8,
    },

    PC_ALAN_PERSENTATION_plus2 =
    {
        name = "Pale Presentation",
        min_persuasion = 5,
    },

    PC_ALAN_REBUTTAL =
    {
        name = "Rebuttal",
        icon = "negotiation/swift_rebuttal.tex",
        desc = "Targets a random opponent argument.\n{EVOKE}: Create a friendly argument.",
        flavour = "'Hold it!'",
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        target_mod = TARGET_MOD.RANDOM1,
        min_persuasion = 2,
        max_persuasion = 3,
        max_xp = 10,
        cost = 1,
        auto_target = true,
        evoke_max = 1,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        event_handlers =
        {
            [ EVENT.MODIFIER_ADDED ] = function( self, modifier, source )
            if modifier.negotiator == self.negotiator then
                self:Evoke( self.evoke_max )
            end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self:ResetEvoke()
                end
            end,
        },
    },

    PC_ALAN_REBUTTAL_plus =
    {
        name = "Boosted Rebuttal",
        min_persuasion = 4,
        max_persuasion = 5,
    },

    PC_ALAN_REBUTTAL_plus2 =
    {
        name = "Genuine Rebuttal",
        desc = "Targets a random opponent argument.\n<#UPGRADE>Gain 1 {PC_ALAN_GENUINE}</>.\n{EVOKE}: Create a friendly argument.",
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", 1, self)
        end,
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
        name = "Stone Agreement",
        desc = "Gain {1} {INFLUENCE}.\n<#UPGRADE>Gain {2} {COMPOSURE}</>.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.influence, self:CalculateComposureText( self.composure_amt ))
        end,
        composure_amt = 3,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("INFLUENCE", self.influence, self)
            self.negotiator:DeltaComposure( self.composure_amt, self )
        end
    },

    PC_ALAN_FACT =
    {
        name = "Fact",
        icon = "negotiation/hard_facts.tex",
        desc = "{PC_ALAN_TRUTH|}Create {1} {PC_ALAN_TRUTH}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.truth_amt)
        end,
        flavour = "'That’s just how it is.'",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.COMMON,
        truth_amt = 1,
        max_xp = 9,
        cost = 1,
        OnPostResolve = function( self, minigame, targets )
            for i=1,self.truth_amt do
                self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
            end
        end
    },

    PC_ALAN_FACT_plus =
    {
        name = "Pale Fact",
        cost = 0,
    },

    PC_ALAN_FACT_plus2 =
    {
        name = "Mirrored Fact",
        desc = "{PC_ALAN_TRUTH|}Create <#UPGRADE>{1}</> {PC_ALAN_TRUTH}.",
        truth_amt = 2,
    },

    PC_ALAN_PLEA =
    {
        name = "Plea",
        icon = "negotiation/plead.tex",
        desc = "Gain {1} {PC_ALAN_GENUINE}.\nDraw a card.",
        flavour = "'C’mon, man… I’m beggin’ ya here.'",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.genuine_amt, self.composure_amt)
        end,
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        genuine_amt = 2,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", self.genuine_amt, self)
            minigame:DrawCards(1)
        end
    },

    PC_ALAN_PLEA_plus =
    {
        name = "Boosted Plea",
        desc = "Gain <#UPGRADE>{1}</> {PC_ALAN_GENUINE}.\nDraw a card.",
        genuine_amt = 3,
    },

    PC_ALAN_PLEA_plus2 =
    {
        name = "Stone Plea",
        desc = "Gain {1} {PC_ALAN_GENUINE}.\n<#UPGRADE>Apply {2} {COMPOSURE}</>.",
        composure_amt = 3,
        target_self = TARGET_ANY_RESOLVE,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", self.renown_amt, self)
            for i,target in ipairs(targets) do
                target:DeltaComposure( self.composure_amt, self )
            end
        end
    },

    PC_ALAN_GOOD_IMPRESSION =
    {
        name = "Good Impression",
        icon = "negotiation/subtlety.tex",
        desc = "{PA_FRIENDLY} {1}: Deal an additional {2} damage.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.friend_need, self.bonus_damage )
        end,
        flavour = "*wink*",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 3,
        friend_need = 4,
        bonus_damage = 3,
        action_bonus = 0,
        OnPostResolve = function( self, minigame, targets )
            local friend = CountPositiveRelationsCPR(self)
            if friend >= self.friend_need then
                minigame:ApplyPersuasion( self, nil, self.bonus_damage, self.bonus_damage )
                minigame:ModifyActionCount(self.action_bonus)
            end
        end
    },

    PC_ALAN_GOOD_IMPRESSION_plus =
    {
        name = "Boosted Good Impression",
        desc = "{PA_FRIENDLY} {1}: Deal an additional <#UPGRADE>{2}</> damage.",
        bonus_damage = 5,
    },

    PC_ALAN_GOOD_IMPRESSION_plus2 =
    {
        name = "Pale Good Impression",
        desc = "{PA_FRIENDLY} {1}: Deal an additional <#DOWNGRADE>{2}</> damage and <#UPGRADE>gain 1 action</>.",
        action_bonus = 1,
        bonus_damage = 1,
    },

    PC_ALAN_UNREASONABLE_RAGE =
    {
        name = "Unreasonable Rage",
        icon = "negotiation/caprice.tex",
        desc = "{PA_UNREASON}: Gain 1 {PC_ALAN_FALLACY}.",
        flavour = "I’m telling you, this isn’t over today!",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        fallacy_amt = 1,
        min_persuasion = 2,
        max_persuasion = 2,
        rude_amt = 0,
        draw = 0,
        OnPostResolve = function( self, minigame, targets )
            local mod_num = CountArguments(self)
            if mod_num == 0 then
                self.negotiator:AddModifier("PC_ALAN_FALLACY", self.fallacy_amt, self)
                self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", self.rude_amt, self)
            end
        end,
    },

    PC_ALAN_UNREASONABLE_RAGE_plus =
    {
        name = "Boosted Unreasonable Rage",
        min_persuasion = 4,
        max_persuasion = 4,
    },

    PC_ALAN_UNREASONABLE_RAGE_plus2 =
    {
        name = "Rude Unreasonable Rage",
        desc = "{PA_UNREASON}: <#UPGRADE>{INCEPT} 1 {PC_ALAN_RUDE}</>.",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        fallacy_amt = 0,
        rude_amt = 1,
    },

    PC_ALAN_BREAK_PACT =
    {
        name = "Break Pact",
        icon = "negotiation/rescind.tex",
        desc = "If you have any {PC_ALAN_FALLACY}, gain {1} {PC_ALAN_FALLACY}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.fallacy_amt )
        end,
        flavour = "No one said I had to follow this damned treaty.",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.BASIC,
        fallacy_amt = 1,
        OnPostResolve = function( self, minigame, targets )
            if self.negotiator:HasModifier("PC_ALAN_FALLACY") then
                self.negotiator:AddModifier("PC_ALAN_FALLACY", self.fallacy_amt, self)
            end
        end,
    },

    PC_ALAN_BREAK_PACT_plus =
    {
        name = "Pale Break Pact",
        cost = 0,
    },

    PC_ALAN_BREAK_PACT_plus2 =
    {
        name = "Boosted Break Pact",
        desc = "If you have any {PC_ALAN_FALLACY}, gain <#UPGRADE>{1}</> {PC_ALAN_FALLACY}.",
        fallacy_amt = 2,
    },

    PC_ALAN_URGE =
    {
        name = "Urge",
        icon = "negotiation/improvise_mean.tex",
        desc = "{PA_VIOLENT} {1}: {INCEPT} 2 {VULNERABILITY}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.enemy_need )
        end,
        flavour = "Move it!",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        enemy_need = 2,
        min_persuasion = 1,
        max_persuasion = 3,
        OnPostResolve = function( self, minigame, targets )
            local enemy = CountNegativeRelationsCNR(self)
            if enemy >= self.enemy_need then
                self.anti_negotiator:InceptModifier("VULNERABILITY", 2, self )
            end
        end,
    },

    PC_ALAN_URGE_plus =
    {
        name = "Boosted Urge",
        min_persuasion = 3,
        max_persuasion = 5,
    },

    PC_ALAN_URGE_plus2 =
    {
        name = "Twisted Urge",
        desc = "<#UPGRADE>{PA_FRIENDLY} {1}</>: {INCEPT} 2 {VULNERABILITY}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.friend_need )
        end,
        min_persuasion = 3,
        max_persuasion = 5,
        friend_need = 3,
        OnPostResolve = function( self, minigame, targets )
            local friend = CountPositiveRelationsCPR(self)
            if friend >= self.friend_need then
                self.anti_negotiator:InceptModifier("VULNERABILITY", 2, self )
            end
        end,
    },

    PC_ALAN_ABANDON = 
    {
        name = "Abandon",
        icon = "negotiation/refusal.tex",
        desc = "Randomly destroy a friendly argument.",
        flavour = "I never said I needed your help.",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 3,
        max_persuasion = 5,
        draw = 0,
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(self.draw)
            local options = {}
            for i, arg in self.negotiator:Modifiers() do
                if arg.modifier_type ~= MODIFIER_TYPE.CORE and arg:GetResolve() then
                    table.insert(options, arg)
                end
            end
            if #options > 0 then
                local chosen = options[math.random(#options)]
                self.negotiator:DestroyModifier(chosen, self)
            end
        end
    },

    PC_ALAN_ABANDON_plus =
    {
        name = "Visionary Abandon",
        desc = "Randomly destroy a friendly argument and <#UPGRADE>draw a card</>.",
        draw = 1,
    },

    PC_ALAN_ABANDON_plus2 =
    {
        name = "Rooted Abandon",
        min_persuasion = 5,
    },

    PC_ALAN_INSULT =
    {
        name = "Insult",
        icon = "negotiation/reckless_insults.tex",
        desc = "{INCEPT} 1 {PC_ALAN_RUDE}.",
        flavour = "Your face is so ugly, even Hesh needs a prophet to prep before taking a second look!",
        cost = 2,
        max_xp = 7,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        OnPostResolve = function( self, minigame, targets )
            self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", 1, self)
        end
    },

    PC_ALAN_INSULT_plus =
    {
        name = "Violent Insult",
        desc = "{INCEPT} 1 {PC_ALAN_RUDE}.\n<#UPGRADE>{PA_VIOLENT} {1}: Gain 1 action</>.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.enemy_need )
        end,
        action_bonus = 1,
        enemy_need = 4,
        OnPostResolve = function( self, minigame, targets )
            self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", 1, self)
            local enemy = CountNegativeRelationsCNR(self)
            if enemy >= self.enemy_need then
                minigame:ModifyActionCount(self.action_bonus)
            end
        end
    },

    PC_ALAN_INSULT_plus2 =
    {
        name = "Warped Insult",
        desc = "{INCEPT} 1 {PC_ALAN_RUDE}.\n<#UPGRADE>Gain 1 {PC_ALAN_FALLACY}</>.",
        OnPostResolve = function( self, minigame, targets )
            self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", 1, self)
            self.negotiator:AddModifier("PC_ALAN_FALLACY", self.fallacy_amt, self)
        end
    },

    PC_ALAN_MISFIRE =
    {
        name = "Misfire",
        icon = "negotiation/burn.tex",
        desc = "{PA_UNREASON}: Hits all opponent arguments.",
        flavour = "Sorry, this gun acts up sometimes.",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 2,
        event_handlers = 
        {
            [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
            local mod_num = CountArguments(self)
                if card == self and target_deck == self.engine:GetHandDeck() then
                    if mod_num == 0 then
                        self.target_mod = TARGET_MOD.TEAM
                        self.auto_target = true
                    else
                        self.target_mod = TARGET_MOD.SINGLE
                        self.auto_target = nil
                    end
                end
            end,

            [ EVENT.MODIFIER_ADDED ] = function( self, card )
            local mod_num = CountArguments(self)
                if mod_num == 0 then
                    self.target_mod = TARGET_MOD.TEAM
                    self.auto_target = true
                else
                    self.target_mod = TARGET_MOD.SINGLE
                    self.auto_target = nil
                end
            end,

            [ EVENT.MODIFIER_REMOVED ] = function( self, card )
            local mod_num = CountArguments(self)
                if mod_num == 0 then
                    self.target_mod = TARGET_MOD.TEAM
                    self.auto_target = true
                else
                    self.target_mod = TARGET_MOD.SINGLE
                    self.auto_target = nil
                end
            end,
        },
    },

    PC_ALAN_MISFIRE_plus =
    {
        name = "Tall Misfire",
        max_persuasion = 4,
    },

    PC_ALAN_MISFIRE_plus2 =
    {
        name = "Focused Misfire",
        desc = "{PA_UNREASON}: <#UPGRADE>Attack twice</>.",
        event_handlers = 
        {
            [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )

            end,
        },
        OnPostResolve = function( self, minigame )
            local mod_num = CountArguments(self)
            if mod_num == 0 then
                for i = 1, 1 do
                    minigame:ApplyPersuasion( self )
                end
            end
        end,
    },

    PC_ALAN_PROHIBIT =
    {
        name = "Prohibit",
        icon = "negotiation/domain.tex",
        desc = "{EVOKE}: Draw 3 Hostility cards in a single turn.",
        flavour = "Yotes—and you—are not allowed in!",
        cost = 0,
        max_xp = 10,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.UNPLAYABLE,
        rarity = CARD_RARITY.COMMON,
        min_persuasion = 2,
        max_persuasion = 2,
        evoke_max = 3,
        deck_handlers = { DECK_TYPE.DRAW, DECK_TYPE.DISCARDS },
        event_handlers = 
        {
            [ EVENT.DRAW_CARD ] = function( self, minigame, card )
                if card:IsFlagged( CARD_FLAGS.HOSTILE ) then
                    self:Evoke( self.evoke_max )
                end
            end,

            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    self:ResetEvoke()
                end
            end,
        },
    },

    PC_ALAN_PROHIBIT_plus =
    {
        name = "Boosted Prohibit",
        min_persuasion = 4,
        max_persuasion = 4,
    },

    PC_ALAN_PROHIBIT_plus2 =
    {
        name = "Warped Prohibit",
        desc = "<#UPGRADE>Gain 1 {PC_ALAN_FALLACY}</>.\n{EVOKE}: Draw 3 Hostility cards in a single turn.",
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.UNPLAYABLE,
        min_persuasion = 0,
        max_persuasion = 0,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PC_ALAN_FALLACY", 1, self)
        end,
    },

    PC_ALAN_SOCIAL_CIRCLE =
    {
        name = "Social Circle",
        icon = "negotiation/networked.tex",
        desc = "Apply 1 {COMPOSURE} for every 2 person that loves or likes you.\n(Apply {1} {COMPOSURE}).",
        desc_fn = function( self, fmt_str )
            local friend = CountPositiveRelationsCPR(self)
            local composure = math.floor(friend / 2) + self.composure_bonus
            return loc.format( fmt_str, composure )
        end,
        flavour = "I’ve got some connections, you know.",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.COMMON,
        composure_amt = 1,
        composure_bonus = 0,
        target_self = TARGET_ANY_RESOLVE,
        OnPostResolve = function( self, minigame, targets )
            local friend = CountPositiveRelationsCPR(self)
            local composure = math.floor(friend / 2) + self.composure_bonus
            for i,target in ipairs(targets) do
                target:DeltaComposure(composure, self)
            end
        end
    },

    PC_ALAN_SOCIAL_CIRCLE_plus =
    {
        name = "Boosted Social Circle",
        desc = "Apply 1 {COMPOSURE}<#UPGRADE>+3</> for every 2 person that loves or likes you.\n(Apply {1} {COMPOSURE}).",
        composure_bonus = 3,
    },

    PC_ALAN_SOCIAL_CIRCLE_plus2 =
    {
        name = "Twisted Social Circle",
        desc = "Apply 1 {COMPOSURE}<#UPGRADE>+3</> for every 2 person that <#UPGRADE>hates</> or <#UPGRADE>dislikes</> you.\n(Apply {1} {COMPOSURE}).",
        desc_fn = function( self, fmt_str )
            local enemy = CountNegativeRelationsCNR(self)
            local composure = math.floor(enemy / 2) + self.composure_bonus
            return loc.format( fmt_str, composure )
        end,
        composure_bonus = 3,
        OnPostResolve = function( self, minigame, targets )
            local enemy = CountNegativeRelationsCNR(self)
            local composure = math.floor(enemy / 2) + self.composure_bonus
            for i,target in ipairs(targets) do
                target:DeltaComposure(composure, self)
            end
        end
    },

    PC_ALAN_BREEZY =
    {
        name = "Breezy",
        icon = "negotiation/standing.tex",
        desc = "{PA_BREEZY|}Create: At the end of the turn, apply 2 {COMPOSURE} to a random friendly argument.",
        flavour = "The wind’s a bit rowdy today.",
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
        desc = "{PA_BREEZY|}Create <#UPGRADE>2</>: At the end of the turn, apply 2 {COMPOSURE} to a random friendly argument.",
        count = 2,
    },

    PC_ALAN_TARGETED =
    {
        name = "Targeted",
        icon = "negotiation/turnabout.tex",
        desc = "Destroy target argument.",
        flavour = "Yeah, that’s right—you, the one with the drink.",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.COMMON,
        target_self = TARGET_ANY_RESOLVE,
        target_enemy = TARGET_ANY_RESOLVE,
        draw = 0,
        CanTarget = function( self, target )
            if target and target.modifier_type == MODIFIER_TYPE.CORE then
                return false, CARD_PLAY_REASONS.INVALID_TARGET
            end
            return true
        end,
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(self.draw)
            for i,target in ipairs(targets) do
                if target.modifier_type ~= MODIFIER_TYPE.CORE then
                    target.negotiator:DestroyModifier(target, self)
                end
            end
        end,
    },

    PC_ALAN_TARGETED_plus =
    {
        name = "Pale Targeted",
        cost = 0,
    },

    PC_ALAN_TARGETED_plus2 =
    {
        name = "Visionary Targeted",
        desc = "Destroy target argument and <#UPGRADE>draw a card</>.",
        draw = 1,
    },

    PC_ALAN_SHOWTIME = 
    {
        name = "Showtime",
        icon = "negotiation/pure_style.tex",
        desc = "Draw {1} card.\n{IMPROVISE} a card from your draw pile.",
        flavour = "Watch closely—this is how it’s done.",
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
        desc = "Draw <#UPGRADE>{1}</> card.\n{IMPROVISE} a card from your draw pile.",
        draw = 2,
    },

    PC_ALAN_SHOWTIME_plus2 =
    {
        name = "Wide Showtime",
        desc = "Draw {1} card.\n<#UPGRADE>{IMPROVISE_PLUS}</> a card from your draw pile.",
        pool_size = 5,
    },

    PC_ALAN_ARGUMENT = 
    {
        name = "Argument",
        desc = "{PA_REASON} X: Attack again for X times.\n(Up to <#UPGRADE>{1}</> times).",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.reason_amt)
        end,
        icon = "negotiation/fast_talk.tex",
        flavour = "'Hear me out.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        min_persuasion = 2,
        max_persuasion = 3,
        max_xp = 9,
        reason_amt = 3,
        OnPreResolve = function( self, minigame, targets )
            local mod_num = CountArguments(self)
            local count = math.min( mod_num, self.reason_amt)
            for i = 1, count do
                minigame:ApplyPersuasion( self )
                self:AssignTarget( nil )
            end
        end,
    },

    PC_ALAN_ARGUMENT_plus =
    {
        name = "Boosted Argument",
        desc = "{PA_REASON} X: Attack again for X times.\n(Up to <#UPGRADE>{1}</> times).",
        reason_amt = 5,
    },

    PC_ALAN_ARGUMENT_plus2 =
    {
        name = "Tall Argument",
        max_persuasion = 5,
    },

    PC_ALAN_SNAP_FINGERS =
    {
        name = "Snap Fingers",
        icon = "negotiation/blank.tex",
        desc = "While this is in your hand, apply {1} {COMPOSURE} to all friendly arguments and lose 1 action whenever you play a card.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:CalculateComposureText( self.composure_amt ))
        end,
        flavour = "'Hey, could you stay focused? Thanks.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.UNPLAYABLE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        composure_amt = 2,
        target_mod = TARGET_MOD.TEAM,
        target_self = TARGET_ANY_RESOLVE,
        event_handlers =
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                if card.negotiator == self.negotiator then
                    self:AddXP(1)
                    minigame:ModifyActionCount(-1)
                    local targets = self.engine:CollectAlliedTargets(self.negotiator)
                    if #targets > 0 then
                        for i,target in ipairs(targets) do
                            target:DeltaComposure(self.composure_amt, self)
                        end                            
                    end
                end
            end
        },
    },

    PC_ALAN_SNAP_FINGERS_plus =
    {
        name = "Visionary Snap Fingers",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.REPLENISH,
    },

    PC_ALAN_SNAP_FINGERS_plus2 =
    {
        name = "Twisted Snap Fingers",
        desc = "<#UPGRADE>Apply {1} {COMPOSURE} to all friendly arguments</>.",
        flags = CARD_FLAGS.DIPLOMACY,
        composure_amt = 3,
        event_handlers =
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                
            end
        },
        auto_target = true,
        cost = 1,
        OnPostResolve = function( self, minigame, targets )
            for i,target in ipairs(targets) do
                target:DeltaComposure(self.composure_amt, self)
            end
        end
    },

    PC_ALAN_APPLAUSE =
    {
        name = "Applause",
        icon = "negotiation/praise.tex",
        desc = "Gain {PC_ALAN_GENUINE} equal to damage dealt by this card.",
        flavour = "'Brilliant plan!'",
        cost = 2,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        min_persuasion = 1,
        max_persuasion = 4,
        event_handlers =
        {
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                if source == self and damage > 0 then
                    self.negotiator:InceptModifier("PC_ALAN_GENUINE", damage, self)
                end
            end
        },
    },

    PC_ALAN_APPLAUSE_plus =
    {
        name = "Boosted Applause",
        min_persuasion = 2,
        max_persuasion = 5,
    },

    PC_ALAN_APPLAUSE_plus2 =
    {
        name = "Pale Applause",
        cost = 1,
        min_persuasion = 0,
        max_persuasion = 3,
    },

    PC_ALAN_LIKE_WIND_AND_RAIN =
    {
        name = "Like Wind and Rain",
        icon = "negotiation/calm.tex",
        desc = "Add {1} resolve to a random friendly arguments.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.resolve_gain)
        end,
        flavour = "'Close your eyes—just enjoy the moment.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        target_self = TARGET_FLAG.ARGUMENT | TARGET_FLAG.BOUNTY,
        target_mod = TARGET_MOD.RANDOM1,
        auto_target = true,
        resolve_gain = 2,
        OnPostResolve = function( self, minigame, targets )
            for i,arg in ipairs(targets) do
                arg:ModifyResolve( self.resolve_gain, self )
            end
        end
    },

    PC_ALAN_LIKE_WIND_AND_RAIN_plus =
    {
        name = "Pale Like Wind and Rain",
        cost = 0,
    },

    PC_ALAN_LIKE_WIND_AND_RAIN_plus2 =
    {
        name = "Wide Like Wind and Rain",
        desc = "Add {1} resolve to <#UPGRADE>all friendly arguments</>.",
        cost = 2,
        target_mod = TARGET_MOD.TEAM,
    },

    PC_ALAN_PROMOTION =
    {
        name = "Promotion",
        icon = "negotiation/appeal_to_reason.tex",
        desc = "Costs 1 less for every 2 person that loves or likes you have.",
        flavour = "'This book is seriously good.'",
        cost = 5,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 3,
        min_persuasion = 7,
        max_persuasion = 9,
        event_handlers =
        {
            [ EVENT.CALC_ACTION_COST ] = function( self, cost_acc, card, target )
                if card == self then
                    local friend = CountPositiveRelationsCPR(self)
                    cost_acc:ModifyValue( card.def.cost - math.floor( friend / 2 ), self )
                end
            end,
        },
    },

    PC_ALAN_PROMOTION_plus =
    {
        name = "Tall Promotion",
        max_persuasion = 12,
    },

    PC_ALAN_PROMOTION_plus2 =
    {
        name = "Rooted Promotion",
        min_persuasion = 10,
        max_persuasion = 10,
    },

    PC_ALAN_NONSTOP_DEBATE =
    {
        name = "Nonstop Debate",
        icon = "negotiation/level_playing_field.tex",
        desc = "{PA_NONSTOP_DEBATE|}{PC_ALAN_TRUTH|}Gain: At the Start of the turn, if your amount of arguments before reaches the maximum, create 1 {PC_ALAN_TRUTH}.",
        flavour = "Are you seriously telling me you brought a gun just to say... That's wrong?",
        cost = 2,
        max_xp = 7,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_NONSTOP_DEBATE", 1, self)
        end
    },

    PC_ALAN_NONSTOP_DEBATE_plus =
    {
        name = "Initial Nonstop Debate",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_NONSTOP_DEBATE_plus2 =
    {
        name = "Pale Nonstop Debate",
        cost = 1,
    },

    PC_ALAN_REPUTATION =
    {
        name = "Reputation",
        icon = "negotiation/fame.tex",
        desc = "{PA_VIOLENT} {1}: This card will be unplayable.\nDraw a card.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.enemy_need )
        end,
        flavour = "'People say I’m a decent person—go ahead, ask around.'",
        cost = 0,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        min_persuasion = 1,
        max_persuasion = 4,
        enemy_need = 2,
        loc_strings =
        {
            ENEMY = "You already have more than one enemy.",
        },
        CanPlayCard = function( self, source, engine, target )
            local enemy = CountNegativeRelationsCNR(self)
            if enemy >= self.enemy_need then
                return false, self.def:GetLocalizedString( "ENEMY" )
            else
                return true
            end
        end,
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(1)
        end,
    },

    PC_ALAN_REPUTATION_plus =
    {
        name = "Tall Reputation",
        max_persuasion = 6,
    },

    PC_ALAN_REPUTATION_plus2 =
    {
        name = "Rooted Reputation",
        min_persuasion = 4,
    },

    PC_ALAN_COIN_BRIDE =
    {
        name = "Coin Bride",
        icon = "negotiation/prominence.tex",
        desc = "Draw {1} cards.\nGain 2 {PC_ALAN_GENUINE} for each Diplomacy card drawn.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.draw )
        end,
        flavour = "I’ve got some rare commemoratives—just... let me off this time, yeah?",
        cost = 1,
        max_xp = 9,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        draw = 2,
        OnPostResolve = function( self, minigame )
            local cards = minigame:DrawCards( self.draw )
            local genuine_amt = 0
            for i, card in ipairs( cards ) do
                if card:IsFlagged( CARD_FLAGS.DIPLOMACY ) then
                    genuine_amt = genuine_amt + 1
                end
            end
            self.negotiator:InceptModifier( "PC_ALAN_GENUINE", (genuine_amt * 2), self )
        end,
    },

    PC_ALAN_COIN_BRIDE_plus =
    {
        name = "Enhanced Coin Bride",
        desc = "Draw <#UPGRADE>{1}</> cards.\nGain 2 {PC_ALAN_GENUINE} for each Diplomacy card drawn.",
        draw = 3,
    },

    PC_ALAN_COIN_BRIDE_plus2 =
    {
        name = "Truthful Coin Bride",
        desc = "Draw {1} cards.\n{PC_ALAN_TRUTH|}<#UPGRADE>Create 1 {PC_ALAN_TRUTH}</> for each Diplomacy card drawn.",
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        OnPostResolve = function( self, minigame )
            local cards = minigame:DrawCards( self.draw )
            local truth_amt = 0
            for i, card in ipairs( cards ) do
                if card:IsFlagged( CARD_FLAGS.DIPLOMACY ) then
                    truth_amt = truth_amt + 1
                end
            end
            if truth_amt > 0 then
                for i=1,self.truth_amt do
                    self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
                end
            end
        end,
    },

    PC_ALAN_UNDERSTAND = 
    {
        name = "Understand",
        icon = "negotiation/incredulous.tex",
        desc = "Gain {1} {PC_ALAN_GENUINE}.\n{PA_FRIENDLY} {2}: Add a copy of this card to your discards.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.genuine_amt, self.friend_need )
        end,
        flavour = "'Ohhh... I see now.'",
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        min_persuasion = 3,
        max_persuasion = 5,
        genuine_amt = 3,
        friend_need = 6,
        OnPostResolve = function( self, minigame )
            self.negotiator:InceptModifier( "PC_ALAN_GENUINE", self.genuine_amt, self )
            local friend = CountPositiveRelationsCPR(self)
            if friend >= self.friend_need then
                local copy = self:Duplicate()
                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DISCARDS ))
            end
        end,
    },

    PC_ALAN_UNDERSTAND_plus =
    {
        name = "Tall Understand",
        max_persuasion = 8,
    },

    PC_ALAN_UNDERSTAND_plus2 =
    {
        name = "Genuine Understand",
        desc = "Gain <#UPGRADE>{1}</> {PC_ALAN_GENUINE}.\n{PA_FRIENDLY} {2}: Add a copy of this card to your discards.",
        genuine_amt = 5,
    },

    PC_ALAN_STAY_CALM =
    {
        name = "Stay Calm",
        icon = "negotiation/collected.tex",
        desc = "Choose an argument, gain {PC_ALAN_GENUINE} double of the argument's stack.",
        flavour = "'Yep, that’s exactly it!'",
        cost = 0,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        target_self = TARGET_FLAG.ARGUMENT | TARGET_FLAG.BOUNTY,
        target_enemy = TARGET_FLAG.ARGUMENT | TARGET_FLAG.BOUNTY,
        composure_bonus = 0,
        genuine_amt= 2,
        genuine_bonus = 0,
        OnPostResolve = function( self, minigame, targets )
            local stacks = targets[1].stacks
            self.negotiator:InceptModifier( "PC_ALAN_GENUINE", stacks * self.genuine_amt + self.genuine_bonus , self )
            self.negotiator:DeltaComposure( stacks * self.composure_bonus, self )
        end,
    },

    PC_ALAN_STAY_CALM_plus =
    {
        name = "Stay Calm Like a Stone",
        desc = "Choose an argument, gain {PC_ALAN_GENUINE} and <#UPGRADE>{COMPOSURE}</> double of the argument's stack.",
        composure_bonus = 2,
    },

    PC_ALAN_STAY_CALM_plus2 =
    {
        name = "Rooted Stay Calm",
        desc = "Choose an argument, gain {PC_ALAN_GENUINE}<#UPGRADE>+2</> double of the argument's stack.",
        genuine_bonus = 2,
    },

    PC_ALAN_SUPPORT =
    {
        name = "Support",
        icon = "negotiation/claim_to_fame.tex",
        desc = "Gain 2 {INFLUENCE}, then Create 1 {PC_ALAN_TRUTH} for every 2 {INFLUENCE} you have.",
        flavour = "'I’ve still got people backing me.'",
        cost = 2,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("INFLUENCE", 2, self)
            local influence = math.floor(self.negotiator:GetModifierStacks( "INFLUENCE" ) / 2)
            if influence > 0 then
                for i=1, influence do
                    self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
                end
            end
        end,
    },

    PC_ALAN_SUPPORT_plus =
    {
        name = "Pale Support",
        cost = 1,
    },

    PC_ALAN_SUPPORT_plus2 =
    {
        name = "Warped Support",
        desc = "Gain 2 <#UPGRADE>{DOMINANCE}, then Create 2 {PC_ALAN_FALLACY} for every {DOMINANCE} you have</>.",
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("DOMINANCE", 2, self)
            local dominance = math.floor(self.negotiator:GetModifierStacks( "DOMINANCE" ) / 2)
            if dominance > 0 then
                self.negotiator:AddModifier("PC_ALAN_FALLACY", dominance, self)
            end
        end,
    },

    PC_ALAN_RECKLESS =
    {
        name = "Reckless",
        icon = "negotiation/all_out.tex",
        desc = "Deals {1} less damage per friendly argument.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.reduction_amt )
        end,
        flavour = "'Come on then—I'm all in!'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        min_persuasion = 5,
        max_persuasion = 7,
        reduction_amt = 3,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self then
                    local mod_num = CountArguments(self)
                    persuasion:AddPersuasion(-( mod_num * self.reduction_amt ), -( mod_num * self.reduction_amt ), self)
                end
            end,
        },
    },

    PC_ALAN_RECKLESS_plus =
    {
        name = "Softened Reckless",
        desc = "Deals <#UPGRADE>{1}</> less damage per friendly argument.",
        reduction_amt = 2,
    },

    PC_ALAN_RECKLESS_plus2 =
    {
        name = "Tactless Reckless",
        desc = "<#DOWNGRADE>{PA_REASON} {1}: This card deal no damage</>.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.reason_amt )
        end,
        min_persuasion = 8,
        max_persuasion = 10,
        reason_amt = 1,
        reduction_amt = 99,
    },

    PC_ALAN_APPLY_PRESSURE =
    {
        name = "Apply Pressure",
        icon = "negotiation/overturn.tex",
        desc = "After play this card, it will gains {1} damage until the end of this negotiation.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.gain )
        end,
        flavour = "'Nothing much, just a reminder—we're running out of time.'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        min_persuasion = 2,
        max_persuasion = 2,
        gain = 2,
        OnPostResolve = function( self, minigame, targets )
            self.bonus = (self.bonus or 0) + self.gain
            self:NotifyChanged()
        end,
        deck_handlers = ALL_DECKS,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
                if source == self and (self.bonus or 0) > 0 then
                    persuasion:AddPersuasion( self.bonus, self.bonus, self )
                end
            end
        }
    },

    PC_ALAN_APPLY_PRESSURE_plus =
    {
        name = "Boosted Apply Pressure",
        min_persuasion = 4,
        max_persuasion = 4,
    },

    PC_ALAN_APPLY_PRESSURE_plus2 =
    {
        name = "Unreasonable Apply Pressure",
        desc = "<#DOWNGRADE>{PA_UNREASON}: </>After play this card, it will gains <#UPGRADE>{1}</> damage until the end of this negotiation.",
        gain = 4,
        OnPostResolve = function( self, minigame, targets )
            local mod_num = CountArguments(self)
            if mod_num == 0 then
                self.bonus = (self.bonus or 0) + self.gain
                self:NotifyChanged()
            end
        end,
    },

    PC_ALAN_BULLY =
    {
        name = "Bully",
        icon = "negotiation/bully.tex",
        desc = "For every person that hate you and love you, deal {1} bonus damage.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.bonus_damage )
        end,
        flavour = "'Nothing much, just a reminder—we're running out of time.'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        min_persuasion = 0,
        max_persuasion = 0,
        bonus_damage = 2,
        deck_handlers = ALL_DECKS,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion )
            local enemy = CountNegativeRelationsCNR(self)
                if source == self and enemy > 0 then
                    persuasion:AddPersuasion( self.bonus_damage * enemy, self.bonus_damage * enemy, self )
                end
            end
        }
    },

    PC_ALAN_BULLY_plus =
    {
        name = "Pale Bully",
        desc = "For every person that hate you and love you, deal <#DOWNGRADE>{1}</> bonus damage.",
        cost = 0,
        bonus_damage = 1,
    },

    PC_ALAN_BULLY_plus2 =
    {
        name = "Rude Bully",
        desc = "For every person that hate you and love you, deal {1} bonus damage.\n<#UPGRADE>{INCEPT} 1 {PC_ALAN_RUDE}</>.",
        OnPostResolve = function( self, minigame, targets )
            self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", 1, self)
        end,
    },

    PC_ALAN_YANK =
    {
        name = "Yank",
        icon = "negotiation/instigate.tex",
        desc = "{PA_VIOLENT} {1}: Draw {2} card.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.enemy_need, self.draw )
        end,
        flavour = "'Get over here!'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        min_persuasion = 2,
        max_persuasion = 2,
        draw = 1,
        enemy_need = 4,
        OnPostResolve = function( self, minigame, targets )
            local enemy = CountNegativeRelationsCNR(self)
            if enemy >= self.enemy_need then
                minigame:DrawCards(self.draw)
            end
        end,
    },

    PC_ALAN_YANK_plus =
    {
        name = "Boosted Yank",
        desc = "{PA_VIOLENT} {1}: Draw <#UPGRADE>{2}</> cards.",
        draw = 2,
    },

    PC_ALAN_YANK_plus2 =
    {
        name = "Violent Yank",
        desc = "{PA_VIOLENT} {1}: Draw {2} card.\n<#UPGRADE>{PA_VIOLENT} {3}: Add a copy of this card to your draw pile</>.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.enemy_need, self.draw, self.enemy_need_alt )
        end,
        enemy_need_alt = 7,
        OnPostResolve = function( self, minigame, targets )
            local enemy = CountNegativeRelationsCNR(self)
            if enemy >= self.enemy_need then
                minigame:DrawCards(self.draw)
            end
            if enemy >= self.enemy_need_alt then
                local copy = self:Duplicate()
                minigame:DealCard( copy, minigame:GetDeck( DECK_TYPE.DRAW ))
            end
        end,
    },

    PC_ALAN_FABRICATE =
    {
        name = "Fabricate",
        icon = "negotiation/notion.tex",
        desc = "Gain 1 {PC_ALAN_FALLACY} for each action available.",
        flavour = "'That's all there is to it. Believe it or not, I don't care. If you don't, then just get lost.'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.VARIABLE_COST,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        composure_amt = 0,
        fallacy_amt = 0,
        OnPostResolve = function( self, minigame, targets )
            local actions = minigame:GetActionCount()
            minigame:ModifyActionCount( -actions )
            self.negotiator:AddModifier("PC_ALAN_FALLACY", (actions + self.fallacy_amt), self)
            self.negotiator:DeltaComposure( (actions * self.composure_amt), self )
        end,
    },

    PC_ALAN_FABRICATE_plus =
    {
        name = "Boosted Fabricate",
        desc = "Gain 1 {PC_ALAN_FALLACY}<#UPGRADE>+1</> for each action available.",
        fallacy_amt = 1,
    },

    PC_ALAN_FABRICATE_plus2 =
    {
        name = "Stone Fabricate",
        desc = "Gain 1 {PC_ALAN_FALLACY} and <#UPGRADE>2 {COMPOSURE}</> for each action available.",
        composure_amt = 2,
    },

    PC_ALAN_HOT_COFFEE =
    {
        name = "Hot Coffee",
        icon = "negotiation/simmer.tex",
        desc = "While this is in your hand, all cards deal {1} bonus damage.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.bonus_damage )
        end,
        flavour = "'Still piping hot. Hope your face doesn’t have to test the temperature.'",
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

    PC_ALAN_TURN_THE_TABLES =
    {
        name = "Turn the Tables",
        icon = "negotiation/bulldoze.tex",
        desc = "Until the end of this turn, whenever you play a card, gain 1 {PC_ALAN_FALLACY}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.bonus_damage )
        end,
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

    PC_ALAN_TRADE_DONE =
    {
        name = "Trade Done",
        icon = "negotiation/trade.tex",
        desc = "For every arguments, bounties and inceptions that opponent have, gain 1 {PC_ALAN_FALLACY}.",
        flavour = "'Hope you won’t regret it.'",
        cost = 2,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        fallacy_amt = 0,
        OnPostResolve = function( self, minigame, targets )
            local count = 0
            for i, modifier in self.anti_negotiator:Modifiers() do
                if modifier:GetResolve() ~= nil and modifier.modifier_type ~= MODIFIER_TYPE.CORE then
                    count = count + 1
                end
            end

            self.negotiator:AddModifier("PC_ALAN_FALLACY", (count + self.fallacy_amt), self)
        end
    },

    PC_ALAN_TRADE_DONE_plus =
    {
        name = "Pale Trade Done",
        cost = 1,
    },

    PC_ALAN_TRADE_DONE_plus2 =
    {
        name = "Boosted Trade Done",
        desc = "For every arguments, bounties and inceptions that opponent have, gain 1 {PC_ALAN_FALLACY}<#UPGRADE>+1</>.",
        fallacy_amt = 1,
    },

    PC_ALAN_FLIP_THE_TABLE =
    {
        name = "Flip the Table",
        icon = "negotiation/erupt.tex",
        desc = "{PA_UNREASON}: When drawn, immediately play it free with a random target.\nDraw a card.",
        flavour = "'Then there’s nothing more to talk about!'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        min_persuasion = 1,
        max_persuasion = 4,
        draw = 1,
        event_handlers =
        {
            [ EVENT.DRAW_CARD ] = function( self, minigame, card, start_of_turn )
                if card == self then
                    local mod_num = CountArguments(self)
                        if mod_num == 0 then
                        minigame:PlayCard(card)
                    end
                end
            end,
        },
        OnPostResolve = function( self, minigame, targets )
            minigame:DrawCards(self.draw)
        end
    },

    PC_ALAN_FLIP_THE_TABLE_plus = 
    {
        name = "Rooted Flip the Table",
        min_persuasion = 4,
    },

    PC_ALAN_FLIP_THE_TABLE_plus2 =
    {
        name = "Visionary Flip the Table",
        desc = "{PA_UNREASON}: When drawn, immediately play it free with a random target.\nDraw <#UPGRADE>2</> cards.",
        draw = 2,
    },

    PC_ALAN_ACCURE =
    {
        name = "Accuse",
        icon = "negotiation/improvise_obtuse.tex",
        desc = "{PA_UNREASON}: Gain {1} action and draw {2} card.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.action_bonus, self.draw )
        end,
        flavour = "'How much more of Hesh’s time must you waste?!'",
        cost = 0,
        flags = CARD_FLAGS.HOSTILE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 10,
        draw = 1,
        action_bonus = 1,
        OnPostResolve = function( self, minigame, targets )
            local mod_num = CountArguments(self)
            if mod_num == 0 then
                minigame:DrawCards(self.draw)
                minigame:ModifyActionCount(self.action_bonus)
            end
        end
    },

    PC_ALAN_ACCURE_plus =
    {
        name = "Visionary Accuse",
        desc = "{PA_UNREASON}: Gain {1} action and draw <#UPGRADE>{2}</> cards.",
        draw = 2,
    },

    PC_ALAN_ACCURE_plus2 =
    {
        name = "Boosted Accuse",
        desc = "{PA_UNREASON}: Gain <#UPGRADE>{1}</> actions and draw {2} card.",
        action_bonus = 2,
    },

    PC_ALAN_FOOLHARDY =
    {
        name = "Foolhardy",
        icon = "negotiation/disregard.tex",
        desc = "{PA_UNREASON}: {INCEPT} {1} {PC_ALAN_RUDE}.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.rude_amt )
        end,
        flavour = "'Either back down now—or go call the Admiralty, if you dare.'",
        cost = 1,
        flags = CARD_FLAGS.HOSTILE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        min_persuasion = 2,
        max_persuasion = 2,
        rude_amt = 1,
        OnPostResolve = function( self, minigame, targets )
            local mod_num = CountArguments(self)
            if mod_num == 0 then
                self.anti_negotiator:InceptModifier("PC_ALAN_RUDE", self.rude_amt, self)
            end
        end
    },

    PC_ALAN_FOOLHARDY_plus =
    {
        name = "Pale Foolhardy",
        cost = 0,
    },

    PC_ALAN_FOOLHARDY_plus2 =
    {
        name = "Boosted Foolhardy",
        desc = "{PA_UNREASON}: {INCEPT} <#UPGRADE>{1}</> {PC_ALAN_RUDE}.",
        rude_amt = 2,
    },

    PC_ALAN_QUESTION =
    {
        name = "Question",
        icon = "negotiation/seeds_of_doubt.tex",
        desc = "If your opponent has any inception, draw {1} cards.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.draw )
        end,
        flavour = "'Be honest, man—those two question signs on your head aren’t gonna cause problems?'",
        cost = 1,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        draw = 3,
        OnPostResolve = function( self, minigame, targets )
            local draw_card = false
            for i, modifier in self.anti_negotiator:Modifiers() do
                if modifier.modifier_type == MODIFIER_TYPE.INCEPTION then
                    draw_card = true
                break
            end
        end
            if draw_card == true then
                minigame:DrawCards(self.draw)
            end
        end
    },

    PC_ALAN_QUESTION_plus =
    {
        name = "Boosted Question",
        desc = "If your opponent has any inception, draw <#UPGRADE>{1}</> cards.",
        draw = 4,
    },

    PC_ALAN_QUESTION_plus2 =
    {
        name = "Improvised Question",
        desc = "If your opponent has any inception, <#UPGRADE>{IMPROVISE_PLUS}</> <#DOWNGRADE>{1}</> cards.",
        draw = 2,
        OnPostResolve = function( self, minigame )
            local draw_card = false
            for i, modifier in self.anti_negotiator:Modifiers() do
                if modifier.modifier_type == MODIFIER_TYPE.INCEPTION then
                    draw_card = true
                break
            end
        end
            if draw_card == true then
                local cards = {}
                if minigame:GetDrawDeck():CountCards() == 0 then
                    minigame:ShuffleDiscardToDraw()
                end

                for i, card in minigame:GetDrawDeck():Cards() do
                    table.insert(cards, card)
                end
                cards = table.multipick( cards, 5 )
                minigame:ImproviseCards( cards, self.draw, nil, nil, nil, self )
            end
        end,
    },

    PC_ALAN_INTERROGATE =
    {
        name = "Interrogate",
        icon = "negotiation/flash_badge.tex",
        desc = "{PA_INTERROGATE|}Create 1 {PA_INTERROGATE}.",
        flavour = "'Hope you're just joking.'",
        cost = 2,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 7,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PA_INTERROGATE", 1, self)
        end
    },

    PC_ALAN_INTERROGATE_plus =
    {
        name = "Initial Interrogate",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_INTERROGATE_plus2 =
    {
        name = "Pale Interrogate",
        cost = 1,
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

    PC_ALAN_BUY_OFF = 
    {
        name = "Buy Off",
        icon = "negotiation/improvise_bank.tex",
        desc = "Insert {1} {hush_money} into your discard pile.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.card_gain )
        end,
        flavour = "'Keep it under wraps!'",
        cost = 1,
        flags = CARD_FLAGS.MANIPULATE,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 9,
        card_gain = 1,
        OnPostResolve = function( self, minigame, targets )
            local cards = {}
                for i=1, self.card_gain do
                    local card = Negotiation.Card("hush_money", self.owner)
                    table.insert(cards, card)
                end
            minigame:DealCards( cards, minigame:GetDiscardDeck() )
        end
    },

    PC_ALAN_BUY_OFF_plus =
    {
        name = "Boosted Buy Off",
        desc = "Insert <#UPGRADE>{1}</> {hush_money} into your discard pile.",
        card_gain = 2,
    },

    PC_ALAN_BUY_OFF_plus2 =
    {
        name = "Swift Buy Off",
        desc = "Insert {1} {hush_money} into your <#UPGRADE>hand</>.",
        OnPostResolve = function( self, minigame, targets )
            local cards = {}
                for i=1, self.card_gain do
                    local card = Negotiation.Card("hush_money", self.owner)
                    table.insert(cards, card)
                end
            minigame:DealCards( cards, minigame:GetHandDeck() )
        end
    },

    PC_ALAN_DEEP_BREATH =
    {
        name = "Deep Breath",
        icon = "negotiation/second_wind.tex",
        desc = "All friendly arguments deal double damage for this turn.",
        flavour = "'Just... give me a moment.'",
        cost = 3,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNCOMMON,
        max_xp = 3,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_DEEP_BREATH", 1, self)
        end,
    },

    PC_ALAN_DEEP_BREATH_plus =
    {
        name = "Pale Deep Breath",
        cost = 2,
    },

    PC_ALAN_DEEP_BREATH_plus2 =
    {
        name = "Twisted Deep Breath",
        desc = "All <#UPGRADE>cards</> deal double damage for this turn.\n<#DOWNGRADE>Gain 1 {PC_ALAN_RUDE} and 1 {VULNERABILITY}</>.",
        cost = 0,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:InceptModifier("PC_ALAN_RUDE", 1, self)
            self.negotiator:InceptModifier("VULNERABILITY", 1, self)
            self.negotiator:AddModifier("escalate", 1, self)
        end,
    },

    PC_ALAN_UNITED_FRONT =
    {
        name = "United Front",
        icon = "negotiation/take_supporters.tex",
        desc = "Apply {1} {COMPOSURE} to a random friendly argument.\n{PA_REASON} X: Repeat X times.",
        flavour = "'I’ve got my crew behind me.'",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self:CalculateComposureText(self.composure_amt))
        end,
        cost = 1,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MANIPULATE,
        target_self = TARGET_ANY_RESOLVE,
        auto_target = true,
        composure_amt = 2,
        max_xp = 9,
        OnPostResolve = function( self, minigame, targets )
            local mod_num = CountArguments(self)
            if mod_num > 0 then
                for i=1, (mod_num + 1) do
                    local target = minigame:CollectPrimaryTarget(self)
                    target:DeltaComposure(self.composure_amt, self)
                    self:ClearTarget()
                end
            end
        end,
    },

    PC_ALAN_UNITED_FRONT_plus =
    {
        name = "Stone United Front",
        desc = "Apply <#UPGRADE>{1}</> {COMPOSURE} to a random friendly argument.\n{PA_REASON} X: Repeat X times.",
        composure_amt = 3,
    },

    PC_ALAN_UNITED_FRONT_plus2 =
    {
        name = "On my own",
        desc = "Apply {1} {COMPOSURE} to a random friendly argument.\n{PA_REASON} X: Repeat X times.\n<#UPGRADE>{PA_UNREASON}: Gain 5 {COMPOSURE}</>.",
        flavour = "'I’ve got my crew behind me... okay, I lied.'",
        composure_bonus = 5,
        OnPostResolve = function( self, minigame, targets )
            local mod_num = CountArguments(self)
            if mod_num > 0 then
                for i=1, (mod_num + 1) do
                    local target = minigame:CollectPrimaryTarget(self)
                    target:DeltaComposure(self.composure_amt, self)
                    self:ClearTarget()
                end
            end

            if mod_num == 0 then 
                self.negotiator:DeltaComposure( self.composure_bonus, self )
            end
        end,
    },

    PC_ALAN_GOSSIP =
    {
        name = "Gossip",
        icon = "negotiation/ad_hominem.tex",
        desc = "{PA_GOSSIP|}Gain: All friendly arguments deal 1 bonus damage.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self:CalculateComposureText(self.composure_amt))
        end,
        flavour = "'Hey, you heard? Things haven’t been too quiet around here lately.'",
        cost = 2,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        max_xp = 7,
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("PA_GOSSIP", 1, self)
        end
    },

    PC_ALAN_GOSSIP_plus =
    {
        name = "Initial Gossip",
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND | CARD_FLAGS.AMBUSH,
    },

    PC_ALAN_GOSSIP_plus2 =
    {
        name = "Pale Gossip",
        cost = 1,
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
        cost = 2,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MANIPULATE,
        max_xp = 7,
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
        name = "Pale Cause and Effect",
        cost = 1,
    },

    PC_ALAN_PROFANE_ARTIFACT =
    {
        name = "Profane Artifact",
        icon = "negotiation/helmet.tex",
        desc = "{bog_boil|}Destroy a chosen friendly argument, then create 1 {bog_boil}.",
        flavour = "'This device contains the knowledge carried by a willing Bogger. Handle with care.'",
        cost = 2,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        max_xp = 7,
        DestroyModifier = true,
        target_self = TARGET_FLAG.ARGUMENT | TARGET_FLAG.BOUNTY,
        auto_target = false,
        CanTarget = function(self, target)
            if self.DestroyModifier then
                if not target or target.negotiator == self.anti_negotiator then
                    return false, CARD_PLAY_REASONS.INVALID_TARGET
                end
            end
            return true
        end,
        OnPostResolve = function( self, minigame, targets )
            if self.DestroyModifier and targets then
                local destroyed = false
                for _, target in ipairs(targets) do
                    if target.modifier_type ~= MODIFIER_TYPE.CORE and target.negotiator ~= self.anti_negotiator then
                        target.negotiator:DestroyModifier(target, self)
                        destroyed = true
                    end
                end

                if destroyed then
                    for i = 1, 1 do
                        self.negotiator:CreateModifier("bog_boil", 1, self)
                    end
                end

                else
                    for i = 1, 1 do
                        self.negotiator:CreateModifier("bog_boil", 1, self)
                    end
                end
            end
    },

    PC_ALAN_PROFANE_ARTIFACT_plus =
    {
        name = "Pale Profane Artifact",
        cost = 1,
    },

    PC_ALAN_PROFANE_ARTIFACT_plus2 =
    {
        name = "Softened Profane Artifact",
        desc = "{bog_boil|}<#UPGRADE>Create 1 {bog_boil}</>.",
        DestroyModifier = false,
        auto_target = true,
    },

    PC_ALAN_REPEAT =
    {
        name = "Repeat",
        icon = "negotiation/duplicity.tex",
        desc = "Duplicate a chosen friendly argument.",
        flavour = "'Now you get it, right?'",
        cost = 2,
        rarity = CARD_RARITY.UNCOMMON,
        flags = CARD_FLAGS.MANIPULATE | CARD_FLAGS.EXPEND,
        max_xp = 7,
        target_self = TARGET_FLAG.ARGUMENT,
        auto_target = false,
        count = 1,
        loc_strings =
        {
            NO_DUPLICATE_CORE = "Cannot duplicate core argument",
        },
        CanPlayCard = function ( self, card, engine, target )
            if is_instance( target, Negotiation.Modifier ) and target.modifier_type == MODIFIER_TYPE.CORE then
                return false, self.def:GetLocalizedString( "NO_DUPLICATE_CORE" )
            end
            return true
        end,
        OnPostResolve = function( self, minigame, targets )
            for i, target in ipairs( targets ) do
                for j = 1, self.count do
                    target:Duplicate()
                end
            end
        end
    },

    PC_ALAN_REPEAT_plus =
    {
        name = "Wide Repeat",
        desc = "Duplicate a <#DOWNGRADE>random</> friendly argument <#UPGRADE>twice</>.",
        count = 2,
        auto_target = true,
    },

    PC_ALAN_REPEAT_plus2 =
    {
        name = "Pale Repeat",
        cost = 1,
    },

    PC_ALAN_CLARIFICATION =
    {
        name = "Clarification",
        icon = "negotiation/setup.tex",
        desc = "For every {PC_ALAN_TRUTH} you have, create 1 {PC_ALAN_TRUTH}.",
        flavour = "'Alright, to be more precise...'",
        cost = 2,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 7,
        OnPostResolve = function( self, minigame, targets )
            local count = 0
            for i, modifier in self.negotiator:Modifiers() do
                if modifier.id == "PC_ALAN_TRUTH" then
                    count = count + 1
                end
            end
            for i=1, count do
                local target = minigame:CollectPrimaryTarget(self)
                target:DeltaComposure(self.stacks * 2, self)
                self:ClearTarget()
            end
        end,
    },

    PC_ALAN_CLARIFICATION_plus =
    {
        name = "Pale Clarification",
        cost = 1,
    },

    PC_ALAN_CLARIFICATION_plus2 =
    {
        name = "Boosted Clarification",
        desc = "<#UPGRADE>Create 1 {PC_ALAN_TRUTH}</>, then for every {PC_ALAN_TRUTH} you have, create 1 {PC_ALAN_TRUTH}.",
        OnPostResolve = function( self, minigame, targets )
            self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
            local count = 0
            for i, modifier in self.negotiator:Modifiers() do
                if modifier.id == "PC_ALAN_TRUTH" then
                    count = count + 1
                end
            end
            for i=1, count do
                self.negotiator:CreateModifier("PC_ALAN_TRUTH", 1, self)
            end
        end,
    },

    PC_ALAN_PLAYING_THE_FOOL =
    {
        name = "Playing the fool",
        icon = "negotiation/flatten.tex",
        desc = "Fully restore resolve to the opponent's core argument. Gain 1 {PC_ALAN_GENUINE} for every {1} resolve restored this way.",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.genuine_divided)
        end,
        flavour = "'Look, it's me — Smith “Turtle” Banquods'",
        cost = 2,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.RARE,
        max_xp = 7,
        genuine_bonus = 0,
        genuine_divided = 2,
        OnPostResolve = function( self, minigame, targets )
            local cur, max = self.anti_negotiator:GetResolve()
            local genuine_amt = max - cur
            self.anti_negotiator:RestoreResolve( genuine_amt, self )
            self.negotiator:InceptModifier("PC_ALAN_GENUINE", math.floor(genuine_amt / self.genuine_divided) + self.genuine_bonus, self)
        end,
    },

    PC_ALAN_PLAYING_THE_FOOL_plus =
    {
        name = "Mirrored Playing the fool",
        desc = "Fully restore resolve to the opponent's core argument. Gain 1 {PC_ALAN_GENUINE} for every <#UPGRADE>{1}</> resolve restored this way.",
        cost = 4,
        genuine_divided = 1,
    },

    PC_ALAN_PLAYING_THE_FOOL_plus2 =
    {
        name = "Boosted Playing the fool",
        desc = "Fully restore resolve to the opponent's core argument. Gain 1 {PC_ALAN_GENUINE}<#UPGRADE>+4</> for every {1} resolve restored this way.",
        genuine_bonus = 4,
    },
}

for i, id, carddef in sorted_pairs( CARDS ) do
    carddef.series = "SHEL"
    Content.AddNegotiationCard( id, carddef )
end

local FEATURES =
{
    PA_REASON =
    {
        name = "Reason",
        desc = "If the amount of arguments (except core argument and inception) is <#HILITE>at least</> a certain amount before this card is played, an additional effect will be triggered.",
    },

    PA_UNREASON =
    {
        name = "Unreason",
        desc = "If there are no arguments (except core argument and inception) before this card is played, an additional effect is triggered."
    },

    PA_FRIENDLY =
    {
        name = "Friendly",
        desc = "When the number of characters who <#HILITE>love</> or <#HILITE>like</> you reaches a certain amount , an additional effect will be triggered.",
    },

    PA_VIOLENT =
    {
        name = "Violent",
        desc = "When the number of characters who <#HILITE>hate</> or <#HILITE>dislike</> you reaches a certain amount , an additional effect will be triggered.",
    },
}

for id, data in pairs(FEATURES) do
    local def = NegotiationFeatureDef(id, data)
    Content.AddNegotiationCardFeature(id, def)
end
