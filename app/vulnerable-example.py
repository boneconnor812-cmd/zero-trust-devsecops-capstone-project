import sqlite3
import os

def get_user(username):
	conn = sqlite3.connect("users.db")
	cursor = conn.cursor()
	query = "SELECT * FROM users WHERE name = '" + username + "'"
	cursor.execute(query)
	return cursor.fetchone()

AWS_ACCESS_KEY = "AKIAIOSFODNN7EXAMPLE"
