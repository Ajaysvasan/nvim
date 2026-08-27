-- ╔══════════════════════════════════════════════════════════════╗
-- ║          dashboard.lua — crafted with devil's blood          ║
-- ║        legends don't die, they open neovim instead          ║
-- ╚══════════════════════════════════════════════════════════════╝

local M = {}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  LOGOS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local logos = {

	-- ✦ DEVIL MAY CRY 5 — Dante (Priority/Featured)
	{
		art = [[

                                                   ██████
                                                 ██      ██
                                               ██    ██    ██
                                           ████    ██  ██    ████
                                       ████      ██      ██      ████
                                    ███        ██  ██████  ██        ███
                                   ██        ██              ██        ██
                                  ██       ██    ██      ██    ██       ██
                                 ██      ██    ████████████    ██       ██
                                 ██    ██    ██   ████████  ██    ██    ██
                                 ██  ██    ██      ██████      ██   ██  ██
                                  ████   ██    ██████████████    ██  ████
                                   ██  ██    ████  ████████  ████   ██  ██
                                   ██████  ██  ██████    ██████  ██  ██████
                                    ████ ██  █████  ██████  █████  ██  ████
                                     ██████ ██ ██████    ██████ ██ ████████
                                      ████████  ████  ██  ████  ████████
                                        ████████████████████████████████
                                           ██████████████████████████
                                               ██    ██████    ██
                                              ████  ████████  ████
                                             ██  ████  ██  ████  ██
                                            ██  ██  ████████  ██  ██
                                           ████████████    ████████████

       ██████╗ ███████╗██╗   ██╗██╗██╗         ███╗   ███╗ █████╗ ██╗   ██╗     ██████╗██████╗ ██╗   ██╗
       ██╔══██╗██╔════╝██║   ██║██║██║         ████╗ ████║██╔══██╗╚██╗ ██╔╝    ██╔════╝██╔══██╗╚██╗ ██╔╝
       ██║  ██║█████╗  ██║   ██║██║██║         ██╔████╔██║███████║ ╚████╔╝     ██║     ██████╔╝ ╚████╔╝
       ██║  ██║██╔══╝  ╚██╗ ██╔╝██║██║         ██║╚██╔╝██║██╔══██║  ╚██╔╝      ██║     ██╔══██╗  ╚██╔╝
       ██████╔╝███████╗ ╚████╔╝ ██║███████╗    ██║ ╚═╝ ██║██║  ██║   ██║       ╚██████╗██║  ██║   ██║
       ╚═════╝ ╚══════╝  ╚═══╝  ╚═╝╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝        ╚═════╝╚═╝  ╚═╝   ╚═╝
]],
		title = "DEVIL MAY CRY 5  —  SON OF SPARDA",
		hl = "DMCRed",
	},

	-- ✦ VERGIL — Son of Sparda
	{
		art = [[

                                   ████████████████
                                 ████              ████
                               ████    ██████████    ████
                             ████    ██████  ██████    ████
                           ████    ██████      ██████    ████
                         ████    ██████    ██    ██████    ████
                       ████    ██████    ██████    ██████    ████
                      ████   ██████    ████████████  ██████   ████
                     ████  ██████    ██████  ██  ██████  ██████  ████
                     ████████████  ██████    ██    ██████  ████████████
                     ████████████████████  ████  ████████████████████████
                       ████████████████████████████████████████████████
                        ████████████████████████████████████████████
                          ████████████  ████████████  ████████████
                            ████████  ████  ████  ████  ████████
                             ████████████  ██████  ████████████
                              ████  ████████████████████  ████
                               ██  ██  ████████████████  ██  ██
                                ████████████████████████████
                                  ████████████████████████
                                    ████████████████████
                                      ████████████████
                                        ████████████
                                          ████████
                                            ████

               ██╗   ██╗███████╗██████╗  ██████╗ ██╗██╗
               ██║   ██║██╔════╝██╔══██╗██╔════╝ ██║██║
               ██║   ██║█████╗  ██████╔╝██║  ███╗██║██║
               ╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██║██║
                ╚████╔╝ ███████╗██║  ██║╚██████╔╝██║███████╗
                 ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝╚══════╝
]],
		title = "VERGIL  —  POWER IS EVERYTHING",
		hl = "VirgilBlue",
	},

	-- ✦ NARUTO — Nine-Tails Spiral Seal
	{
		art = [[

                             ░░░░░░░░░░░░░░░░░░░░░
                         ░░░░                     ░░░░
                       ░░░    ▄▄▄             ▄▄▄    ░░░
                     ░░░    ▄██▀▀▄           ▄▀▀██▄    ░░░
                    ░░    ▄██▀  ░░░▄       ▄░░░  ▀██▄    ░░
                   ░░   ▄██▀    ░░░░░▄   ▄░░░░░    ▀██▄   ░░
                  ░░   ██▀      ░░░░░░░▄░░░░░░░      ▀██   ░░
                 ░░   ██        ░░░░░░░░░░░░░░░        ██   ░░
                 ░░  ██         ░░░░░░░░░░░░░░░         ██  ░░
                ░░   ██    ██████░░░░░░░░░░░░░██████    ██   ░░
                ░░   ██  ██▀▀▀▀██░░░░░░░░░░░░██▀▀▀▀██  ██   ░░
                ░░   ██  ██    ██░░░░░░░░░░░░██    ██  ██   ░░
                ░░   ██  ██    ██░░▄████████▄░░██    ██  ██   ░░
                 ░░  ██  ██████░░░██░░░░░░░██░░░██████  ██  ░░
                 ░░   ██        ░░░█░░░░░░░█░░░        ██   ░░
                  ░░   ██▄      ░░░█████████░░░      ▄██   ░░
                   ░░   ▀██▄     ░░░░░░░░░░░░░     ▄██▀   ░░
                    ░░    ▀██▄    ░░░░░░░░░░░░    ▄██▀    ░░
                     ░░░    ▀██▄▄░░░░░░░░░░░░░░▄▄██▀    ░░░
                       ░░░    ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀    ░░░
                         ░░░░                         ░░░░
                             ░░░░░░░░░░░░░░░░░░░░░░░░

        ███╗   ██╗ █████╗ ██████╗ ██╗   ██╗████████╗ ██████╗
        ████╗  ██║██╔══██╗██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗
        ██╔██╗ ██║███████║██████╔╝██║   ██║   ██║   ██║   ██║
        ██║╚██╗██║██╔══██║██╔══██╗██║   ██║   ██║   ██║   ██║
        ██║ ╚████║██║  ██║██║  ██║╚██████╔╝   ██║   ╚██████╔╝
        ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝
]],
		title = "NARUTO UZUMAKI  —  THE 7TH HOKAGE",
		hl = "NarutoOrange",
	},

	-- ✦ ATTACK ON TITAN — Wings of Freedom
	{
		art = [[

                               ▄▄▄▄▄
                              █ ▄▄▄ █
                             █ █   █ █
                            █  █   █  █
                           █   █   █   █
                          █    █   █    █
                         █    ███████    █
                        █   ██       ██   █
                       █  ██     ▄     ██  █
                      █ ██     ▄████▄    ██ █
                     █ ██    ████████████ ██ █
                    █ ██    █ ████████████ ██ █
                   █ ██    █  █████████████ ██ █
                  █  ██   █   ████   █████  ██  █
                 █   ██  █    ████   █████   ██   █
                █    ██ █     ████   █████    ██    █
               █      ██      ████   ████      ██     █
              █        ██     █████  ████       ██      █
             █          ██     ██████████        ██       █
            █            ██     ████████          ██       █
           █              ████████████████         ████     █
          █                 ██████████                ████  █

      █████╗ ████████╗████████╗ █████╗  ██████╗██╗  ██╗     ██████╗ ███╗   ██╗
     ██╔══██╗╚══██╔══╝╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝    ██╔═══██╗████╗  ██║
     ███████║   ██║      ██║   ███████║██║     █████╔╝     ██║   ██║██╔██╗ ██║
     ██╔══██║   ██║      ██║   ██╔══██║██║     ██╔═██╗     ██║   ██║██║╚██╗██║
     ██║  ██║   ██║      ██║   ██║  ██║╚██████╗██║  ██╗    ╚██████╔╝██║ ╚████║
     ╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝     ╚═════╝ ╚═╝  ╚═══╝
]],
		title = "ATTACK ON TITAN  —  SHINZOU WO SASAGEYO",
		hl = "AoTGreen",
	},

	-- ✦ DEMON SLAYER — Tanjiro
	{
		art = [[

                                 ▄████████▄
                              ▄████████████████▄
                            ▄████▀          ▀████▄
                           ████▀              ▀████
                          ████                  ████
                         ████     ░░░░░░░░░░     ████
                        █████   ░░░░░░░░░░░░░   █████
                        █████   ░░░░░░░░░░░░░   █████
                         ████   ░░░░░▄▄▄░░░░░   ████
                         ████   ░░░░█████░░░░   ████
                          ████  ░░░░░▀▀▀░░░░  ████
                           ████  ░░░░░░░░░░  ████
                            ████▄          ▄████
                              ████████████████
                                ████████████
                             ▄████████████████▄
                           ████▀              ▀████
                          ████    ██████████    ████
                         ████   ████████████████  ████
                        ████   ██████      ██████  ████
                       ████████████            ████████████
                         ████████                ████████

    ██████╗ ███████╗███╗   ███╗ ██████╗ ███╗   ██╗    ███████╗██╗      █████╗ ██╗   ██╗███████╗██████╗
    ██╔══██╗██╔════╝████╗ ████║██╔═══██╗████╗  ██║    ██╔════╝██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗
    ██║  ██║█████╗  ██╔████╔██║██║   ██║██╔██╗ ██║    ███████╗██║     ███████║ ╚████╔╝ █████╗  ██████╔╝
    ██║  ██║██╔══╝  ██║╚██╔╝██║██║   ██║██║╚██╗██║    ╚════██║██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗
    ██████╔╝███████╗██║ ╚═╝ ██║╚██████╔╝██║ ╚████║    ███████║███████╗██║  ██║   ██║   ███████╗██║  ██║
    ╚═════╝ ╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝    ╚══════╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
]],
		title = "DEMON SLAYER  —  KAMADO TANJIRO",
		hl = "DemonSlayerRed",
	},

	-- ✦ DARK SOULS — Bonfire
	{
		art = [[

                                      ████
                                    ████████
                                  ████  ██████
                                ████  ██  ██████
                              ██████████████████
                             ████████████████████
                              ██████████████████
                               ████████████████
                            ██████████████████████
                          ██████████████████████████
                         ████████████████████████████
                        ██████████████████████████████
                          ██████████████████████████
                            ████████████████████████
                              ████████████████████
                                ████████████████
                                  ████████████
                           ████████████████████████
                        ████████████████████████████████
                      ████████████████████████████████████
                    ████████████████████████████████████████

       ██████╗  █████╗ ██████╗ ██╗  ██╗    ███████╗ ██████╗ ██╗   ██╗██╗     ███████╗
       ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝    ██╔════╝██╔═══██╗██║   ██║██║     ██╔════╝
       ██║  ██║███████║██████╔╝█████╔╝     ███████╗██║   ██║██║   ██║██║     ███████╗
       ██║  ██║██╔══██║██╔══██╗██╔═██╗     ╚════██║██║   ██║██║   ██║██║     ╚════██║
       ██████╔╝██║  ██║██║  ██║██║  ██╗    ███████║╚██████╔╝╚██████╔╝███████╗███████║
       ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
]],
		title = "DARK SOULS  —  PRAISE THE SUN  \\o/",
		hl = "DarkSoulsGold",
	},

	-- ✦ ONE PIECE — Jolly Roger
	{
		art = [[

                             ████████████████████
                         ████▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀████
                       ████                          ████
                      ████   ████████████████████     ████
                     ████   ██                  ██     ████
                    ████   ██                    ██     ████
                    ████  ██   ████      ████    ██     ████
                    ████  ██  ██████    ██████   ██     ████
                    ████  ██  ██████    ██████   ██     ████
                    ████  ██   ████      ████    ██     ████
                    ████   ██                    ██     ████
                     ████   ██      ████        ██     ████
                      ████   ██    ██████      ██     ████
                       ████   ██████████████████    ████
                        ████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄████
                        ████████████████████████████████████████████
                       ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████
                                 ████████████████████████

     ██████╗ ███╗   ██╗███████╗    ██████╗ ██╗███████╗ ██████╗███████╗
    ██╔═══██╗████╗  ██║██╔════╝    ██╔══██╗██║██╔════╝██╔════╝██╔════╝
    ██║   ██║██╔██╗ ██║█████╗      ██████╔╝██║█████╗  ██║     █████╗
    ██║   ██║██║╚██╗██║██╔══╝      ██╔═══╝ ██║██╔══╝  ██║     ██╔══╝
    ╚██████╔╝██║ ╚████║███████╗    ██║     ██║███████╗╚██████╗███████╗
     ╚═════╝ ╚═╝  ╚═══╝╚══════╝    ╚═╝     ╚═╝╚══════╝ ╚═════╝╚══════╝
]],
		title = "ONE PIECE  —  KING OF THE PIRATES",
		hl = "OnePieceYellow",
	},

	-- ✦ GOD OF WAR — Omega / Kratos
	{
		art = [[

                            ▄▄█████████████████▄▄
                         ▄███▀▀                 ▀▀███▄
                       ▄██▀    ▄███████████████▄    ▀██▄
                      ██▀    ▄██▀▀           ▀▀██▄    ▀██
                     ██    ▄██▀    ▄███████▄    ▀██▄    ██
                    ██   ▄██▀    ▄██▀     ▀██▄    ▀██▄   ██
                    ██   ██    ▄██▀         ▀██▄    ██   ██
                    ██   ██   ██▀  ▄███████▄  ▀██   ██   ██
                    ██   ██   ██   ███████████  ██   ██   ██
                    ██   ██   ██   ███████████  ██   ██   ██
                    ██   ██   ██▄  ▀███████▀  ▄██   ██   ██
                    ██   ██    ▀██▄         ▄██▀    ██   ██
                    ██   ▀██▄    ▀██▄     ▄██▀    ▄██▀   ██
                     ██    ▀██▄    ▀███████▀    ▄██▀    ██
                      ██▄    ▀██▄▄           ▄▄██▀    ▄██
                       ▀██▄    ▀███████████████▀    ▄██▀
                         ▀███▄▄                 ▄▄███▀
                            ▀▀█████████████████▀▀

       ██████╗  ██████╗ ██████╗     ██████╗ ███████╗    ██╗    ██╗ █████╗ ██████╗
      ██╔════╝ ██╔═══██╗██╔══██╗   ██╔═══██╗██╔════╝    ██║    ██║██╔══██╗██╔══██╗
      ██║  ███╗██║   ██║██║  ██║   ██║   ██║█████╗      ██║ █╗ ██║███████║██████╔╝
      ██║   ██║██║   ██║██║  ██║   ██║   ██║██╔══╝      ██║███╗██║██╔══██║██╔══██╗
      ╚██████╔╝╚██████╔╝██████╔╝   ╚██████╔╝██║         ╚███╔███╔╝██║  ██║██║  ██║
       ╚═════╝  ╚═════╝ ╚═════╝     ╚═════╝ ╚═╝          ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝
]],
		title = "GOD OF WAR  —  GHOST OF SPARTA",
		hl = "KratosRed",
	},

	-- ✦ CYBERPUNK 2077 — Samurai
	{
		art = [[

                         ▄████████████████████████▄
                       ▄██▀▀                      ▀▀██▄
                      ██▀   ▄████████████████████▄   ▀██
                     ██   ▄██▀                  ▀██▄   ██
                    ██   ██   ▄████████████████▄   ██   ██
                    ██   ██  ██▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀██  ██   ██
                    ██   ██  ██  ▄▄▄▄▄▄▄▄▄▄▄▄  ██  ██   ██
                    ██   ██  ██  ██▀▀▀▀▀▀▀▀▀▀  ██  ██   ██
                    ██   ██  ██  ██   ▄████▄    ██  ██   ██
                    ██   ██  ██  ██  ████████   ██  ██   ██
                    ██   ██  ██  ██   ▀████▀    ██  ██   ██
                    ██   ██  ██  ██▄▄▄▄▄▄▄▄▄▄  ██  ██   ██
                    ██   ██  ██▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄██  ██   ██
                    ██   ██   ▀████████████████▀   ██   ██
                     ██   ▀██▄                  ▄██▀   ██
                      ██▄   ▀████████████████████▀   ▄██
                       ▀██▄▄                      ▄▄██▀
                         ▀████████████████████████▀

      ██████╗██╗   ██╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗███╗   ██╗██╗  ██╗
     ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗██╔══██╗██║   ██║████╗  ██║██║ ██╔╝
     ██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝██████╔╝██║   ██║██╔██╗ ██║█████╔╝
     ██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗██╔═══╝ ██║   ██║██║╚██╗██║██╔═██╗
     ╚██████╗   ██║   ██████╔╝███████╗██║  ██║██║     ╚██████╔╝██║ ╚████║██║  ██╗
      ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝
]],
		title = "CYBERPUNK 2077  —  WAKE UP SAMURAI",
		hl = "CyberpunkYellow",
	},
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  QUOTES — organised by franchise with character attribution
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local quotes = {
	-- DEVIL MAY CRY
	{
		text = "Jackpot!",
		src = "Dante — Devil May Cry",
	},
	{
		text = "I'm a devil hunter. It's what I do. Saving people, killing demons.",
		src = "Dante — Devil May Cry 5",
	},
	{
		text = "Might controls everything. And without strength, you cannot protect anything. Let alone yourself.",
		src = "Vergil — Devil May Cry 3",
	},
	{
		text = "Nothing is impossible for a son of Sparda.",
		src = "Vergil — Devil May Cry 5",
	},
	{
		text = "I need more power!",
		src = "Vergil — Devil May Cry 5",
	},
	{
		text = "Vergil... you're such a dumbass.",
		src = "Dante — Devil May Cry 5",
	},
	{
		text = "Subduing power with power... that's what it means to be a demon king!",
		src = "Nero — Devil May Cry 5",
	},
	{
		text = "I should have been the one to fill your dark soul with LIGHT!",
		src = "Dante — Devil May Cry",
	},
	{
		text = "Stay out of trouble... son.",
		src = "Vergil — Devil May Cry 5",
	},
	{
		text = "This is what you always wanted, right? A chance to see who's stronger.",
		src = "Nero — Devil May Cry 5",
	},
	{
		text = "The power of the Yamato is in my veins now. V... you and I are one.",
		src = "Vergil — Devil May Cry 5",
	},

	-- NARUTO
	{
		text = "I'm not gonna run away, I never go back on my word! That's my nindo: my ninja way!",
		src = "Naruto Uzumaki",
	},
	{
		text = "When people get hurt, they learn to hate. When people hurt others, they become hated. But knowing that pain allows people to be kind.",
		src = "Nagato — Naruto",
	},
	{
		text = "The true measure of a shinobi is not how he lives, but how he dies.",
		src = "Jiraiya — Naruto",
	},
	{
		text = "Those who break the rules are scum, but those who abandon their comrades are worse than scum.",
		src = "Kakashi Hatake — Naruto",
	},
	{
		text = "I will become Hokage. That's my dream and I'll never give up on it!",
		src = "Naruto Uzumaki",
	},

	-- ATTACK ON TITAN
	{
		text = "If you win, you live. If you lose, you die. If you don't fight, you can't win!",
		src = "Eren Yeager — Attack on Titan",
	},
	{
		text = "Dedicate your heart! Shinzou wo Sasageyo!",
		src = "Erwin Smith — Attack on Titan",
	},
	{
		text = "The world is cruel. But also very beautiful.",
		src = "Mikasa Ackerman — Attack on Titan",
	},
	{
		text = "I want to see and understand the world outside. I don't want to die inside these walls.",
		src = "Eren Yeager — Attack on Titan",
	},

	-- DEMON SLAYER
	{
		text = "No matter how many people you may lose, you have no choice but to go on living.",
		src = "Tanjiro Kamado — Demon Slayer",
	},
	{
		text = "All I have to do is not give up. I can do it. I can do it!",
		src = "Tanjiro Kamado — Demon Slayer",
	},
	{
		text = "Set your heart ablaze.",
		src = "Rengoku Kyojuro — Demon Slayer",
	},
	{
		text = "Grow stronger. By any means necessary.",
		src = "Muzan Kibutsuji — Demon Slayer",
	},

	-- ONE PIECE
	{
		text = "I'm going to be the King of the Pirates!",
		src = "Monkey D. Luffy — One Piece",
	},
	{
		text = "Power isn't determined by your size, but the size of your heart and dreams!",
		src = "Monkey D. Luffy — One Piece",
	},
	{
		text = "Nothing happened.",
		src = "Roronoa Zoro — One Piece",
	},
	{
		text = "If you die, I'll kill you.",
		src = "Roronoa Zoro — One Piece",
	},

	-- DARK SOULS
	{
		text = "Praise the Sun! \\o/",
		src = "Solaire of Astora — Dark Souls",
	},
	{
		text = "Bearer of the curse... seek misery.",
		src = "Dark Souls II",
	},
	{
		text = "Don't give up, skeleton!",
		src = "Patches — Dark Souls",
	},
	{
		text = "You Died.",
		src = "Dark Souls",
	},

	-- GOD OF WAR
	{
		text = "BOY!",
		src = "Kratos — God of War",
	},
	{
		text = "The cycle ends here. We must be better than this.",
		src = "Kratos — God of War",
	},
	{
		text = "Do not be sorry. Be better.",
		src = "Kratos — God of War",
	},
	{
		text = "Monsters do not walk these lands. Only gods who have forgotten who they are.",
		src = "Kratos — God of War: Ragnarok",
	},

	-- CYBERPUNK 2077
	{
		text = "Wake the f*** up, Samurai. We have a city to burn.",
		src = "Johnny Silverhand — Cyberpunk 2077",
	},
	{
		text = "Corpo, street kid, or nomad — doesn't matter where you start. Only matters where you end.",
		src = "Cyberpunk 2077",
	},

	-- CLASSIC GAMING
	{
		text = "War. War never changes.",
		src = "Fallout",
	},
	{
		text = "A man chooses. A slave obeys.",
		src = "Andrew Ryan — BioShock",
	},
	{
		text = "The right man in the wrong place can make all the difference in the world.",
		src = "G-Man — Half-Life 2",
	},
	{
		text = "Had to be me. Someone else might have gotten it wrong.",
		src = "Mordin Solus — Mass Effect 3",
	},
	{
		text = "Evil is evil. Lesser, greater, middling — makes no difference.",
		src = "Geralt of Rivia — The Witcher 3",
	},
	{
		text = "Rip and tear, until it is done.",
		src = "Doom Eternal",
	},
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  HIGHLIGHT GROUPS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function set_highlights()
	-- logo-specific
	vim.api.nvim_set_hl(0, "DMCRed", { fg = "#FF2233", bold = true })
	vim.api.nvim_set_hl(0, "VirgilBlue", { fg = "#4FC3F7", bold = true })
	vim.api.nvim_set_hl(0, "NarutoOrange", { fg = "#FF7043", bold = true })
	vim.api.nvim_set_hl(0, "AoTGreen", { fg = "#66BB6A", bold = true })
	vim.api.nvim_set_hl(0, "DemonSlayerRed", { fg = "#EF5350", bold = true })
	vim.api.nvim_set_hl(0, "DarkSoulsGold", { fg = "#FFD54F", bold = true })
	vim.api.nvim_set_hl(0, "OnePieceYellow", { fg = "#FFCA28", bold = true })
	vim.api.nvim_set_hl(0, "CyberpunkYellow", { fg = "#F9E000", bold = true })
	vim.api.nvim_set_hl(0, "KratosRed", { fg = "#B71C1C", bold = true })
	-- shared elements
	vim.api.nvim_set_hl(0, "DashTitle", { fg = "#C792EA", bold = true, italic = true })
	vim.api.nvim_set_hl(0, "DashButton", { fg = "#82AAFF", bold = true })
	vim.api.nvim_set_hl(0, "DashShortcut", { fg = "#FF2233", bold = true })
	vim.api.nvim_set_hl(0, "DashFooter", { fg = "#546E7A", italic = true })
	vim.api.nvim_set_hl(0, "DashQuote", { fg = "#A6DA95", italic = true })
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  FORMAT HELPERS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function format_title(title)
	local w = #title + 6
	local bar = string.rep("═", w)
	return string.format("\n  ╔%s╗\n  ║   %s   ║\n  ╚%s╝\n", bar, title, bar)
end

local function format_quote(q)
	local rule =
		"  ──────────────────────────────────────────────────────────────────"
	return string.format("%s\n  ❝  %s\n     ─── %s\n%s", rule, q.text, q.src, rule)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  SETUP
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function M.setup()
	local alpha_ok, alpha = pcall(require, "alpha")
	if not alpha_ok then
		vim.notify("[dashboard] alpha-nvim not found — run :Lazy sync", vim.log.levels.WARN)
		return
	end

	local dashboard = require("alpha.themes.dashboard")

	math.randomseed(os.time())

	local logo = logos[math.random(#logos)]
	local q = quotes[math.random(#quotes)]

	-- ── header
	local header_text = logo.art .. format_title(logo.title)
	dashboard.section.header.val = vim.split(header_text, "\n")
	dashboard.section.header.opts.hl = logo.hl or "DashTitle"

	-- ── buttons
	dashboard.section.buttons.val = {
		dashboard.button("SPC f f", "󰍉  Find File", "<cmd>Telescope find_files<CR>"),
		dashboard.button("SPC f r", "  Recent Files", "<cmd>Telescope oldfiles<CR>"),
		dashboard.button("SPC f g", "  Live Grep", "<cmd>Telescope live_grep<CR>"),
		dashboard.button("SPC f b", "  Buffers", "<cmd>Telescope buffers<CR>"),
		dashboard.button("SPC g s", "  Git Status", "<cmd>Telescope git_status<CR>"),
		dashboard.button("SPC l  ", "  LSP Info", "<cmd>LspInfo<CR>"),
		dashboard.button("SPC s s", "  Sessions", "<cmd>lua require('persistence').load()<CR>"),
		dashboard.button("n      ", "  New File", "<cmd>ene <BAR> startinsert<CR>"),
		dashboard.button("c      ", "  Neovim Config", "<cmd>e ~/.config/nvim/init.lua<CR>"),
		dashboard.button("l      ", "󰒲  Lazy", "<cmd>Lazy<CR>"),
		dashboard.button("m      ", "  Mason", "<cmd>Mason<CR>"),
		dashboard.button("q      ", "  Quit", "<cmd>qa<CR>"),
	}
	dashboard.section.buttons.opts.hl = "DashButton"
	dashboard.section.buttons.opts.hl_shortcut = "DashShortcut"

	-- ── footer / quote
	dashboard.section.footer.val = vim.split(format_quote(q), "\n")
	dashboard.section.footer.opts.hl = "DashQuote"

	-- ── layout
	dashboard.opts.layout = {
		{ type = "padding", val = 1 },
		dashboard.section.header,
		{ type = "padding", val = 1 },
		dashboard.section.buttons,
		{ type = "padding", val = 1 },
		dashboard.section.footer,
		{ type = "padding", val = 1 },
	}

	set_highlights()
	alpha.setup(dashboard.opts)

	-- clean alpha buffer
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "alpha",
		callback = function()
			vim.opt_local.foldenable = false
			vim.opt_local.number = false
			vim.opt_local.relativenumber = false
			vim.opt_local.signcolumn = "no"
			vim.opt_local.cursorline = false
			vim.opt_local.statusline = " "
			vim.opt_local.list = false
		end,
	})
end

return M
