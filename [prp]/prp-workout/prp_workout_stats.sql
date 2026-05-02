CREATE TABLE IF NOT EXISTS `prp_workout_stats` (
    `citizenid` varchar(50) NOT NULL,
    `strength` int(11) NOT NULL DEFAULT 0,
    `stamina` int(11) NOT NULL DEFAULT 0,
    `endurance` int(11) NOT NULL DEFAULT 0,
    `activity_count` int(11) NOT NULL DEFAULT 0,
    `activity_reset` int(11) NOT NULL DEFAULT 0,
    `last_decay` int(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
