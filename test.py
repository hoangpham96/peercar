#!/usr/bin/env python3

import bcrypt

from modules import pg8000
import configparser

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



sql = """UPDATE Member
SET nickname = 'ABC'
WHERE memberno = 1"""
cur.execute(sql)




sql = """SELECT *
     FROM Member"""
cur.execute(sql)
result = cur.fetchall()

print(result)


if (result is None):
    print("Result is none")


for member in result:
    unhashedpwd = member[3]
    print(member[3])
    # hashedpwd = bcrypt.hashpw(unhashedpwd.encode(encoding = 'ascii'), bcrypt.gensalt()).decode('ascii')

unhashedpwd = result[0][3]
hashedpwd = bcrypt.hashpw(unhashedpwd.encode(encoding = 'ascii'), bcrypt.gensalt())


cur.close()
conn.close()





print("END")



