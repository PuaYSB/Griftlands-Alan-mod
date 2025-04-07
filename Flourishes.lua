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
{}

for i, id, data in sorted_pairs( NEGOTIATION_FLOURISHES ) do
	data.series = "SHEL"
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
		target_type = TARGET_TYPE.SELF,
		num_draw = 8,
        OnPostResolve = function( self, battle, attack )
            battle:DrawCards( self.num_draw )
            battle:DiscardCards(nil, nil, self)
        end
	},
}



for i, id, data in sorted_pairs( BATTLE_FLOURISHES ) do
	data.series = "SHEL"
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