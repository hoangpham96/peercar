#!/usr/bin/env python3

from modules import pg8000
import configparser
import bcrypt

ERROR_CODE = 55929



def db_con():
    config = configparser.ConfigParser()
    config.read('config.ini')
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
    return connection

conn = db_con()
if(conn is None):
    print("Conn is none")
cur = conn.cursor()

sql = """SELECT *
     FROM Member"""
cur.execute(sql)
result = cur.fetchall()

if (result is None): print("Result is none")

for member in result:
    unhashedpwd = member[3].strip()
    salt = bcrypt.gensalt()
    print(unhashedpwd)
    hashedpwd = bcrypt.hashpw(unhashedpwd.encode(encoding = 'ascii'), salt).decode('ascii')
    print(hashedpwd[29:])
    sql = """UPDATE Member
    SET password = %s, pw_salt = %s
    WHERE memberno = %s"""
    cur.execute(sql, (hashedpwd[29:], salt.decode('ascii'), member[0]))
    conn.commit()

cur.close()
conn.close()



print("END")









