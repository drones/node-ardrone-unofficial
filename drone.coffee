
dgram = require 'dgram'
net = require 'net'
{timeoutSet, intervalSet} = require './util'


DRONE_HOST   = '192.168.1.1'
COMMAND_PORT = 5556
CONTROL_PORT = 5559
NAVDATA_PORT = 5554
VIDEO_PORT   = 5555


[PMODE, MISC, REF, CONFIG, PCMD] = [1, 2, 3, 4, 5]
MESSAGE_NAMES = ['', 'PMODE', 'MISC', 'REF', 'CONFIG', 'PCMD']
MESSAGE_ARITIES = [0, 1, 4, 1, 2, 5]

LAND = 290717696
TAKEOFF = 290718208


exports.Drone = class Drone

  constructor: () ->

    @seq = 0

    @commandClient = dgram.createSocket 'udp4'
    @commandClient.bind COMMAND_PORT

    @controlClient = null

    @navdataServer = dgram.createSocket 'udp4', (data) =>
      console.log "Got navdata"
    @navdataServer.addMembership '224.1.1.1'
    @navdataServer.bind NAVDATA_PORT

    @videoServer = dgram.createSocket 'udp4', (data) =>
      console.log "Got video"
    @videoServer.bind VIDEO_PORT

  nextSeq: () ->
    @seq++
    @seq

  awaken: () ->

    @t0 = new Date().getTime()

    # First contact
    @send(
      PMODE, 2,
      MISC, 2, 20, 2000, 3000,
      REF, 290717696)

    @interval = intervalSet 25, () => @send REF, LAND
    timeoutSet 1000, () =>
      clearInterval @interval

      # Show us the data!
      @send CONFIG, "general:navdata_demo", "TRUE"
      data = new Buffer [2, 0, 0, 0]
      @commandClient.send data, 0, data.length, NAVDATA_PORT, DRONE_HOST

      # Open control connection
      @controlClient = net.createConnection CONTROL_PORT, DRONE_HOST
      
      @interval = intervalSet 25, () => @send REF, LAND

  takeoff: () ->
    @send REF, TAKEOFF
    if @interval
      clearInterval @interval
    @interval = intervalSet 25, () => @send TAKEOFF

  land: () ->
    if @interval
      clearInterval @interval
    @interval = intervalSet 25, () => @send REF, LAND

  sendEmergency: () ->
    @send REF, 0, REF, 256, REF, 0

  send: () ->

    arr = []
    pos = 0
    numArgsMinusOne = arguments.length - 1
    while pos < numArgsMinusOne
      typeNum = arguments[pos]
      arr.push "AT*#{MESSAGE_NAMES[typeNum]}=#{@nextSeq()}"
      pos++
      for i in [0...MESSAGE_ARITIES[typeNum]]
        arr.push ","
        x = arguments[pos]
        if (typeof x) == 'string'
          arr.push '"' + x + '"'
        else
          arr.push x
        pos++
      arr.push '\r'
    message = new Buffer arr.join ''

    @commandClient.send message, 0, message.length, COMMAND_PORT, DRONE_HOST

