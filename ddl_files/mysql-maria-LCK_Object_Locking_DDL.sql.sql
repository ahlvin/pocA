-- -------------------------------

DROP TABLE IF EXISTS `LCK_OBJECT_LOCK`;

CREATE TABLE `LCK_OBJECT_LOCK` (
  `OBJECT_KEY` varchar(551) NOT NULL,	-- PK, used for unique constraint locking. SPs concatenate this from ID and Type.
  `OBJECT_ID` varchar(50) NOT NULL,		-- for info and look up if required (also first part of object key)
  `OBJECT_TYPE` varchar(500) NOT NULL,	-- for info and look up if required (also second part of object key)
  `PROCESS_ID` int(11) NOT NULL,		-- process id of process taking the lock
  `USERNAME` varchar(255) DEFAULT NULL,	-- user running the process taking the lock
  `TIMESTAMP` datetime DEFAULT NULL,	-- timestamp when lock was taken
  PRIMARY KEY (`OBJECT_KEY`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



-- -------------------------------

DROP PROCEDURE IF EXISTS `LCK_SP_GET_OBJECT_LOCK`;


DELIMITER $$

CREATE PROCEDURE `LCK_SP_GET_OBJECT_LOCK` (
	IN `p_objectId` VARCHAR(50),
	IN `p_objectType` VARCHAR(500),
	IN `p_processId` INT(11),
	IN `p_username` VARCHAR(255),
	OUT `p_lockSuccessful` TINYINT(1),
	OUT `p_lockProcessId` INT(11),
	OUT `p_lockedBy` VARCHAR(255)
)

BEGIN

	-- Create object key
	DECLARE objectKey VARCHAR(551) default concat(ifnull(p_objectId, ''), '|', ifnull(p_objectType, ''));

	-- Declare exit handler for duplicate primary key
	DECLARE EXIT HANDLER FOR 1062
	BEGIN
		ROLLBACK;

		-- If duplicate primary key, return locked false and user with lock
		set p_lockSuccessful := false;

		-- Find out who actually holds the lock
		select PROCESS_ID, USERNAME
		into p_lockProcessId, p_lockedBy
		from LCK_OBJECT_LOCK
		where OBJECT_KEY = objectKey;
	END;

	START TRANSACTION;

		-- Try to get lock
		 insert into LCK_OBJECT_LOCK (OBJECT_KEY, OBJECT_ID, OBJECT_TYPE, PROCESS_ID, USERNAME, TIMESTAMP)
		 values (objectKey, p_objectId, p_objectType, p_processId, p_username, now());

	COMMIT;

	-- Set locked to true
	set p_lockSuccessful := true;
	-- Set lock process Id to make it easy for caller to save this for later
	set p_lockProcessId := p_processId;

END$$


DELIMITER ;

DROP PROCEDURE IF EXISTS `LCK_SP_RELEASE_OBJECT_LOCK`;


DELIMITER $$

CREATE PROCEDURE `LCK_SP_RELEASE_OBJECT_LOCK` (
	IN `p_objectId` VARCHAR(50),
	IN `p_objectType` VARCHAR(500),
  OUT `p_releaseSuccessful` TINYINT(1)
)

BEGIN

	-- Create object key
	DECLARE objectKey VARCHAR(551) default concat(ifnull(p_objectId, ''), '|', ifnull(p_objectType, ''));

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
    SET p_releaseSuccessful := false;
	END;

	START TRANSACTION;

		-- Release lock
		 delete from LCK_OBJECT_LOCK
		 where OBJECT_KEY = objectKey;

	COMMIT;

  SET p_releaseSuccessful := true;

END$$

DELIMITER ;


-- -------------------------------
