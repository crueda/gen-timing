#!/usr/bin/env python
#-*- coding: UTF-8 -*-

# autor: Carlos Rueda Morales
# date: 2016-04-21
# version: 1.1

##################################################################################
# version 1.0 release notes: call to API and generate json
# Initial version
# Requisites: library python-mysqldb. To install: "apt-get install python-mysqldb"
##################################################################################


import MySQLdb
import logging, logging.handlers
import os
import json
import sys
import datetime
import calendar
import time

#### VARIABLES #########################################################
from configobj import ConfigObj
config = ConfigObj('./gen-timing.properties')

#INTERNAL_LOG_FILE = config['directory_logs'] + "/gen-timing.log"
INTERNAL_LOG_FILE = "./gen-timing.log"
LOG_FOR_ROTATE = 10

API_URL = config['api_url']

INTERNAL_LOG = "/tmp/kyros-json.log"

PID = "/var/run/json-generator"

from json import encoder
encoder.FLOAT_REPR = lambda o: format(o, '.4f')


########################################################################
# definimos los logs internos que usaremos para comprobar errores
log_folder = os.path.dirname(INTERNAL_LOG)

if not os.path.exists(log_folder):
	os.makedirs(log_folder)

try:
	logger = logging.getLogger('wrc-json')
	loggerHandler = logging.handlers.TimedRotatingFileHandler(INTERNAL_LOG , 'midnight', 1, backupCount=10)
	formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
	loggerHandler.setFormatter(formatter)
	logger.addHandler(loggerHandler)
	logger.setLevel(logging.DEBUG)
except:
	print '------------------------------------------------------------------'
	print '[ERROR] Error writing log at %s' % INTERNAL_LOG
	print '[ERROR] Please verify path folder exits and write permissions'
	print '------------------------------------------------------------------'
	exit()
########################################################################

########################################################################
if os.access(os.path.expanduser(PID), os.F_OK):
        print "Checking if json generator is already running..."
        pidfile = open(os.path.expanduser(PID), "r")
        pidfile.seek(0)
        old_pd = pidfile.readline()
        # process PID
        if os.path.exists("/proc/%s" % old_pd) and old_pd!="":
			print "You already have an instance of the json generator running"
			print "It is running as process %s," % old_pd
			sys.exit(1)
        else:
			print "Trying to start json generator..."
			os.remove(os.path.expanduser(PID))

pidfile = open(os.path.expanduser(PID), 'a')
print "json generator started with PID: %s" % os.getpid()
pidfile.write(str(os.getpid()))
pidfile.close()
#########################################################################

def getUTC():
	t = calendar.timegm(datetime.datetime.utcnow().utctimetuple())
	return int(t)


def getTracking():
	dbKyros4 = MySQLdb.connect(MYSQL_IP, MYSQL_USER, MYSQL_PASSWORD, MYSQL_NAME)
	try:
		dbKyros4 = MySQLdb.connect(MYSQL_IP, MYSQL_USER, MYSQL_PASSWORD, MYSQL_NAME)
	except:
		logger.error('Error connecting to database: IP:%s, USER:%s, PASSWORD:%s, DB:%s', MYSQL_IP, MYSQL_USER, MYSQL_PASSWORD, MYSQL_NAME)

	cursor = dbKyros4.cursor()
	cursor.execute("""SELECT VEHICLE.ALIAS as DRIVER, 
		round(POS_LATITUDE_DEGREE,5) + round(POS_LATITUDE_MIN/60,5) as LAT, 
		round(POS_LONGITUDE_DEGREE,5) + round(POS_LONGITUDE_MIN/60,5) as LON, 
		round(TRACKING_1.GPS_SPEED,1) as speed,
		round(TRACKING_1.HEADING,1) as heading,
		VEHICLE.START_STATE as TRACKING_STATE, 
		VEHICLE_EVENT_1.TYPE_EVENT as VEHICLE_STATE, 
		VEHICLE.ALARM_ACTIVATED as ALARM_STATE,
		TRACKING_1.VEHICLE_LICENSE as DEV,
		TRACKING_1.POS_DATE as DATE 
		FROM VEHICLE inner join (TRACKING_1, HAS, VEHICLE_EVENT_1) 
		WHERE VEHICLE.VEHICLE_LICENSE = TRACKING_1.VEHICLE_LICENSE
		AND VEHICLE.VEHICLE_LICENSE = VEHICLE_EVENT_1.VEHICLE_LICENSE
		AND VEHICLE.VEHICLE_LICENSE =  HAS.VEHICLE_LICENSE
		AND (HAS.FLEET_ID=489 || HAS.FLEET_ID=498)""")
	result = cursor.fetchall()
	
	try:
		return result
	except Exception, error:
		logger.error('Error getting data from database: %s.', error )
		
	cursor.close
	dbFrontend.close

while True:
	array_list = []
	trackingInfo = getTracking()

	for tracking in trackingInfo:
	#	lonRound = float("{0:.4f}".format(tracking[2]))
	#	print lonRound
	#	latRound = float("{0:.4f}".format(tracking[1]))
	#	print latRound
		tracking_state = str(tracking[5])
		state = str(tracking[6])

		#if (state != "CAR_HOOD_OPEN" and state != "YELLOW_FLAG_CONFIRM" and state != "VEHICLE_STOPPED" and tracking_state != "STOP"):
		if (state != "CAR_HOOD_OPEN" and state != "YELLOW_FLAG_CONFIRM" and tracking_state != "STOP"):
			utcDate = getUTC()
			delta = (utcDate-3600) - int(tracking[7])/1000
			if delta > 300:
				state = "OLD"
			elif delta > 90:
				state = "1MIN"

		position = {"geometry": {"type": "Point", "coordinates": [ tracking[2] , tracking[1] ]}, "type": "Feature", "properties":{"alias":str(tracking[0]), "speed": str(tracking[3]), "heading": str(tracking[4]), "tracking_state":tracking_state, "vehicle_state":state, "alarm_state":str(tracking[7]), "license":str(tracking[8])}}
		array_list.append(position)

	with open('/var/www2/tracking_wrc.json', 'w') as outfile:
		json.dump(array_list, outfile)
	
	time.sleep(1)
