#!/usr/bin/env python3

from modules import pg8000
import configparser
import bcrypt

# Define some useful variables
ERROR_CODE = 55929

#####################################################
##  Database Connect
#####################################################

def database_connect():
    # Read the config file
    config = configparser.ConfigParser()
    config.read('config.ini')
    # Create a connection to the database
    connection = None
    try:
        connection = pg8000.connect(database=config['DATABASE']['user'],
            user=config['DATABASE']['user'],
            password=config['DATABASE']['password'],
            host=config['DATABASE']['host'])
    except pg8000.OperationalError as e:
        print("""Error, you haven't updated your config.ini or you have a bad
        connection, please try again. (Update your files first, then check
        internet connection)
        """)
        print(e)
    #return the connection to use
    return connection


#####################################################
##  Login
#####################################################

def check_login(email, password):

    # Check if the user details are correct!

    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        sql = """SELECT *
                 FROM Member
                 WHERE email=%s OR nickname =%s"""
        cur.execute(sql, (email, email))
        result = cur.fetchone()
        cur.close()
        conn.close()

        if (result is None):
            return None

        # Stored hash includes salt and hash of password
        stored_hash = result[3].encode(encoding='ascii')
        pwd = password.encode(encoding = 'ascii')

        if (bcrypt.hashpw(pwd, stored_hash) == stored_hash):
            return result
        else:
            return None
        
    except:
        print("Error with Database")
        cur.close()
        conn.close()
        return None


#####################################################
##  Homebay
#####################################################
def update_homebay(email, bayname):
    # TODO
    # Update the user's homebay
    return True

#####################################################
##  Booking (make, get all, get details)
#####################################################

def make_booking(email, car_rego, date, hour, duration):
    # TODO
    # Insert a new booking
    # Make sure to check for:
    #       - If the member already has booked at that time
    #       - If there is another booking that overlaps
    #       - Etc.
    # return False if booking was unsuccessful :)
    # We want to make sure we check this thoroughly
    return True


def get_all_bookings(email):

    # Get all the bookings made by this member's email

    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        sql = """SELECT car, name, whenbooked::date, EXTRACT(hour FROM whenbooked)
                 FROM Member INNER JOIN Booking ON (memberno = madeby)
                 INNER JOIN Car ON (car = regno)
                 WHERE email=%s OR nickname =%s
                 ORDER BY whenbooked::date"""

        cur.execute(sql, (email,email))
        result = cur.fetchall()
        cur.close()
        conn.close()

        return result

    except:
        print("Error with Database")

    cur.close()
    conn.close()

    return None



def get_booking(b_date, b_hour, car):

    # Get the information about a certain booking
    # It has to have the combination of date, hour and car

    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        sql = """SELECT namegiven, car, car.name, starttime::date, EXTRACT(hour FROM whenbooked),
                 EXTRACT(epoch FROM endtime-starttime)/3600, whenbooked::date, carbay.name
                 FROM member INNER JOIN booking ON (madeby = memberno)
                 INNER JOIN car ON (car = regno)
                 INNER JOIN carbay ON (parkedat = bayid)
                 WHERE whenbooked::date = %s
                 AND EXTRACT(hour from whenbooked) = %s
                 AND car = %s"""

        cur.execute(sql, (b_date, b_hour, car))
        result = cur.fetchone()
        cur.close()
        conn.close()

        return result

    except:
        print("Error with Database")

    cur.close()
    conn.close()

    return None


#####################################################
##  Car (Details and List)
#####################################################

def get_car_details(regno):
    val = ['66XY99', 'Ice the Cube','Nissan', 'Cube', '2007', 'auto', 'Luxury', '5', 'SIT', '8', 'http://example.com']
    # TODO
    # Get details of the car with this registration number
    # Return the data (NOTE: look at the information, requires more than a simple select. NOTE ALSO: ordering of columns)

    # Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        result = []
        # Try executing the SQL and get from the database
        sql = """SELECT regno, C.name, make, model, year, transmission, category, capacity, CB.name, walkscore, mapurl
                 FROM (Car C INNER JOIN CarModel CM USING (make, model))
                             INNER JOIN Carbay CB ON (C.parkedat = CB.bayid)
                 WHERE regno = %s """ 
        cur.execute(sql, regno)
        result = cur.fetchone()
        if (result is None):
            return None

        return result

        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        
    except:
        # If there were any errors, return a NULL row printing an error to the debug
        print("Error with Database")
    cur.close()                     # Close the cursor
    conn.close()                    # Close the connection to the db


    return result

def get_all_cars():
    # Get all cars that PeerCar has
    # Return the results
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        # Try executing the SQL and get from the database
        sql = """SELECT regno, name, make, model, year, transmission
                 FROM Car
                 ORDER BY name ASC"""
        cur.execute(sql)
        result = cur.fetchall()
        if (result is None):
            return None

        return result

        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        
    except:
        # If there were any errors, return a NULL row printing an error to the debug
        print("Error with Database")
    cur.close()                     # Close the cursor
    conn.close()                    # Close the connection to the db


    return None
#####################################################
##  Bay (detail, list, finding cars inside bay)
#####################################################

def get_all_bays():

    # Get all the bays that PeerCar has :)
    # And the number of bays
    # Return the results

    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        sql = """SELECT CB.name, CB.address, count(C.regno) AS count
                 FROM carbay CB INNER JOIN car C ON (CB.bayid = C.parkedat)
                 GROUP BY CB.name, CB.address
                 ORDER BY name ASC"""

        cur.execute(sql)
        result = cur.fetchall()
        cur.close()
        conn.close()

        return result

    except:
        print("Error with Database")

    return None


def get_bay(name):
    val = ['SIT', 'Home to many (happy?) people.', '123 Some Street, Boulevard', '-33.887946', '151.192958']

    # TODO
    # Get the information about the bay with this unique name
    # Make sure you're checking ordering ;)

    return val

def search_bays(search_term):
    #val = [['SIT', '123 Some Street, Boulevard', '-33.887946', '151.192958']]

    # Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        # Try executing the SQL and get from the database
        sql = """SELECT *
                 FROM search_bays(%s)"""
        cur.execute(sql, (search_term,))
        result = cur.fetchall()
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        
        if (result is None):
            return None
        else:
            return result
        
    except:
        # If there were any errors, return a NULL row printing an error to the debug
        print("Error with Database")
    cur.close()                     # Close the cursor
    conn.close()                    # Close the connection to the db
    return None

def get_cars_in_bay(bay_name):
    val = [ ['66XY99', 'Ice the Cube'], ['WR3KD', 'Bob the SmartCar']]

    # TODO
    # Get the cars inside the bay with the bay name
    # Cars who have this bay as their bay :)
    # Return simple details (only regno and name)

    return val
