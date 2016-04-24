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

#import MySQLdb
import logging, logging.handlers
import os
import json
import sys
import datetime
import calendar
import requests
import time
import xml.etree.ElementTree

#### VARIABLES #########################################################
from configobj import ConfigObj
config = ConfigObj('./gen-timing.properties')

#INTERNAL_LOG_FILE = config['directory_logs'] + "/gen-timing.log"
INTERNAL_LOG_FILE = "./gen-timing.log"
LOG_FOR_ROTATE = 10

API_URL = config['api_url']


#PID = "/var/run/timing-generator"
PID = "./timing-generator"

from json import encoder
encoder.FLOAT_REPR = lambda o: format(o, '.4f')


########################################################################
# definimos los logs internos que usaremos para comprobar errores
log_folder = os.path.dirname(INTERNAL_LOG_FILE)

if not os.path.exists(log_folder):
	os.makedirs(log_folder)

try:
	logger = logging.getLogger('wrc-json')
	loggerHandler = logging.handlers.TimedRotatingFileHandler(INTERNAL_LOG_FILE , 'midnight', 1, backupCount=10)
	formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
	loggerHandler.setFormatter(formatter)
	logger.addHandler(loggerHandler)
	logger.setLevel(logging.DEBUG)
except:
	print '------------------------------------------------------------------'
	print '[ERROR] Error writing log at %s' % INTERNAL_LOG_FILE
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

def genTiming():
	headers = {"Content-type": "application/json"}	
	try:
		response = requests.get(API_URL)
		#print "code:"+ str(response.status_code)
		#print "headers:"+ str(response.headers)
		#print "content:"+ str(response.text)
		timingXml = response.text
		e = xml.etree.ElementTree.parse(timingXml).getroot()
		for atype in e.findall('type'):
			print(atype.get('competitor'))

	except requests.ConnectionError as e:
		print "Error al llamar a la api:" + str(e)

genTiming()

'''
while True:
	array_list = []
	trackingInfo = getTiming()

	for tracking in trackingInfo:
		tracking_state = str(tracking[5])
		state = str(tracking[6])

		position = {"geometry": {"type": "Point", "coordinates": [ tracking[2] , tracking[1] ]}, "type": "Feature", "properties":{"alias":str(tracking[0]), "speed": str(tracking[3]), "heading": str(tracking[4]), "tracking_state":tracking_state, "vehicle_state":state, "alarm_state":str(tracking[7]), "license":str(tracking[8])}}
		array_list.append(position)

	with open('/var/www2/timig_wrc.json', 'w') as outfile:
		json.dump(array_list, outfile)
	
	time.sleep(1)
'''