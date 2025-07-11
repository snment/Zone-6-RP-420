CREATE TABLE IF NOT EXISTS `interaction_points` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `x` float NOT NULL,
    `y` float NOT NULL,
    `z` float NOT NULL,
    `item` varchar(50) NOT NULL,
    `amount` int(11) NOT NULL DEFAULT 1,
    `radius` float NOT NULL DEFAULT 2.0,
    `blipSprite` int(11) NOT NULL DEFAULT 478,
    `blipColor` int(11) NOT NULL DEFAULT 2,
    `blipScale` float NOT NULL DEFAULT 0.8,
    `blipName` varchar(50) NOT NULL DEFAULT 'Interaction Point',
    `duration` int(11) NOT NULL DEFAULT 0,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;