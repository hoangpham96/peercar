/*set carsharing as the default schema*/
SET search_path TO carsharing;

ALTER TABLE member ALTER password SET DATA TYPE CHAR(31);
ALTER TABLE member ALTER pw_salt SET DATA TYPE CHAR(29);


--------------------------------------
-- PROCEDURES --
--------------------------------------

/* Return the relevant Login details */
--SELECT * FROM member where memberno = 1;
--SELECT * FROM login('drfoster');
--DROP FUNCTION IF EXISTS login(input_email TEXT);
CREATE OR REPLACE FUNCTION login(input_email TEXT)
	RETURNS TABLE(result_password member.password%TYPE, 
			result_pw_salt member.pw_salt%TYPE,
			result_email member.email%TYPE, 
			result_nickname member.nickname%TYPE, 
			result_nametitle member.nametitle%TYPE, 
			result_namegiven member.namegiven%TYPE,
			result_namefamily member.namefamily%TYPE,
			result_address member.address%TYPE,
			result_since member.since%TYPE,
			result_homebay member.homebay%TYPE,
			result_subscribed member.subscribed%TYPE,
			result_stat_nrofbookings member.stat_nrofbookings%TYPE)
			--Making a type is the same damn work.
AS $$
	BEGIN
		IF(input_email IS NULL) THEN 
			RETURN QUERY SELECT NULL;
		END IF;

		RETURN QUERY SELECT password,
					pw_salt,
					email, 
					nickname, 
					nametitle, 
					namegiven,
					namefamily,
					address,
					since,
					homebay, 
					subscribed,
					stat_nrofbookings
					
				FROM member
				WHERE LOWER(email) = LOWER(TRIM(input_email)) 
					OR nickname = TRIM(input_email);
	END;
$$ LANGUAGE plpgsql;

/* update homebay from from email and bay name*/
CREATE OR REPLACE FUNCTION update_homebay(input_email TEXT, input_bayname TEXT)
	RETURNS BOOLEAN
AS $$
	DECLARE
		current_bayid INTEGER;
	BEGIN
		current_bayid := NULL;

		IF(input_email IS NULL 
		OR input_bayname IS NULL) THEN 
			RETURN FALSE;
		END IF;

		SELECT bayid
		INTO current_bayid
        FROM carbay
        WHERE name=input_bayname;

        IF (current_bayid IS NULL) THEN 
        	RETURN FALSE;
        END IF;

        UPDATE Member
        SET homebay=current_bayid
        WHERE email=input_email;

		RETURN TRUE;
	EXCEPTION
		WHEN OTHERS THEN RETURN FALSE;
	END;
$$ LANGUAGE plpgsql;


/* resolve bay name from bay id*/
--SELECT * FROM carbay;
--DROP FUNCTION IF EXISTS get_bayname(input_bayid TEXT);
CREATE OR REPLACE FUNCTION get_bayname(input_bayid TEXT)
	RETURNS TABLE(result_name carbay.name%TYPE)
AS $$
	BEGIN
		IF(input_bayid IS NULL) THEN 
			RETURN QUERY SELECT NULL;
		END IF;

		RETURN QUERY SELECT name
				FROM carbay
				WHERE bayid = CAST(TRIM(input_bayid) AS INTEGER);
	EXCEPTION
		WHEN OTHERS THEN RETURN QUERY SELECT NULL;
	END;
$$ LANGUAGE plpgsql;


/* Return bays matching a search term*/
--SELECT * FROM search_bays('point');
--DROP FUNCTION IF EXISTS search_bays(search_term TEXT);
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




/* Returns a list of bookings a user has made using given email*/
--DROP FUNCTION IF EXISTS get_all_bookings(member_email TEXT);
CREATE OR REPLACE FUNCTION get_all_bookings(member_email TEXT)
	RETURNS TABLE(regno_result Booking.car%TYPE, carName_result Car.name%TYPE, starttimeDate_result DATE, starttimeHour_result INTEGER, duration_result INTEGER, whenBookedDate_result DATE)
AS $$
	BEGIN
		RETURN QUERY
			SELECT car, name, starttime::date, CAST(EXTRACT(hour FROM starttime) AS INT), CAST(EXTRACT(epoch FROM endtime-starttime)/3600 AS INT), whenbooked::date
			FROM Member INNER JOIN Booking ON (memberno = madeby)
			INNER JOIN Car ON (car = regno)
			WHERE email = member_email OR nickname = member_email
			ORDER BY starttime::date DESC;
	END;
$$ LANGUAGE plpgsql;



/* Attempt to make booking and return whether successful*/
--SELECT * FROM booking WHERE madeby = 1 ORDER BY whenbooked DESC;
--SELECT * FROM make_booking('drfoster', 'BJN71S', '2022-07-01', '5', '12');
--DROP FUNCTION IF EXISTS make_booking(TEXT, TEXT, TEXT, TEXT, TEXT);
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
--DROP FUNCTION IF EXISTS get_num_bookings(raw_email TEXT);
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