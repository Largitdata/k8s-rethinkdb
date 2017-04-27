#!/usr/bin/env python

import sys
import logging
import rethinkdb as r

FORMAT = '%(asctime)-15s - %(levelname)-4s - %(message)s'
logging.basicConfig(level=logging.INFO, format=FORMAT)
logger = logging.getLogger('PROBE')


try:
    conn = r.connect('localhost',28015,'rethinkdb')
    r.table('server_status').pluck('id', 'name').run(conn)
except Exception as e:
    logger.error(e)
    sys.exit(1)

logger.info("OK!")
