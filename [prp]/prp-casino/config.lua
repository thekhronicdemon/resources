Config = {}

Config.Debug = false

Config.BlackjackTableHash = -2126678982

Config.UseCasinoChips = false
Config.ChipItem = 'casino_chip'

Config.MinBet = 100
Config.MaxBet = 5000

Config.Betting = {
    phaseSeconds = 15,
    step = 100
}

Config.Controls = {
    betUp = 172,
    betDown = 173,
    betMin = 174,
    betMax = 175,
    placeBet = 176,
    leave = 177,
    hit = 38,
    stand = 47
}

Config.Anims = {
    sharedPlayer = 'anim_casino_b@amb@casino@games@shared@player@',
    blackjackPlayer = 'anim_casino_b@amb@casino@games@blackjack@player',
    sharedDealer = 'anim_casino_b@amb@casino@games@shared@dealer@',
    blackjackDealer = 'anim_casino_b@amb@casino@games@blackjack@dealer'
}

Config.Player = {
    seatIndex = 1,
    seatScenario = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER',
    enterClip = 'sit_enter_left',
    exitClip = 'sit_exit_left',
    idleClip = 'idle_cardgames',
    betClip = 'place_bet_small',
    hitClip = 'request_card',
    standClip = 'decline_card_001',
    winClip = 'reaction_pleased',
    loseClip = 'reaction_terrible',
    pushClip = 'reaction_impatient_001'
}

Config.Timing = {
    placeBetAnimMs = 1200,
    hitAnimMs = 900,
    standAnimMs = 950,
    resultAnimMs = 1600,
    resultPauseMs = 1800,
    cleanupStepMs = 220
}

Config.Tables = {
        [1] = {
        tableHash = -2126678982,
        tableCoords = vector3(1015.58, 47.49, 72.28),
        tableHeading = 103.3,

        dealer = {
            model = `s_f_y_casino_01`,
            coords = vector4(1014.78, 47.25, 73.28, 280.45),
            handBone = 28422,
            handOffset = vector3(0.0, 0.0, 0.0)
        },

        seats = {
            [1] = {
                coords = vector4(1015.18, 48.60, 72.75, 177.6),
                seatNumber = 1
            }
        }, 
        layout = {
            playerCards = {
                factor = 0.50,
                spreadStep = 0.042,
                z = 0.964,
                sideOffset = -0.25
            },
            dealerCards = {
                factor = 0.75,
                spreadStep = 0.048,
                z = 0.964
            },
            chips = {
                factor = 0.37,
                z = 0.958,
                perRow = 3,
                stepSide = 0.032,
                stepForward = 0.026,
                stackLift = 0.011
            }
        }
    }
}

Config.Props = {
    hiddenCard = 'vw_prop_casino_cards_single',
    fallbackCard = 'vw_prop_casino_cards_01',
    chipModels = {
        { value = 50000, model = 'vw_prop_plaq_50kdollar_x1' },
        { value = 10000, model = 'vw_prop_plaq_10kdollar_x1' },
        { value = 5000, model = 'vw_prop_plaq_5kdollar_x1' },
        { value = 1000, model = 'vw_prop_plaq_1kdollar_x1' },
        { value = 500, model = 'vw_prop_chip_500dollar_x1' },
        { value = 100, model = 'vw_prop_chip_100dollar_x1' },
        { value = 50, model = 'vw_prop_chip_50dollar_x1' }
    },
    cardPitch = 0.0,
    cardRoll = 0.0
}
