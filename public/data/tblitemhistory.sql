-- --------------------------------------------------------
-- Host:                         localhost
-- Server version:               5.5.10 - MySQL Community Server (GPL)
-- Server OS:                    Win32
-- HeidiSQL Version:             8.0.0.4396
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- Dumping structure for event invndccdo.ev_invhistory
DROP EVENT IF EXISTS `ev_invhistory`;
DELIMITER //
CREATE DEFINER=`ndccdo`@`192.168.1.101` EVENT `ev_invhistory` ON SCHEDULE EVERY 1 DAY STARTS '2015-09-12 02:00:00' ON COMPLETION PRESERVE ENABLE COMMENT 'rund every day' DO BEGIN
	TRUNCATE TABLE tblitemhistory;
	call sp_invhistory('');
END//
DELIMITER ;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
