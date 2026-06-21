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
        alias = "DENIKUS",
        no_validation = true,
    }
    :AddCastByAlias{
        cast_id = "spark_baron_boss",
        alias = "BISHOP_OF_FOAM",
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
                OPT_SPECIFIC = "Debate {1#agent}",
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
                        !angry
                    agent:
                        !right
                        !fight
                ]],
            OPT_ATTACK = "Convince!",
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

            cxt:Opt("OPT_ATTACK")
                :Dialog("DIALOG_INTRO")
                :Negotiation{
                    flags = NEGOTIATION_FLAGS.WORDSMITH | NEGOTIATION_FLAGS.NO_IMPATIENCE,
                }
                    :OnSuccess()
                        :Fn(function() 
                                ConvoUtil.GiveQuestRewards(cxt)
                                cxt.quest:Complete()
                        end)
                    :OnFailure()
                        :Fn(function() 
                                cxt.quest:Fail()
                        end)
        end)