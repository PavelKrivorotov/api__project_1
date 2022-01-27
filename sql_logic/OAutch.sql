

-- 
CREATE FUNCTION START_REGISTRATION(
    EMAIL           USERS_TEMPLATE.EMAIL%TYPE,
    PASSWORD        USERS_TEMPLATE.PASSWORD%TYPE,

    NAME            USERS_TEMPLATE.NAME%TYPE,
    LAST_NAME       USERS_TEMPLATE.LAST_NAME%TYPE,

    TOKEN           USERS_TEMPLATE.TOKEN_ACTIVATE%TYPE
)

RETURNS INTEGER AS

$$
DECLARE

    USER_EMAIL      USERS_TEMPLATE.EMAIL%TYPE;
    TOKEN_TIME      USERS_TEMPLATE.DATE_REGISTRATION%TYPE;

BEGIN

    -- Проверяем нету ли такого пользователя в основной базе
    SELECT  USERS.EMAIL
    INTO    USER_EMAIL
    FROM    USERS
    WHERE   USERS.EMAIL = $1;

    IF USER_EMAIL IS NOT NULL THEN
        RETURN 1300;
    END IF;


    -- Проверяем нет ли такого юзера в users_template.
    SELECT  USERS_TEMPLATE.EMAIL, USERS_TEMPLATE.DATE_REGISTRATION
    INTO    USER_EMAIL, TOKEN_TIME
    FROM    USERS_TEMPLATE
    WHERE   USERS_TEMPLATE.EMAIL = $1;

    IF USER_EMAIL IS NOT NULL THEN
        UPDATE  USERS_TEMPLATE
        SET     TOKEN_ACTIVATE = $5, DATE_REGISTRATION = NOW()
        WHERE   USERS_TEMPLATE.EMAIL = $1;

        RETURN 1301;
    
    ELSE
        -- Добавить пользователя в таблицу, как ожидающего подтверждения почты.
        -- USER_TOKEN = 'YOUR_TOKEN_ACTIVATION';

        INSERT INTO USERS_TEMPLATE (EMAIL, PASSWORD, NAME, LAST_NAME,
            TOKEN_ACTIVATE, DATE_REGISTRATION)
        VALUES      ($1, $2, $3, $4, $5, NOW());

        RETURN 1201;
    
    END IF;

END;
$$

LANGUAGE plpgsql;



-- 
CREATE FUNCTION END_REGISTRATION(
    EMAIL           USERS_TEMPLATE.EMAIL%TYPE,
    TOKEN_ACTIVATE  USERS_TEMPLATE.TOKEN_ACTIVATE%TYPE,

    TOKEN           USERS.TOKEN%TYPE
)

RETURNS INTEGER AS

$$
DECLARE

    USER_PASSWORD   USERS_TEMPLATE.PASSWORD%TYPE;

    USER_NAME       USERS_TEMPLATE.NAME%TYPE;
    USER_LAST_NAME  USERS_TEMPLATE.LAST_NAME%TYPE;
    TOKEN_TIME      USERS_TEMPLATE.DATE_REGISTRATION%TYPE;

    NEW_USER_TOKEN  USERS_TEMPLATE.TOKEN_ACTIVATE%TYPE;

BEGIN

    -- 
    SELECT  USERS_TEMPLATE.PASSWORD, USERS_TEMPLATE.NAME, USERS_TEMPLATE.LAST_NAME,
            USERS_TEMPLATE.DATE_REGISTRATION
    INTO    USER_PASSWORD, USER_NAME, USER_LAST_NAME, TOKEN_TIME
    FROM    USERS_TEMPLATE
    WHERE   USERS_TEMPLATE.EMAIL = $1 AND USERS_TEMPLATE.TOKEN_ACTIVATE = $2;

    IF ( USER_NAME IS NOT NULL AND NOW()::TIMESTAMP(0) WITHOUT TIME ZONE
            - TOKEN_TIME <= '24:00:00' ) THEN
        -- 

        INSERT INTO USERS (EMAIL, PASSWORD, TOKEN, TOKEN_ACTIVATION_DATE)
        VALUES      ($1, USER_PASSWORD, $3, NOW());

        INSERT INTO USERS_INFO (USER_ID, NAME, LAST_NAME)
        VALUES      (LASTVAL(), USER_NAME, USER_LAST_NAME);

        DELETE FROM USERS_TEMPLATE
        WHERE       USERS_TEMPLATE.EMAIL = $1;

        RETURN 1200;
    
    ELSE
        RETURN 1302;
    
    END IF;

END;
$$

LANGUAGE plpgsql;



-- 
CREATE FUNCTION DELETE_USER(
    EMAIL           USERS.EMAIL%TYPE
)

