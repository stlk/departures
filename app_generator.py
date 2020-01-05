import logging
from flask import Flask
from request_logger import attach_logger

from datetime import timedelta
import json

class TimeDeltaEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, timedelta):
            return str(o)

        return json.JSONEncoder.default(self, o)

def create_app():
    app = Flask(__name__)
    app.json_encoder = TimeDeltaEncoder

    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    attach_logger(app)
    return app
