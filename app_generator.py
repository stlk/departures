import logging
from flask import Flask
from request_logger import attach_logger


def create_app():
    app = Flask(__name__)

    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    attach_logger(app)
    return app