RETURNS INTEGER AS

$$
DECLARE

    USER_USER_ID    USERS_INFO.USER_ID%TYPE;
    USER_STATUS     USERS_INFO.STATUS%TYPE;
    USER_GROUP      USERS_INFO.GROUP_ID%TYPE;

    GROUP_MEMBERS   USERS_GROUPS.MEMBERS%TYPE;

BEGIN

    SELECT  USERS_INFO.USER_ID, USERS_INFO.STATUS, USERS_INFO.GROUP_ID
    INTO    USER_USER_ID, USER_STATUS, USER_GROUP
    FROM    USERS JOIN USERS_INFO
    ON      USERS.USER_ID = USERS_INFO.USER_ID
    WHERE   USERS.EMAIL = $1;

    -- IF USER_USER_ID IS NULL THEN
    --     RETURN 'YOU ARE NOT IN DATABASE';
    -- END IF;


    SELECT  USERS_GROUPS.MEMBERS
    INTO    GROUP_MEMBERS
    FROM    USERS_GROUPS
    WHERE   USERS_GROUPS.USER_ID = USER_USER_ID;
    
    IF USER_STATUS = 'TEAM_LEAD' AND GROUP_MEMBERS > 1 THEN
        RETURN 1401;

    ELSE
        DELETE FROM USERS
        WHERE       USERS.USER_ID = USER_USER_ID;

        IF USER_STATUS = 'MEMBER' THEN
            UPDATE  USERS_GROUPS SET MEMBERS = (SELECT MEMBERS FROM USERS_GROUPS
                WHERE USERS_GROUPS.GROUP_ID = USER_GROUP) - 1
            WHERE   USERS_GROUPS.GROUP_ID = USER_GROUP;
        END IF;

        RETURN 1202;

    END IF;

END;
$$

LANGUAGE plpgsql;



-- 
CREATE FUNCTION AUTHORISATION(
    EMAIL           USERS.EMAIL%TYPE,

    TOKEN           USERS.TOKEN%TYPE
)

RETURNS INTEGER AS

$$
DECLARE

    USER_USER_ID    USERS.USER_ID%TYPE;

    TOKEN_TIME      USERS.TOKEN_ACTIVATION_DATE%TYPE;

BEGIN

    -- 
    SELECT  USERS.USER_ID, USERS.TOKEN_ACTIVATION_DATE
    INTO    USER_USER_ID, TOKEN_TIME
    FROM    USERS
    WHERE   USERS.EMAIL = $1;

    IF USER_USER_ID IS NULL THEN
        RETURN 1303;

    ELSE
        UPDATE  USERS
        SET     TOKEN = $2, TOKEN_ACTIVATION_DATE = NOW()
        WHERE   USERS.USER_ID  = USER_USER_ID;

        RETURN 1203;

    END IF;

END;
$$

LANGUAGE plpgsql;



-- 
CREATE FUNCTION CHECK_PASSWORD(
    EMAIL           USERS.EMAIL%TYPE
)

RETURNS TABLE(STATUS_CODE INTEGER, PASSWORD VARCHAR(256)) AS

$$
DECLARE

    USER_PASSWORD   USERS.PASSWORD%TYPE;

BEGIN

    SELECT  USERS.PASSWORD
    INTO    USER_PASSWORD
    FROM    USERS
    WHERE   USERS.EMAIL = $1;

    IF USER_PASSWORD IS NULL THEN
        -- RETURN 'NOT THIS USER IN DATABASE';
        RETURN QUERY (SELECT 1400 AS STATUS_CODE, USER_PASSWORD AS PASSWORD);
        RETURN;
    END IF;

    -- RETURN 'THIS YSER IN DATABASE AND THIS IS HIM PASSWORD';
    RETURN QUERY (SELECT 1204 AS STATUS_CODE, USER_PASSWORD AS PASSWORD);

END;
$$

LANGUAGE plpgsql;



-- 
CREATE FUNCTION SESSION(
    TOKEN_TIME      USERS.TOKEN_ACTIVATION_DATE%TYPE
)

RETURNS BOOLEAN AS

$$
DECLARE


BEGIN

    -- IF TOKEN_TIME IS NULL THEN
    --     RETURN False;

    -- ELSEIF NOW()::TIMESTAMP(0) WITHOUT TIME ZONE - TOKEN_TIME > '24:00:00' THEN
    --     RETURN False;

    IF TOKEN_TIME IS NULL OR (NOW()::TIMESTAMP(0) WITHOUT TIME ZONE - TOKEN_TIME >
        '24:00:00') THEN
        RETURN False;
    
    ELSE
        RETURN True;
    
    END IF;

END;
$$

LANGUAGE plpgsqL;