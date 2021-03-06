import ConfigParser
import json
import datetime
import time
import email.utils

purgeList = []
allMessages = []

def _sendMessage(toAddress, fromAddress, subject, body):
	try:
		return app.api.sendMessage(toAddress, fromAddress, subject, body)
	except:
		return 0

def _sendBroadcast(fromAddress, subject, body):
	try:
		return app.api.sendBroadcast(fromAddress, subject, body)
	except:
		return 0

def send(toAddress, fromAddress, subject, body):
	subject = subject.encode('base64')
	body = body.encode('base64')
	if toAddress == 'broadcast':
		return _sendBroadcast(fromAddress, subject, body)
	else:
		return _sendMessage(toAddress, fromAddress, subject, body)

def _getAll():
	global allMessages
	if not allMessages:
		allMessages = json.loads(app.api.getAllInboxMessages())
	return allMessages

def get(msgID):
	inboxMessages = _getAll()
	dateTime = email.utils.formatdate(time.mktime(datetime.datetime.fromtimestamp(float(inboxMessages['inboxMessages'][msgID]['receivedTime'])).timetuple()))
	toAddress = inboxMessages['inboxMessages'][msgID]['toAddress'] + '@bm.addr'
	fromAddress = inboxMessages['inboxMessages'][msgID]['fromAddress'] + '@bm.addr'
	subject = inboxMessages['inboxMessages'][msgID]['subject'].decode('base64')
	body = inboxMessages['inboxMessages'][msgID]['message'].decode('base64')
	return dateTime, toAddress, fromAddress, subject, body

def listMsgs():
	inboxMessages = _getAll()
	return len(inboxMessages['inboxMessages'])

def markForDelete(msgID):
	global purgeList
	inboxMessages = _getAll()
	msgRef = str(inboxMessages['inboxMessages'][msgID]['msgid'])
	purgeList.append(msgRef)
	return 0

def cleanup():
	global allMessages
	global purgeList
	while len(purgeList):
		_deleteMessage(purgeList.pop())
	allMessages = []
	return 0

def _deleteMessage(msgRef):
	app.api.trashMessage(msgRef)
	return 0 

def getUIDLforAll():
	inboxMessages = json.loads(app.api.getAllInboxMessages())
	refdata = []
	for msgID in range(len(inboxMessages['inboxMessages'])):
		msgRef = inboxMessages['inboxMessages'][msgID]['msgid'] #gets the message Ref via the message index number
		refdata.append(str(msgRef))
	return refdata #api.trashMessage(msgRef) #TODO uncomment this to allow deletion

def getUIDLforSingle(msgID):
	inboxMessages = json.loads(app.api.getAllInboxMessages())
	msgRef = inboxMessages['inboxMessages'][msgID]['msgid'] #gets the message Ref via the message index number
	return [str(msgRef)]

