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
                 FROM login(%s)"""
        cur.execute(sql, (email,))
        result = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()

        if (result is None or len(result) < 1):
            return None

        #Convert hashing components to the b'' type
        stored_salt = result[1].encode(encoding = 'ascii')
        password = password.encode(encoding = 'ascii')

        #Taking the last 31 characters of the output because bcrypt is interesting.
        input_hash = (bcrypt.hashpw(password, stored_salt).decode('ascii'))[29:]
        stored_hash = result[0]

        if ( input_hash == stored_hash):
            return result
        else:
            return None
        
    except:
        print("Error with Database")
        conn.rollback()
        cur.close()
        conn.close()


#####################################################
##  Homebay
#####################################################
def update_homebay(email, bayname):

    # TODO
    # Update the user's homebay

    # Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        # Get homebay id from bayname
        # Try executing the SQL and get from the database
        sql = """SELECT * 
                 FROM update_homebay(%s,%s)"""
        cur.execute(sql, (email, bayname))
        
        conn.commit()
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        
        return True

    except:
        # If there were any errors, return a NULL row printing an error to the debug
        print("Error with Database")
    conn.rollback()
    cur.close()                     # Close the cursor
    conn.close()                    # Close the connection to the db
    return False

#####################################################
##  Booking (make, get all, get details)
#####################################################

def make_booking(email, car_rego, date, hour, duration):

    # #Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        result = True
        # Try executing the SQL and get from the database
        sql = """SELECT *
                 FROM make_booking(%s, %s, %s, %s, %s)"""
        cur.execute(sql, (email, car_rego, date, hour, duration,))
        val = cur.fetchone()
        if(val is None or val[0] == None or val[0] == False):
            conn.rollback()
            result = False
        else:
            conn.commit()
            result = True
            
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db

        return result
        
    except:
        # If there were any errors return false
        print("Error with Database")
        conn.rollback()
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        return False


def get_all_bookings(email):

    # Get all the bookings made by this member's email

    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        sql = """SELECT * FROM get_all_bookings(%s)"""
        cur.execute(sql, (email,))
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
     	 #val = ['Shadow', '66XY99', 'Ice the Cube', '01-05-2016', '10', '4', '29-04-2016', 'SIT']
         # sql = """SELECT namegiven, car, car.name, starttime::date, EXTRACT(hour FROM whenbooked),
         #          EXTRACT(epoch FROM endtime-starttime)/3600, whenbooked::date, carbay.name
         #          FROM member INNER JOIN booking ON (madeby = memberno)
         #          INNER JOIN car ON (car = regno)
         #          INNER JOIN carbay ON (parkedat = bayid)
         #          WHERE whenbooked::date = %s
         #          AND EXTRACT(hour from whenbooked) = %s
         #          AND car = %s"""
         sql = """SELECT * FROM get_booking(%s, %s, %s)"""
         cur.execute(sql, (b_date, b_hour, car))
         result = cur.fetchone()
         print(result)
         if(result is None or result[0] is None):
         	return None
            
         cur.close()
         conn.close()
 
         return result
 
     except:
        print("Error with Database")
        conn.rollback()
        cur.close()
        conn.close()
        return None

#####################################################
##  Car (Details and List)
#####################################################

def get_car_details(regno):
    # Get details of the car with this registration number
    # Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        result = []
        # Try executing the SQL and get from the database
        sql = """SELECT * FROM get_car_details(%s)""" 
        cur.execute(sql, (regno,))
        result = cur.fetchone()
        if (result is None):
            conn.rollback()
            return None
        else:
        	conn.commit()
        	return result

        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        
    except:
        # If there were any errors, return a NULL row printing an error to the debug
        print("Error with Database")
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        return None

def get_all_cars():
    # Get all cars that PeerCar has
    # Return the results
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        # Try executing the SQL and get from the database
        sql = """SELECT * FROM get_all_cars()"""
        cur.execute(sql)
        result = cur.fetchall()
        if (result is None or len(result) == 0):
            conn.rollback()
            return None
        else:
            conn.commit()
            return result

        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        
    except:
        # If there were any errors, return a NULL row printing an error to the debug
        print("Error with Database")
        conn.rollback()
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db


    return None
#####################################################
##  Bay (detail, list, finding cars inside bay)
#####################################################

def get_all_bays(hb):

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
                 where CB.name = %s
                 GROUP BY CB.name, CB.address
                 UNION ALL
                 SELECT CB.name, CB.address, count(C.regno) AS count
                 FROM carbay CB INNER JOIN car C ON (CB.bayid = C.parkedat)
                 GROUP BY CB.name, CB.address"""

        cur.execute(sql, (hb,))
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

    # Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        result = []
        # Try executing the SQL and get from the database
        sql = """SELECT name, description, address, gps_long, gps_lat
                 FROM carbay 
                 WHERE name = %s"""
        cur.execute(sql, (name,))
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
    return None


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

    # Get the cars inside the bay with the bay name
    # Cars who have this bay as their bay :)
    # Return simple details (only regno and name)

    # Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        # Try executing the SQL and get from the database
        sql = """SELECT * FROM get_cars_in_bay(%s)"""
        cur.execute(sql, (bay_name,))
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

#################
# ADDED METHODS #
#################
def get_bayname(bayid):

    # Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:
        # Try executing the SQL and get from the database
        sql = """SELECT * 
                    FROM get_bayname(%s)"""
        cur.execute(sql, (bayid,))
        result = cur.fetchone()

        conn.commit()
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        

        if (result is None or len(result) < 1):
            return None

        return result[0]
        
    except:
        print("Error with Database")
        conn.rollback()
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
    
        return None

#Get all invoices from the user
def get_all_invoices(email):
    # Ask for the database connection, and get the cursor set up
    conn = database_connect()
    if(conn is None):
        return ERROR_CODE
    cur = conn.cursor()

    try:

        # Try executing the SQL and get from the database
        sql = """SELECT * FROM get_all_invoices(%s)"""
        cur.execute(sql, (email,))
        result = cur.fetchall()


        conn.commit()
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
        

        if (result is None):
            return None

        return result
        
    except:
        print("Error with Database")
        conn.rollback()
        cur.close()                     # Close the cursor
        conn.close()                    # Close the connection to the db
    
        return None