# app/logging.py

import logging
import sys
from app.config import config


def init_logging() -> None:
    formatter = logging.Formatter(fmt=config.LOG_FORMAT)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(config.LOG_LEVEL)
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.setLevel(config.LOG_LEVEL)
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
