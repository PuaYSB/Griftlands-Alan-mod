local patron_weights = {
    LUMINITIATE = 1,
    PRIEST = 1,
    LUMINARI = .25,

    SPARK_BARON_GOON = 1,
    SPARK_BARON_TASKMASTER = 1,
    SPARK_BARON_PROFESSIONAL = .25,

    ADMIRALTY_GOON = 1,
    ADMIRALTY_GUARD = 1,
    ADMIRALTY_PATROL_LEADER = .25,

    JAKES_RUNNER = .5,
    JAKES_SMUGGLER = .5,
    JAKES_LIFTER = .25,
}


local brawl = require "content/quests/brawl/brawl_util"
local data = table.extend(brawl.base_data)
{
    home_loc_name = "Moreef's Place",
    home_loc_desc = "Sweet Moreef's bar",
    home_loc_plax = "INT_SMITHBAR",
    bartender_alias = "SWEET_MOREEF",
    merchant_list = {
        "grafts", "negotiation", "battle", "pets"
    },
    bosses = {
        {"SPARK_BARON_BOSS", "DRONE_GOON", "HESH_BOSS", "MERCENARY_BOSS", "RENTORIAN_BOSS", "WEEZIL", "BRUT", "RISE_TURNCOAT_BOSS"},
        {"JAKES_ASSASSIN", "JAKES_ASSASSIN2", "FLEAD_QUEEN", "AUTOMECH_BOSS", "MARK_NINE_NINE", "TWIN_BOSS_1"},
        {"SPARK_SECOND", "RISE_SECOND", "SHROOG", "DRUSK_1", "SHREDMAW", "DROAD"},
        {"MURDER_BAY_BANDIT_CONTACT", "MURDER_BAY_ADMIRALTY_CONTACT"},
        {"KASHIO"},
    }
}

data.MakeBrawlSchedule = function(data)

    local all_valid_quests = {}
    for id, def in pairs( Content.GetAllQuests() ) do
        if def.qtype == QTYPE.SIDE and not def:HasTag("manual_spawn") and def:FilterForAct( "SAL_BRAWL" ) and (def.character_specific == nil or table.contains(def.character_specific, "SAL")) then
            table.insert(all_valid_quests, def)
        end
    end
    local used_bosses = {}
    local selected_quests = {}

    --local day_1_quests = 
    --local day_2_quests = brawl.PickQuests(all_valid_quests, selected_quests, 2, 3, 1, 1)
    --local day_3_quests = brawl.PickQuests(all_valid_quests, selected_quests, 3, 3, 1, 1)
    --local day_4_quests = brawl.PickQuests(all_valid_quests, selected_quests, 4, 3, 1, 1)
    --local day_5_quests = brawl.PickQuests(all_valid_quests, selected_quests, 5, 3, 1, 1)

    
    local bs = BrawlSchedule()
    
    local bs = BrawlSchedule()
    bs:SetCurrentHome("home_bar")
        :Merchants(data.merchant_list)
        :QuestPhase("starting")
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 1, 2, 1, 1))
        :Bonus(data.all_bonuses, 2)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 1, 2, 1, 1))
        :Night()
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 1, 2, 1, 1))
        :Merchants({"mettle"})
        :Bonus(data.all_bonuses, 2)
        :Boss(brawl.PickBoss(data.bosses[1], used_bosses), true)
        :Sleep()

    bs:SetDifficulty(2)
        :Merchants(data.merchant_list)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 2, 2, 1, 1))
        :Bonus(data.all_bonuses, 2)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 2, 2, 1, 1))
        :Night()
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 2, 2, 1, 1))
        :Merchants({"mettle"})
        :Bonus(data.all_bonuses, 2)
        :Boss(brawl.PickBoss(data.bosses[2], used_bosses), true)
        :Sleep()

    bs:SetDifficulty(3)
        :Merchants(data.merchant_list)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 3, 2, 1, 1))
        :Bonus(data.all_bonuses, 2)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 3, 2, 1, 1))
        :Night()
        :Boss(brawl.PickBoss(data.bosses[1], used_bosses) )
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 3, 2, 1, 1))
        :Merchants({"mettle"})
        :Bonus(data.all_bonuses, 2)
        :Boss(brawl.PickBoss(data.bosses[3], used_bosses), true)
        :Sleep()

    bs:SetDifficulty(4)
        :Merchants(data.merchant_list)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 4, 2, 1, 1))
        :Bonus(data.all_bonuses, 2)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 4, 2, 1, 1))
        :Night()
        :Boss(brawl.PickBoss(data.bosses[2], used_bosses))
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 4, 2, 1, 1))
        :Merchants({"mettle"})
        :Bonus(data.all_bonuses, 2)
        :Boss(brawl.PickBoss(data.bosses[4], used_bosses), true)
        :Sleep()

    bs:SetDifficulty(5)
        :Merchants(data.merchant_list)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 5, 2, 1, 1))
        :Bonus(data.all_bonuses, 2)
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 5, 2, 1, 1))
        :Night(3)
        :Bonus(data.all_bonuses, 2)
        :Merchants({"mettle"})
        :Quests(brawl.PickQuests(all_valid_quests, selected_quests, 5, 2, 1, 1))
        :Merchants(data.merchant_list)
        :Boss(brawl.PickBoss( data.bosses[5], used_bosses))
        :Win()
    
    return bs.events
end

local QDEF = brawl.CreateBrawlQuest("ALAN_BRAWL", data)

QDEF:AddQuestLocation{
    cast_id = "home_bar",
    name = "Moreef's Place",
    desc = "Sweet Moreef's bar",
    plax = "INT_SMITHBAR",
    show_agents = true,
    tags = {"tavern"},
    indoors = true,
    work = 
    {
        bartender = CreateClosedJob( PHASE_MASK_ALL, "Bartender", CHARACTER_ROLES.PROPRIETOR, "GROG_N_DOG_ITEMS"),
    },
    patron_data = {
        num_patrons = 4,
        patron_generator = function(location)
            local def = weightedpick(patron_weights)
            TheGame:GetGameState():AddSkinnedAgent(def):GetBrain():SendToPatronize(location)
        end
    },
    on_assign = function(quest, location)
        AgentUtil.TakeJob(quest:GetCastMember("bartender"), location, "bartender")
    end,

}
