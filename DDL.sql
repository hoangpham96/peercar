﻿SET search_path TO carsharing;
ALTER TABLE member ALTER password SET DATA TYPE CHAR(60);
ALTER TABLE member DROP COLUMN pw_salt;

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


/* Return bookings based on member's email*/
SELECT * FROM get_all_bookings('point');
DROP FUNCTION IF EXISTS get_all_bookings(email TEXT);
CREATE OR REPLACE FUNCTION get_all_bookings(member_email TEXT)
	RETURNS TABLE(regno_result Booking.car%TYPE, carName_result Car.name%TYPE, whenBookedDate_result DATE, whenBookedHour INTEGER)
AS $$
	BEGIN
		RETURN QUERY
			SELECT car, name, whenbooked::date, CAST(EXTRACT(hour FROM whenbooked) AS INT)
			FROM Member INNER JOIN Booking ON (memberno = madeby)
			INNER JOIN Car ON (car = regno)
			WHERE email = member_email OR nickname = member_email
			ORDER BY whenbooked::date DESC;
	END;
$$ LANGUAGE plpgsql;