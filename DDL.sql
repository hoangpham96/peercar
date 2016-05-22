
﻿/*set carsharing as the default schema*/
SET search_path TO carsharing;

ALTER TABLE member ALTER password SET DATA TYPE CHAR(60);
ALTER TABLE member DROP COLUMN pw_salt;


--------------------------------------
-- PROCEDURES --
--------------------------------------

/* Return bays matching a search term*/
--SELECT * FROM search_bays('point');
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


/* Return bookings based on member's email*/
SELECT * FROM get_all_bookings('DrdrfosterFoster@gmail.com');
DROP FUNCTION IF EXISTS get_all_bookings(email TEXT);
CREATE OR REPLACE FUNCTION get_all_bookings(member_email TEXT)
	RETURNS TABLE(regno_result Booking.car%TYPE, carName_result Car.name%TYPE, starttimeDate_result DATE, starttimeHour_result INTEGER)
AS $$
	BEGIN
		RETURN QUERY
			SELECT car, name, starttime::date, CAST(EXTRACT(hour FROM starttime) AS INT)
			FROM Member INNER JOIN Booking ON (memberno = madeby)
			INNER JOIN Car ON (car = regno)
			WHERE email = member_email OR nickname = member_email
			ORDER BY starttime::date DESC;
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

		-- Unsure about this
		/*IF(booking_duration < 1) THEN
			RETURN FALSE;
		END IF;*/

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
		UPDATE member SET stat_nrofbookings = stat_nrofbookings + 1 WHERE memberno = booking_memberno;
		
		
		RETURN TRUE;

	EXCEPTION
		-- return false if there is an exception
		WHEN OTHERS THEN RETURN FALSE;
	END;
$$ LANGUAGE plpgsql;

/* Get number of bookins stat of user */
DROP FUNCTION IF EXISTS get_num_bookings(raw_email TEXT);
CREATE OR REPLACE FUNCTION get_num_bookings(raw_email TEXT)
	RETURNS INTEGER
AS $$
	DECLARE
		return_value INTEGER;
	BEGIN

		SELECT stat_nrofbookings
		INTO return_value
		FROM member
		WHERE email = TRIM(raw_email) 
			OR m.nickname = TRIM(raw_email);
		
		RETURN reutrn_value;	

	EXCEPTION
		WHEN OTHERS THEN RETURN NULL;
	END;
$$ LANGUAGE plpgsql;