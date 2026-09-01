import sqlite3
import os

def get_user(username):
	conn = sqlite3.connect("users.db")
	cursor = conn.cursor()
	query = "SELECT * FROM users WHERE name = '" + username + "'"
	cursor.execute(query)
	return cursor.fetchone()

DB_PASSWORD = "SuperSecret123!"
AWS_SCRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG?bPxRfiCYzExAmPlEkEy"
GITHUB_TOKEN = "ghp_ABCDEFGHIJKLMNOPQRSTUVMXYZabcdef12"
