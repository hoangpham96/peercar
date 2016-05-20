SELECT * FROM member;
ALTER TABLE member ALTER password SET DATA TYPE CHAR(60)
UPDATE member SET password ='$2b$12$e/BZXwFoEg9dHSlJ9uDQ..iexa5UWBXHnCXgEsqMIOGf01pmsSIju' WHERE memberno=1
ALTER TABLE member DROP COLUMN pw_salt0
--Check Login
/*
CREATE FUNCTION () RETURNS  AS 
$$
  BEGIN
		
  END;
$$ LANGUAGE plpgsql;
*/