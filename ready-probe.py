#!/usr/bin/env python

import sys
import logging
import urllib2

FORMAT = '%(asctime)-15s - %(levelname)-4s - %(message)s'
logging.basicConfig(level=logging.INFO, format=FORMAT)
logger = logging.getLogger('PROBE')

try:
    urllib2.urlopen('http://localhost:8080')
except Exception as e:
    logger.error(e)
    sys.exit(1)

logger.info('OK!')
