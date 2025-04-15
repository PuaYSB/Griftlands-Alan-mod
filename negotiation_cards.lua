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
        if modifier:GetResolve() ~= nil and modifier.modifier_type ~= MODIFIER_TYPE.CORE then
            count = count + 1
        end
    end
    return count
end

local function CountPositiveRelationsCPR(self)
    local rel = self.negotiator.agent.social_connections
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
    local rel = self.negotiator.agent.social_connections
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
        desc = "All friendly attack arguments deal 1 bonus damage.",
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
        desc = "At the end of the turn, if the stacks of {PC_ALAN_GENUINE} is more than oppenent's core resovle, win the negotiation and upgrade their opinion of you by one level.",
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
        desc = "All resolve loss is increased by 3. Remove 1 stack at the start of your turn. At the end of the negotiation, if oppenent still having this inception, downgrade their opinion of you by one level.",
        icon = "negotiation/modifiers/animosity.tex",
        sound = "event:/sfx/battle/cards/neg/create_argument/vulnerability",
        modifier_type = MODIFIER_TYPE.INCEPTION,
        event_handlers =
        {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion, minigame, target )
                if target and target.owner == self.owner then
                    persuasion:AddPersuasion( 3, 3, self )
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
        desc = "At the end of your turn, deal 2 damage to a random opponent argument for every stack of {PC_ALAN_FALLACY}.\nAt the begin of your turn, clear all stacks.",
        icon = "negotiation/modifiers/hostility.tex",        
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        min_persuasion = 2,
        max_persuasion = 2,
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
        max_persuasion = 1,
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
        desc = "Gain {1} {PC_ALAN_GENUINE}\nCreate {2} {PC_ALAN_TRUTH}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.genuine_amt, self.truth_amt)
        end,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        cost = 0,
        genuine_amt = 3,
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
        desc = "If the amount of arguments (except core argument) is <#HILITE>at least</> a certain amount before this card is played, an additional effect will be triggered.",
    },

    PA_UNREASON =
    {
        name = "Unreason",
        desc = "If there are no arguments (except core argument) before this card is played, an additional effect is triggered."
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
