/*set carsharing as the default schema*/
SET search_path TO carsharing

SELECT * FROM carbay
ALTER TABLE member ALTER password SET DATA TYPE CHAR(60)
UPDATE member SET password ='$2b$12$e/BZXwFoEg9dHSlJ9uDQ..iexa5UWBXHnCXgEsqMIOGf01pmsSIju' WHERE memberno=1
ALTER TABLE member DROP COLUMN pw_salt0

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
		IF(search_term IS NOT NULL) THEN 
			search_term := TRIM(search_term);
		END IF;

		-- return all results when search term is null or empty
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


/* Attempt to make booking and return whether successful*/
--SELECT * FROM booking WHERE madeby = 1 ORDER BY whenbooked DESC;
--SELECT * FROM make_booking('drfoster', 'BJN71S', '2022-07-01', '5', '12');
DROP FUNCTION IF EXISTS make_booking(TEXT, TEXT, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION make_booking(raw_email TEXT, 
					raw_regno TEXT, 
					raw_booking_date TEXT, 
					raw_booking_hour TEXT,
					raw_duration TEXT)
	RETURNS BOOLEAN
AS $$
	DECLARE
		-- Cleaned up variables 
		booking_date DATE;
		booking_hour INTEGER;
		booking_duration INTEGER;

		--The variables for the insertion
		booking_car booking.car%TYPE;
		booking_memberno booking.madeby%TYPE;
		booking_starttime booking.starttime%TYPE;
		booking_endtime booking.endtime%TYPE;
		
	BEGIN
		-- Clean the input data; exception will be caught on fail.
		IF(raw_email IS NULL
			OR raw_regno IS NULL
			OR raw_booking_date IS NULL
			OR raw_booking_hour IS NULL
			OR raw_duration IS NULL) THEN
			RETURN FALSE;
		END IF;
		
		booking_car := TRIM(raw_regno);
		booking_date := TRIM(raw_booking_date);
		booking_hour := TRIM(raw_booking_hour);
		booking_duration := TRIM(raw_duration);

		IF(booking_hour < 0 OR booking_hour > 23) THEN
			RETURN FALSE;
		END IF;

		IF(booking_duration < 1) THEN
			RETURN FALSE;
		END IF;

		--look up memberno associated with the email/nick
		SELECT m.memberno
		INTO booking_memberno
		FROM member m
		WHERE m.email = TRIM(raw_email) 
			OR m.nickname = TRIM(raw_email);

		--Check there was a member
		IF(booking_memberno IS NULL) THEN
			RETURN FALSE;
		END IF;

		--Calculate start and end times
		booking_starttime := booking_date + booking_hour * interval '1 hour';
		booking_endtime := booking_starttime + booking_duration * interval '1 hour';

		--Check booking is after current time
		IF(booking_starttime < LOCALTIMESTAMP) THEN
			RETURN FALSE;
		END IF;

		--Check car isn't booked at that time and that member doesnt have another booking at that time.
		IF(EXISTS (SELECT *
				FROM booking b
				WHERE (b.car = booking_car OR b.madeby = booking_memberno)
					AND (b.starttime, b.endtime) OVERLAPS (booking_starttime, booking_endtime))) THEN
			RETURN FALSE;
		END IF;
		
		-- Insert the booking
		INSERT INTO booking(car, madeby, whenbooked, starttime, endtime) 
			VALUES (booking_car, booking_memberno, LOCALTIMESTAMP , booking_starttime, booking_endtime);
		
		RETURN TRUE;

	EXCEPTION
		-- return false if there is an exception
		WHEN OTHERS THEN RETURN FALSE;	
	END;
$$ LANGUAGE plpgsql;