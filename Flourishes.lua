local negotiation_defs = require "negotiation/negotiation_defs"
local NEGOTIATION_FLAGS = negotiation_defs.CARD_FLAGS
local EVENT = negotiation_defs.EVENT
local battle_defs = require "battle/battle_defs"
local CARD_FLAGS = battle_defs.CARD_FLAGS
local BATTLE_EVENT = battle_defs.EVENT

local RARITY_TABLE = {
	CARD_RARITY.COMMON,
	CARD_RARITY.UNCOMMON,
	CARD_RARITY.RARE
}

local NEGOTIATION_FLOURISHES = 
{
		PC_ALAN_COMPOSURE =
	{
		name = "Composure",
		desc = "Gain 1 {INFLUENCE} and 3 {DOMINANCE}.",
		icon = "negotiation/weight.tex",
		flavour = "'Calm down. Think about what's left to say, and what's left to do.'",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		basic_flourish = true,
		OnPostResolve = function( self, minigame, targets )
			self.negotiator:AddModifier( "INFLUENCE", 1, self )
			self.negotiator:AddModifier( "DOMINANCE", 3, self )
		end,
	},

	PC_ALAN_TESTING =
	{
		name = "Testing",
		desc = "Attack a random opponent argument once for every card in your hand.",
		icon = "negotiation/just_the_facts.tex",
		flavour = "'Is that so?'",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		target_mod = TARGET_MOD.RANDOM1,
        auto_target = true,
        min_persuasion = 2,
        max_persuasion = 2,
		OnPostResolve = function( self, minigame, targets )
			local count = minigame:GetHandDeck():CountCards()
            if count > 0 then
            	for i = 1, count do
            		minigame:ApplyPersuasion( self )
            		self:AssignTarget( nil )
            	end
            end
		end,
	},

	PC_ALAN_TESTING_ii =
	{
		name = "Testing II",
		desc = "Deal 3 damage to a random opponent argument for every card in your hand.",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		target_mod = TARGET_MOD.RANDOM1,
        auto_target = true,
        min_persuasion = 3,
        max_persuasion = 3,
		OnPostResolve = function( self, minigame, targets )
			local count = minigame:GetHandDeck():CountCards()
            if count > 0 then
            	for i = 1, count do
            		minigame:ApplyPersuasion( self )
            		self:AssignTarget( nil )
            	end
            end
		end,
	},

	PC_ALAN_BRIDE =
	{
		name = "Bribe",
		desc = "Add 4 copies of {hush_money} to your hand.",
		icon = "negotiation/hush_money.tex",
		flavour = "'Don't be shy, just take it.'",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		OnPostResolve = function( self, minigame )
			local cards = {}
            for i = 1, 4 do
                local card = Negotiation.Card( "hush_money", self.owner )
                card:ClearXP()
                card:MakeTemporary()
                table.insert( cards, card )
            end
            minigame:DealCards( cards, minigame:GetHandDeck() )
		end,
	},

	PC_ALAN_BRIDE_ii =
	{
		name = "Bribe II",
		desc = "Add 6 copies of {hush_money} to your hand.",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		OnPostResolve = function( self, minigame )
			local cards = {}
            for i = 1, 6 do
                local card = Negotiation.Card( "hush_money", self.owner )
                card:ClearXP()
                card:MakeTemporary()
                table.insert( cards, card )
            end
            minigame:DealCards( cards, minigame:GetHandDeck() )
		end,
	},

	PC_ALAN_PREPARATION =
	{
		name = "Preparation",
		desc = "Play all basic cards in your hand.",
		icon = "negotiation/long_winded.tex",
		flavour = "'Hope you're ready.'",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		OnPostResolve = function( self, minigame, card )
		    for i, card in self.engine:GetHandDeck():Cards() do
		        if card.rarity == CARD_RARITY.BASIC then
			        minigame:PlayCard( card, nil, 1.0)
			    end
		    end
		end,
	},

	PC_ALAN_PREPARATION_ii =
	{
		name = "Preparation II",
		desc = "Play all basic cards in your hand and draw pile.",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		OnPostResolve = function( self, minigame, card )
		    for i, card in self.engine:GetHandDeck():Cards() do
		        if card.rarity == CARD_RARITY.BASIC then
			        minigame:PlayCard( card, nil, 1.0)
			    end
		    end

		    for i, card in self.engine:GetDrawDeck():Cards() do
		        if card.rarity == CARD_RARITY.BASIC then
			        minigame:PlayCard( card, nil, 1.0)
			    end
		    end
		end,
	},

	PC_ALAN_WINDFALL =
	{
		name = "Windfall",
		desc = "Gain 30 shills.",
		icon = "negotiation/cash_out.tex",
		flavour = "'Yes, I used my sheer charm to score this many shills.'",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		OnPostResolve = function( self, minigame )
			self.engine:ModifyMoney( 30 )
		end,
	},

	PC_ALAN_WINDFALL_ii =
	{
		name = "Windfall II",
		desc = "Gain 50 shills.",
		flags = NEGOTIATION_FLAGS.MANIPULATE,
		series = "ALAN",
		OnPostResolve = function( self, minigame )
			self.engine:ModifyMoney( 50 )
		end,
	},
}

