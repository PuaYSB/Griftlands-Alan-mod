local QDEF = QuestDef.Define{
        title = "Sal Alternate Day 1 Boss",
        qtype = QTYPE.STORY,
        icon = engine.asset.Texture("icons/quests/sal_story_act1_huntingkashio.tex"),
        rank = 1,
		
		on_init = function(quest)
		
			TheGame:GetGameState():SetMainQuest(quest)
			TheGame:GetGameState():GetCaravan():MoveToLocation( quest:SpawnTempLocation("AUCTION_HOUSE") )
			
		end,		
		
    }
    :AddLocationDefs{

        AUCTION_HOUSE =
        {
            name = "Auction House",
            desc = "The room where the auction is taking place.",
            show_agents = true,
            indoors = false,
            no_exit = true,
            plax = "EXT_DROPSITE",
        }
        
    }
    :AddCastByAlias{
        cast_id = "mark",
        alias = "NPC_PA_FAKE_SMITH",
        no_validation = true,
    }
    :AddCastByAlias{
        cast_id = "spark_baron_boss",
        alias = "HESH_BOSS",
        no_validation = true,
    }
    :AddObjective{
        id = "test",
        title = "Fight the Rise Turncoat Boss, and provide feedback!",
        state = QSTATUS.ACTIVE,
    }

QDEF:AddConvo("test")
    :ConfrontState("INTRO")
        :Fn(function(cxt)
            cxt.quest:SetRank(1)
            TheGame:GetGameState():SetDifficulty(1)
            cxt.quest.param.seed = 0
            cxt.encounter:DoLocationTransition(  cxt.quest:SpawnTempLocation("AUCTION_HOUSE") )
            cxt:GoTo("STATE_CHOOSE_BOSS") 
        end)
        :State("STATE_CHOOSE_BOSS")
            :Loc{
                DIALOG_INTRO = [[
                    * Choose the boss you wish to fight, or fight a random one.
                ]],
                OPT_SPECIFIC = "Fight {1#agent}",
                OPT_RANDOM = "Random Boss",
            }
            :Fn(function(cxt)
                local turncoat = cxt.quest:GetCastAgent("mark")
                cxt:Opt("OPT_SPECIFIC", turncoat)
                    :Fn(function(cxt)
                        cxt.enc:SetPrimaryCast(turncoat)
                        cxt:GoTo("STATE_DO_FIGHT")
                    end)

                local sparky = cxt.quest:GetCastAgent("spark_baron_boss")
                cxt:Opt("OPT_SPECIFIC", sparky)
                    :Fn(function(cxt)
                        cxt.enc:SetPrimaryCast(sparky)
                        cxt:GoTo("STATE_DO_FIGHT")
                    end)

                cxt:Opt("OPT_RANDOM")
                    :Fn(function(cxt)
                        cxt.enc:SetPrimaryCast(math.random() < 0.5 and turncoat or sparky)
                        cxt:GoTo("STATE_DO_FIGHT")
                    end)
            end)

        :State("STATE_DO_FIGHT")
            :Loc{
                DIALOG_INTRO = [[
                    player:
                        !left
                        !fight
                    agent:
                        !right
                        !fight
                ]],
                OPT_FIGHT = "Fight!",
                DIALOG_DONE_FIGHT = [[
                    left:
                        !happy
                    right:
                        !greeting
                    * Thanks for testing! Now would be a great time to submit some feedback about that fight! (Your seed was: {1})
                ]],
                OPT_RETRY = "Retry this exact fight",
                OPT_AGAIN = "Start over",
                DIALOG_AGAIN = [[
                    player:
                        !exit
                    agent:
                        !exit
                ]],
                OPT_FEEDBACK = "Tell us how that went!"
            }
            :Fn(function(cxt) 
                cxt:Dialog("DIALOG_INTRO")
                local ally = cxt.quest:CreateSkinnedAgent( "JAKES_SMUGGLER" )
                cxt:Opt("OPT_FIGHT")
                    :Battle{
                        flags = BATTLE_FLAGS.ISOLATED | BATTLE_FLAGS.NO_FLEE | BATTLE_FLAGS.SELF_DEFENCE,
                        -- allies = {ally},
                        IS_EXPERIMENT = true,
                        on_experiment_done = function( cxt, battle )
                            local player_team = {}
                            local enemy_team = {}
                            for k,v in ipairs(battle:GetScenario().teams[TEAM.BLUE]) do
                                table.insert(player_team, v:GetContentID())
                            end

                            for k,v in ipairs(battle:GetScenario().teams[TEAM.RED]) do
                                table.insert(enemy_team, v:GetContentID())
                            end

                            local player_state = TheGame:GetGameState():GetPlayerState()
                            local json_t = {
                                PLAYER_DATA = player_state,
                                BATTLE_DATA = {
                                    TURNS = battle.turns,
                                    CONTENT_ID = battle:GetScenario().content_id,
                                    HEALTH_DELTA = battle:GetPlayerFighter():GetHealth() - battle:GetPlayerFighter():GetMaxHealth(), -- Player always start with full HP
                                    PLAYER_TEAM = player_team,
                                    ENEMY_TEAM = enemy_team,
                                },
                                EXPERIMENT_DATA = {
                                    ENEMY_HEALTH_PERCENTAGE = battle:GetEnemyTeam():Primary():GetHealthPercent() * 100,
                                }
                            }
                            local evt_type = (battle:GetBattleResult() == BATTLE_RESULT.WON) and "EXPERIMENT_BATTLE_WON" or "EXPERIMENT_BATTLE_LOST"
                            SendMetricsData(evt_type, json_t )
                            local boss = cxt:GetAgent()
                            if boss then
                                boss:MoveToLimbo()
                            end
                        end,
                    }
                    
                    
                    :Fn(function() 
                        cxt:Dialog("DIALOG_DONE_FIGHT", cxt.quest.param.seed)

                        cxt:RunLoopingFn(function() 
                            cxt:Opt("OPT_FEEDBACK")
                                :Fn(function() TheGame:StartFeedback() end)
                            cxt:Opt("OPT_AGAIN")
                                :Fn(function(cxt)
                                    cxt.quest:UnassignCastMember("mark")
                                    cxt.quest:UnassignCastMember("spark_baron_boss")
                                    cxt.quest:AssignCastMember("mark")
                                    cxt.quest:AssignCastMember("spark_baron_boss")
                                end)
                                :Dialog("DIALOG_AGAIN")
                                :GoTo("STATE_INTRO")
                            cxt:Opt("OPT_RETRY")
                                :GoTo("STATE_DO_FIGHT")
                        end)
                    end)
            end)