ALTER TABLE member ALTER password SET DATA TYPE CHAR(31);
ALTER TABLE member ALTER pw_salt SET DATA TYPE CHAR(29);

--------------------------------------
-- PROCEDURES --
--------------------------------------

/* Return bays matching a search term*/
SELECT * FROM search_bays('point');
DROP FUNCTION IF EXISTS search_bays(search_term TEXT);
CREATE OR REPLACE FUNCTION search_bays(search_term TEXT)
	RETURNS TABLE(name_result carbay.name%TYPE, address_result carbay.address%TYPE, count_result INTEGER)
AS $$
	BEGIN
		search_term := TRIM(search_term);
		IF(search_term IS NOT NULL) THEN 
			search_term := TRIM(search_term);
		END IF;
		
		IF(search_term IS NULL OR search_term = '') THEN
			RETURN	QUERY SELECT cb.name, cb.address, CAST(COUNT(regno) AS INTEGER)
					FROM carbay cb 
						LEFT OUTER JOIN car c 
						ON(c.parkedat = cb.bayid)
					GROUP BY bayid;
		ELSE
			RETURN	QUERY SELECT cb.name, cb.address, CAST(COUNT(regno) AS INTEGER)
					FROM carbay cb 
						LEFT OUTER JOIN car c 
						ON(c.parkedat = cb.bayid)
					WHERE cb.name ILIKE '%'|| search_term ||'%'
						OR cb.address ILIKE '%'|| search_term ||'%'
					GROUP BY bayid;
		END IF;
	END;
$$ LANGUAGE plpgsql;

/* Return bays matching a search term*/
--SELECT * FROM member;
DROP FUNCTION IF EXISTS get_hash&salt(TEXT);
CREATE OR REPLACE FUNCTION get_hash&salt(raw_email TEXT)
	RETURNS TABLE(hash_result member.password%TYPE, salt_result member.pw_salt%TYPE)
AS $$
	BEGIN
		
		IF(raw_email IS NOT NULL) THEN
			raw_email := TRIM(raw_email);
		END IF;

		RETURN QUERY SELECT m.password, m.pw_salt
		FROM member m
		WHERE m.email = raw_email
			OR m.nickname = raw_email;
		
	END;
$$ LANGUAGE plpgsql;