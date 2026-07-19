CREATE TABLE IF NOT EXISTS `prp_vehicle_upgrades` (
  `plate` varchar(20) NOT NULL,
  `airbags` tinyint(1) NOT NULL DEFAULT 0,
  `stancer` tinyint(1) NOT NULL DEFAULT 0,
  `hydraulics` tinyint(1) NOT NULL DEFAULT 0,
  `airbags_down` tinyint(1) NOT NULL DEFAULT 0,
  `stance_data` longtext DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Existing v1 installations only:
-- ALTER TABLE `prp_vehicle_upgrades` ADD COLUMN `airbags_down` tinyint(1) NOT NULL DEFAULT 0 AFTER `hydraulics`;
