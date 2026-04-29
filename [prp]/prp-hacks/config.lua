Config = {}

-- Admin test commands. Uses ACE permission: prp-hacks.admin
-- Add this to server.cfg for admins:
-- add_ace group.admin prp-hacks.admin allow
Config.AdminCommands = {
    enabled = true,
    tetris = 'testtetris',
    flappy = 'testflappy',
    crossy = 'testcrossy',
    memory = 'testmemory',
    typing = 'testtyping',
    random = 'testrandomhack',
    any = 'testhack'
}

Config.Defaults = {
    tetris = {
        targetScore = 1000,
        timeLimit = 120,
        loadingTime = 3200,
        title = 'TETRIS HACK'
    },
    flappy = {
        targetScore = 20,
        timeLimit = 90,
        loadingTime = 3200,
        title = 'FLAPPY HACK'
    },
    crossy = {
        targetScore = 20,
        timeLimit = 90,
        loadingTime = 3200,
        title = 'CROSSY ROADS HACK'
    },
    memory = {
        difficulty = 'easy',
        targetScore = 8,
        timeLimit = 30,
        loadingTime = 3200,
        title = 'MEMORY MATCH HACK'
    },
    typing = {
        difficulty = 'medium',
        timeLimit = 60,
        loadingTime = 3200,
        title = 'CODE TYPE HACK'
    }
}

Config.Memory = {
    easy = { tiles = 8, timeLimit = 30 },
    medium = { tiles = 16, timeLimit = 60 },
    hard = { tiles = 24, timeLimit = 120 }
}

-- Typing still has easy/medium/hard, but the actual code is random every start.
Config.Typing = {
    easy = { lines = 3, minLen = 12, maxLen = 18, maxErrors = 5, timeLimit = 45 },
    medium = { lines = 4, minLen = 16, maxLen = 26, maxErrors = 3, timeLimit = 60 },
    hard = { lines = 5, minLen = 22, maxLen = 34, maxErrors = 2, timeLimit = 75 }
}

-- Random hack pool used by StartRandomHack() and /testrandomhack.
Config.RandomHack = {
    games = { 'tetris', 'flappy', 'crossy', 'memory', 'typing' },
    difficulties = { 'easy', 'medium', 'hard' },
    randomDifficulty = true
}

Config.Banners = {
    success = 'Hack Completed',
    failed = 'Hack Failed'
}
