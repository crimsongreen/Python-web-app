"""
Hello World Python web app
using Flask
"""
from flask import Flask

app = Flask(__name__)


@app.route("/")
def greeting():
    return "Welcome!"


@app.route("/test")
def health_resp():
    return "200 OK!"
