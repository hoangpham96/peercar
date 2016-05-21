SELECT * FROM carbay;
ALTER TABLE member ALTER password SET DATA TYPE CHAR(60)
UPDATE member SET password ='$2b$12$e/BZXwFoEg9dHSlJ9uDQ..iexa5UWBXHnCXgEsqMIOGf01pmsSIju' WHERE memberno=1
ALTER TABLE member DROP COLUMN pw_salt0

-- TYPES --
CREATE TYPE car_bay AS (
  bayid INTEGER,
  name        VARCHAR(80),
  address     VARCHAR(200),
  description TEXT,
  gps_lat     FLOAT,
  gps_long    FLOAT,
  mapURL      VARCHAR(200),
  walkscore   INTEGER,
  located_at  INTEGER
);

--------------------------------------
-- PROCEDURES --
--------------------------------------

/* Return bays matching a search term*/
--SELECT * FROM search_bays('point');
DROP FUNCTION IF EXISTS search_bays(search_term TEXT);
CREATE OR REPLACE FUNCTION search_bays(search_term TEXT)
	RETURNS SETOF car_bay
AS $$
	BEGIN
		search_term := TRIM(search_term);
		IF(search_term IS NOT NULL) THEN 
			search_term := TRIM(search_term);
		END IF;
		
		IF(search_term IS NULL OR search_term = '') THEN
			RETURN	QUERY SELECT *
				FROM carbay;
		ELSE
			RETURN	QUERY SELECT *
				FROM carbay
				WHERE name ILIKE '%'|| search_term ||'%'
					OR address ILIKE '%'|| search_term ||'%';
		END IF;
	END;
$$ LANGUAGE plpgsql;