for i, id, data in sorted_pairs( NEGOTIATION_FLOURISHES ) do
	data.series = "ALAN"
	assert(data.series, loc.format("Series missing on {1}", data.name))
	if id:match( "(.*)_ii.*$" ) then
		data.base_id = id:match( "(.*)_ii.*$" )
		data.pp_cost = 15
	elseif data.basic_flourish then
		data.pp_cost = 0
	else
		data.pp_cost = 5
	end
	if not data.basic_flourish then
		data.max_xp = 0
	end
	data.flags = data.flags | NEGOTIATION_FLAGS.FLOURISH
	data.rarity = CARD_RARITY.UNIQUE
	data.cost = 0
	data.flourish = true
	Content.AddNegotiationCard( id, data )
end

local BATTLE_FLOURISHES =
{
	PC_ALAN_FOCUSED_FIRE =
	{
		name = "Focused Fire",
		desc = "Attack three times.",
		icon = "battle/automech_blaster.tex",
		anim = "shoot",
		flavour = "'Still too slow!'",
		flags = CARD_FLAGS.RANGED,
		series = "ALAN",
		basic_flourish = true,
		target_type = TARGET_TYPE.ENEMY,
		hit_count = 3,
		min_damage = 2,
		max_damage = 4,
	},

	PC_ALAN_TITANIC_LIFT =
	{
		name = "Titanic Lift",
		desc = "Attack all enemies.",
		flavour = "'Whoever takes this is looking at months in the hospital.'",
		anim = "attack3",
		icon = "battle/final_blow.tex",
		flags = CARD_FLAGS.MELEE,
		series = "ALAN",
		target_type = TARGET_TYPE.ENEMY,
		target_mod = TARGET_MOD.TEAM,
        min_damage = 10,
        max_damage = 10,
	},

	PC_ALAN_TITANIC_LIFT_ii =
	{
		name = "Titanic Lift II",
		desc = "Attack all enemies twice.",
		anim = "attack3",
		flags = CARD_FLAGS.MELEE,
		series = "ALAN",
		target_type = TARGET_TYPE.ENEMY,
		hit_count = 2,
	},

	PC_ALAN_LUMIN_BIO_ACCELERATOR =
	{
		name = "Lumin Bio-Accelerator",
		desc = "Gain {1} {LUMIN_RESERVE} and {2} {EVASION}.",
		desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.lumin_res_amt, self.eva_amt )
        end,
		flavour = "'Rumor has it, this is the same type of relic Gorgula used.'",
		anim = "taunt",
		icon = "battle/lumin_generator.tex",
		flags = CARD_FLAGS.SKILL,
		series = "ALAN",
		target_type = TARGET_TYPE.SELF,
        lumin_res_amt = 5,
        eva_amt = 1,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
            self.owner:AddCondition("EVASION", self.eva_amt, self)
        end
	},

	PC_ALAN_LUMIN_BIO_ACCELERATOR_ii = 
	{
		name = "Lumin Bio-Accelerator II",
		desc = "Gain {1} {LUMIN_RESERVE} and {2} {EVASION}.",
		flags = CARD_FLAGS.SKILL,
		series = "ALAN",
		target_type = TARGET_TYPE.SELF,
        lumin_res_amt = 10,
        eva_amt = 3,
        OnPostResolve = function( self, battle, attack )
            self.owner:AddCondition("LUMIN_RESERVE", self.lumin_res_amt, self)
            self.owner:AddCondition("EVASION", self.eva_amt, self)
        end
	},

	PC_ALAN_SPARK_CANNON = 
	{
		name = "Spark Cannon",
		desc = "Apply {1} {SPARK_RESERVE}.",
		desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.spark_amt )
        end,
		flavour = "'I paid a fortune for this high-quality knockoff!'",
		anim = "throw",
		icon = "battle/spark_cannon.tex",
		flags = CARD_FLAGS.RANGED,
		series = "ALAN",
		target_type = TARGET_TYPE.ENEMY,
		spark_amt = 5,
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
        end
	},

	PC_ALAN_SPARK_CANNON_ii = 
	{
		name = "Spark Cannon II",
		desc = "Apply {1} {SPARK_RESERVE}.",
		desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.spark_amt )
        end,
		flags = CARD_FLAGS.RANGED,
		series = "ALAN",
		target_type = TARGET_TYPE.ENEMY,
		spark_amt = 10,
        OnPostResolve = function( self, battle, attack )
            attack.target:AddCondition("SPARK_RESERVE", self.spark_amt, self)
        end
	},

	PC_ALAN_SCROUNGE =
	{
		name = "Scrounge",
		desc = "Draw {1} card,Discard any number of cards.",
		desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.num_draw )
        end,
		flavour = "'Remember to put away what you don’t need—don’t just toss things around.'",
		anim = "taunt",
		icon = "battle/scrounge.tex",
		flags = CARD_FLAGS.SKILL,
		series = "ALAN",
		target_type = TARGET_TYPE.SELF,
		num_draw = 4,
        OnPostResolve = function( self, battle, attack )
            battle:DrawCards( self.num_draw )
            battle:DiscardCards(nil, nil, self)
        end
	},

	PC_ALAN_SCROUNGE_ii =
	{
		name = "Scrounge II",
		desc = "Draw {1} card,Discard any number of cards.",
		desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.num_draw )
        end,
		flags = CARD_FLAGS.SKILL,
		series = "ALAN",
		target_type = TARGET_TYPE.SELF,
		num_draw = 8,
        OnPostResolve = function( self, battle, attack )
            battle:DrawCards( self.num_draw )
            battle:DiscardCards(nil, nil, self)
        end
	},
}



for i, id, data in sorted_pairs( BATTLE_FLOURISHES ) do
	data.series = "ALAN"
	assert(data.series, loc.format("Series missing on {1}", data.name))
	if id:match( "(.*)_ii.*$" ) then
		data.base_id = id:match( "(.*)_ii.*$" )
		data.pp_cost = 10
	elseif data.basic_flourish then
		data.pp_cost = 0
	else
		data.pp_cost = 5
	end
	if not data.basic_flourish then
		data.max_xp = 0
	end
	data.rarity = CARD_RARITY.UNIQUE
	data.flags = data.flags | CARD_FLAGS.FLOURISH
	data.cost = 0
	data.flourish = true
	Content.AddBattleCard( id, data )
end