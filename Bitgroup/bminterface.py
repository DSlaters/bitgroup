import ConfigParser
import xmlrpclib
import json
import datetime
import time
import email.utils

purgeList = []
allMessages = []
    
def _sendMessage(toAddress, fromAddress, subject, body):
    api = _makeApi(_getKeyLocation())
    try:
      return api.sendMessage(toAddress, fromAddress, subject, body)
    except:
      return 0
      
def _sendBroadcast(fromAddress, subject, body):
    api = _makeApi(_getKeyLocation())
    try:
      return api.sendBroadcast(fromAddress, subject, body)
    except:
      return 0
      
def _stripAddress(address):
    if 'broadcast' in address.lower():
      return 'broadcast'

    orig = address
    alphabet = '123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
    retstring = ''
    while address:
      if address[:3] == 'BM-':
        retstring = 'BM-'
        address = address[3:]
        while address[0] in alphabet:
          retstring += address[0]
          address = address[1:]
      else:
        address = address[1:]
    print "converted address " + orig + " to " + retstring
    return retstring

def send(toAddress, fromAddress, subject, body):
    toAddress = _stripAddress(toAddress)
    fromAddress = _stripAddress(fromAddress)
    subject = subject.encode('base64')
    body = body.encode('base64')
    if toAddress == 'broadcast':
      return _sendBroadcast(fromAddress, subject, body)
    else:
      return _sendMessage(toAddress, fromAddress, subject, body)

def _getAll():
    global allMessages
    if not allMessages:
      api = _makeApi(_getKeyLocation())
      allMessages = json.loads(api.getAllInboxMessages())
    return allMessages

def get(msgID):
    inboxMessages = _getAll()
    dateTime = email.utils.formatdate(time.mktime(datetime.datetime.fromtimestamp(float(inboxMessages['inboxMessages'][msgID]['receivedTime'])).timetuple()))
    toAddress = inboxMessages['inboxMessages'][msgID]['toAddress'] + '@bm.addr'
    fromAddress = inboxMessages['inboxMessages'][msgID]['fromAddress'] + '@bm.addr'

    ##Disabled to support new chan format
    #if 'Broadcast' in toAddress:
    #  toAddress = fromAddress

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
    api = _makeApi(_getKeyLocation())
    api.trashMessage(msgRef) #TODO uncomment this to allow deletion 
    return 0 
    
def getUIDLforAll():
    api = _makeApi(_getKeyLocation())
    inboxMessages = json.loads(api.getAllInboxMessages())
    refdata = []
    for msgID in range(len(inboxMessages['inboxMessages'])):
      msgRef = inboxMessages['inboxMessages'][msgID]['msgid'] #gets the message Ref via the message index number
      refdata.append(str(msgRef))
    return refdata #api.trashMessage(msgRef) #TODO uncomment this to allow deletion
    
def getUIDLforSingle(msgID):
    api = _makeApi(_getKeyLocation())
    inboxMessages = json.loads(api.getAllInboxMessages())
    msgRef = inboxMessages['inboxMessages'][msgID]['msgid'] #gets the message Ref via the message index number
    return [str(msgRef)]
