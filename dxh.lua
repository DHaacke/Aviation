--------------------------------------------------------------------------
-- Adapted by Doug Haacke for TBS Mambo 128 x 64 for use with long range
--------------------------------------------------------------------------

-- Templating

-- If you set the GPS, it will not show Quad locator & Power ouput in order to keep a readable screen
local displayGPS          = true
local displayRssi         = true
local displayPowerOutput  = true

-- Will be displayed only if displayGPS, Quad locator and PowerOuput are set to false
local displayFillingText = true

------- GLOBALS -------
-- The model name when it can't detect a model name  from the handset
local modelName = "Unknown"
-- Tango2 Voltage
local lowVoltage    = 3.2
local currentVoltage = 4.2
local highVoltage = 4.2
-- For our timer tracking
local timerLeft = 0
local maxTimerValue = 0
-- For armed drawing
local armed = 0
-- For mode drawing
local mode = 0
-- Animation increment
local animationIncrement = 0
-- is off trying to go on...
local isArmed = 0
-- Our global to get our link_quality
local link_quality = 0
-- Remember last good GPS coords
local prevCoords = ''
-- For debugging / development
local lastMessage = "None"
local lastNumberMessage = "0"


------- HELPERS -------
-- Helper converts voltage to percentage of voltage for a sexy battery percent
local function convertVoltageToPercentage(voltage)
  local curVolPercent = math.ceil(((((highVoltage - voltage) / (highVoltage - lowVoltage)) - 1) * -1) * 100)
  if curVolPercent < 0 then
    curVolPercent = 0
  end
  if curVolPercent > 100 then
    curVolPercent = 100
  end
  return curVolPercent
end

-- A little animation / frame counter to help us with various animations
local function setAnimationIncrement()
  animationIncrement = math.fmod(math.ceil(math.fmod(getTime() / 100, 2) * 8), 4)
end

 
-- Sexy voltage helper
local function drawTransmitterVoltage(start_x,start_y,voltage)

  local batteryWidth = 17

  -- Battery Outline
  lcd.drawRectangle(start_x, start_y, batteryWidth + 2, 6, SOLID)
  lcd.drawLine(start_x + batteryWidth + 2, start_y + 1, start_x + batteryWidth + 2, start_y + 4, SOLID, FORCE) -- Positive Nub

  -- Battery Percentage (after battery)
  local curVolPercent = convertVoltageToPercentage(voltage)
  if curVolPercent < 20 then
    lcd.drawText(start_x + batteryWidth + 5, start_y, curVolPercent.."%", SMLSIZE + BLINK)
  else
    if curVolPercent == 100 then
      lcd.drawText(start_x + batteryWidth + 5, start_y, "99%", SMLSIZE)
    else
      lcd.drawText(start_x + batteryWidth + 5, start_y, curVolPercent.."%", SMLSIZE)
    end

  end

  -- Filled in battery
  local pixels = math.ceil((curVolPercent / 100) * batteryWidth)
  if pixels == 1 then
    lcd.drawLine(start_x + pixels, start_y + 1, start_x + pixels, start_y + 4, SOLID, FORCE)
  end
  if pixels > 1 then
    lcd.drawRectangle(start_x + 1, start_y + 1, pixels, 4)
  end
  if pixels > 2 then
    lcd.drawRectangle(start_x + 2, start_y + 2, pixels - 1, 2)
    lcd.drawLine(start_x + pixels, start_y + 2, start_x + pixels, start_y + 3, SOLID, FORCE)
  end
end

local function drawFlightTimer(start_x, start_y)
  local timerWidth  = 44
  local timerHeight = 15
  local myWidth     = 0
   
  -- lcd.drawFilledRectangle( start_x - 4, start_y + 11, start_x + (timerWidth - 5), start_y + (timerHeight - 10), SOLID)
  -- lcd.drawRectangle( start_x - 5, start_y + 11, 128, start_y + (timerHeight - 10), SOLID )

  if timerLeft < 0 then
    -- lcd.drawRectangle( start_x + 2, start_y + 20, 3, 2, SOLID )
    lcd.drawText( start_x - 3, start_y + 12, " Land ", MIDSIZE)
  else
    lcd.drawTimer( start_x + 2, start_y + 12, timerLeft, MIDSIZE + FORCE)
  end

  -- local offset = 0
  -- while offset < (timerHeight) do
  --   lcd.drawLine( start_x + 1, start_y + offset, start_x + timerWidth, start_y + offset, SOLID, FORCE)
  --   offset = offset + 1
  -- end

end

local function drawTime()
  -- Draw date time
  local datenow = getDateTime()
  local min = datenow.min .. ""
  if datenow.min < 10 then
    min = "0" .. min
  end
  local hour = datenow.hour .. ""
  if datenow.hour < 10 then
    hour = "0" .. hour
  end
  if math.ceil(math.fmod(getTime() / 100, 2)) == 1 then
    hour = hour .. ":"
  end
  lcd.drawText(107,0,hour, SMLSIZE)
  lcd.drawText(119,0,min, SMLSIZE)
end

local function drawLinkQuality(start_x, start_y)
  local timerWidth  = 44
  local timerHeight = 15
  local myWidth = 0
  local percentageLeft = 0

  lcd.drawText( start_x + 2, start_y + 3, "LQ", SMLSIZE)
  if link_quality < 60 then
    lcd.drawText( start_x + 23, start_y + 3, link_quality, SMLSIZE + BLINK)
  else
    lcd.drawText( start_x + 23, start_y + 3, link_quality, SMLSIZE)
  end
 end

local function drawVoltageText(start_x, start_y)
  -- First, try to get voltage from VFAS...
  local voltage = getValue('RxBt')
  -- local voltage = getValue('Cels')   -- For miniwhoop seems more accurate
  -- TODO: if that failed, get voltage from somewhere else from my bigger quads?  Or rebind the voltage to VFAS?

  if tonumber(voltage) >= 10 then
    lcd.drawText(start_x,start_y,string.format("%.2f", voltage),MIDSIZE)
  else
    lcd.drawText(start_x + 7,start_y,string.format("%.2f", voltage),MIDSIZE)
  end
  lcd.drawText(start_x + 31, start_y + 4, 'v', MEDSIZE)
end

local function drawPower(start_x, start_y, output_power)
  -- lcd.drawPixMap(start_x, start_y, "/test.bmp")
  -- lcd.drawRectangle( start_x, start_y, 44, 10 )
  lcd.drawText( start_x + 3, start_y + 3, "Tx Power", SMLSIZE )
  -- lcd.drawRectangle( start_x, start_y + 10, 44, 15 )
  if output_power == 0 then
    lcd.drawText(start_x + 5, start_y + 12, output_power, MIDSIZE + BLINK)
  else
    lcd.drawText(start_x + 5, start_y + 12, output_power, MIDSIZE)
  end
end

local function drawRssiDbm(start_x, start_y, rssi_dbm)
  -- lcd.drawPixMap(start_x, start_y, "/test.bmp")
  lcd.drawText( start_x + 2, start_y + 2, "Quad Locator", SMLSIZE )
  lcd.drawGauge( start_x, start_y + 10, 64, 15, rssi_dbm, 100 )
  --  lcd.drawText(start_x + 5, start_y + 12, rssi_dbm, DBLSIZE)
end

local function drawSendIt(start_x, start_y, rssi_dbm)
  -- lcd.drawPixMap(start_x, start_y, "/test.bmp")
  lcd.drawText( start_x + 2, start_y + 2, "Send It !", DBLSIZE )

end

local function drawVoltageImage(start_x, start_y)

  -- Define the battery width (so we can adjust it later)
  local batteryWidth = 12

  -- Draw our battery outline
  lcd.drawLine(start_x + 2, start_y + 1, start_x + batteryWidth - 2, start_y + 1, SOLID, 0)
  lcd.drawLine(start_x, start_y + 2, start_x + batteryWidth - 1, start_y + 2, SOLID, 0)
  lcd.drawLine(start_x, start_y + 2, start_x, start_y + 50, SOLID, 0)
  lcd.drawLine(start_x, start_y + 50, start_x + batteryWidth - 1, start_y + 50, SOLID, 0)
  lcd.drawLine(start_x + batteryWidth, start_y + 3, start_x + batteryWidth, start_y + 49, SOLID, 0)

  -- top one eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 8, start_x + batteryWidth - 1, start_y + 8, SOLID, 0)
  -- top quarter line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 2), start_y + 14, start_x + batteryWidth - 1, start_y + 14, SOLID, 0)
  -- third eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 20, start_x + batteryWidth - 1, start_y + 20, SOLID, 0)
  -- Middle line
  lcd.drawLine(start_x + 1, start_y + 26, start_x + batteryWidth - 1, start_y + 26, SOLID, 0)
  -- five eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 32, start_x + batteryWidth - 1, start_y + 32, SOLID, 0)
  -- bottom quarter line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 2), start_y + 38, start_x + batteryWidth - 1, start_y + 38, SOLID, 0)
  -- seven eighth line
  lcd.drawLine(start_x + batteryWidth - math.ceil(batteryWidth / 4), start_y + 44, start_x + batteryWidth - 1, start_y + 44, SOLID, 0)

  -- Voltage top
  lcd.drawText(start_x + batteryWidth + 4, start_y + 0,  "4.2v", SMLSIZE)
  -- Voltage mid-top
  lcd.drawText(start_x + batteryWidth + 4, start_y + 12, "3.8v", SMLSIZE)
  -- Voltage middle
  lcd.drawText(start_x + batteryWidth + 4, start_y + 24, "3.6v", SMLSIZE)  -- 3.9
  -- Voltage bottom
  lcd.drawText(start_x + batteryWidth + 4, start_y + 45, "3.2v", SMLSIZE)  -- 3.7

  -- Now draw how full our voltage is...
  local voltage = getValue('RxBt')
  voltageLow  = 3.20  -- 3.8
  voltageHigh = 4.20
  voltageIncrement = ((voltageHigh - voltageLow) / 47)  -- (4.2 - 3.8) / 47 = 0.008510638298

  local offset = 0  -- Start from the bottom up
  while offset < 47 do
    if ((offset * voltageIncrement) + voltageLow) < tonumber(voltage) then
      lcd.drawLine( start_x + 1, start_y + 49 - offset, start_x + batteryWidth - 1, start_y + 49 - offset, SOLID, 0)
    end
    offset = offset + 1
  end
end

local function gatherInput(event)

  -- Get our link_quality
  link_quality = getValue("RQly")
  -- Get the Output power of the transmitter
  output_power = getValue("TPWR")
  -- Get the downlink RSSI to be able to find the quad
  rssi_dbm = getValue("TSNR")
  -- Get GPS values
  coords = getValue("GPS")
  -- Get the number of satellites
  sats = getValue("Sats")
  -- Get the distance
  dist = getValue("Dst")
  -- Get the altitude
  alt = getValue("Alt")

  -- Get the seconds left in our timer
  timerLeft = getValue('timer1')
  -- And set our max timer if it's bigger than our current max timer
  if timerLeft > maxTimerValue then
    maxTimerValue = timerLeft
  end

  -- Get our current transmitter voltage
  currentVoltage = getValue('tx-voltage')









  -- Armed / Disarm
  -- armed = getValue('sf')
  armed = getValue("sd")

  -- Our "mode" switch
  mode = getValue('sb')
  



  -- Do some event handling to figure out what button(s) were pressed  :)
  if event > 0 then
    lastNumberMessage = event
  end

  if event == 131 then
    lastMessage = "Page Button HELD"
    killEvents(131)
  end
  if event == 99 then
    lastMessage = "Page Button Pressed"
    killEvents(99)
  end
  if event == 97 then
    lastMessage = "Exit Button Pressed"
    killEvents(97)
  end

  if event == 96 then
    lastMessage = "Menu Button Pressed"
    killEvents(96)
  end

  if event == EVT_ROT_RIGHT then
    lastMessage = "Navigate Right Pressed"
    killEvents(EVT_ROT_RIGHT)
  end
  if event == EVT_ROT_LEFT then
    lastMessage = "Navigate Left Pressed"
    killEvents(EVT_ROT_LEFT)
  end
  if event == 98 then
    lastMessage = "Navigate Button Pressed"
    killEvents(98)
  end

end


local function getModeText()
  local modeText = "Unknown"
  if mode < 0 then
    modeText = "Acro"
  elseif mode == 0 then
    modeText = "Horizon"
  elseif mode > 0 then
    modeText = "Turtle"
  end
  return modeText
end

local function drawGPS(start_x, start_y, coords)
  lcd.drawText( start_x, start_y, "Sats", SMLSIZE)
  if sats < 5 then
    lcd.drawText( start_x, start_y + 8, sats, SMLSIZE + BLINK)
  else
    lcd.drawText( start_x, start_y + 8, sats, SMLSIZE)
  end
  lcd.drawText( start_x + 26, start_y, "Dist", SMLSIZE )
  lcd.drawText( start_x + 26, start_y + 8,  dist, SMLSIZE )

  lcd.drawText( start_x + 56, start_y, "Alti", SMLSIZE )
  lcd.drawText( start_x + 56, start_y + 8, alt, SMLSIZE )
  
  
  if (type(coords) == "table") then
    lcd.drawText(start_x + 6, start_y + 16, coords["lat"] .. " N", SMLSIZE)
    lcd.drawText(start_x + 6, start_y + 24, coords["lon"] .. " W", SMLSIZE)
    prevCoords = coords
  else
    if (type(prevCoords) == "table") then
      lcd.drawText(start_x + 6, start_y + 16, prevCoords["lat"] .. " N", SMLSIZE)
      lcd.drawText(start_x + 6, start_y + 24, prevCoords["lon"] .. " W", SMLSIZE)
    end
  end
end

local function drawFrames()
  -- Draw a horizontal line separating the header
  lcd.drawLine(0, 7, 128, 7, SOLID, FORCE)
  -- draw the Tx Power label rect
  lcd.drawRectangle( 40, 8, 44, 10 )
  -- draw the LQ label rect
  lcd.drawRectangle( 84, 8, 44, 10 )
  -- draw the Tx Power rect
  lcd.drawRectangle( 40, 18, 44, 14 )
  -- draw the Timer rect
  lcd.drawRectangle( 84, 18, 44, 14 )
  lcd.drawFilledRectangle( 84, 18, 44, 14, SOLID)
end

local function run(event)

  -- Now begin drawing...
  lcd.clear()

  -- lcd.drawText(46, 58, mode, SMLSIZE)

  -- Gather input from the user
  gatherInput(event)

  -- Set our animation "frame"
  setAnimationIncrement()


  -- Check if we just armed... this only works for the momentary switch
  if armed < 0 then
    isArmed = 1
  else
    isArmed = 0
  end
  if isArmed == 1 then
    modeText = "Armed"
    lcd.drawText( 64 - math.ceil((#modeText * 5) / 2),0, modeText, SMLSIZE + BLINK)
  else
    modeText = "Disarmed"
    lcd.drawText( 64 - math.ceil((#modeText * 5) / 2),0, modeText, SMLSIZE)
  end
  -- armText = getValue("ls03")

  -- draw the pertinent lines and rectangles
  drawFrames()

  -- draw the flight mode at the top center
  -- modeText = getModeText()
  -- if isArmed == 1 then
  --   lcd.drawText( 64 - math.ceil((#modeText * 5) / 2),0, modeText, SMLSIZE + BLINK)
  -- else
  --  lcd.drawText( 64 - math.ceil((#modeText * 5) / 2),0, modeText, SMLSIZE)
  -- end
  
  -- draw our sexy voltage
  drawTransmitterVoltage(0,0, currentVoltage)
  -- draw Time in Top Right
  drawTime()

  -- draw the tx power value
  drawPower(40, 7, output_power)
    -- Draw link_quality
  drawLinkQuality(84, 7)
  -- draw the flight timer
  drawFlightTimer(88, 7)

  -- draw battery voltage graphic
  drawVoltageImage(3, 10)

  -- draw GOS info
  drawGPS(40, 34, coords)


  -- if (type(coords) == "table") then
  --   lcd.drawText(40, 34, coords["lat"] .. " N", SMLSIZE)
  --   lcd.drawText(40, 46, coords["lon"] .. " W", SMLSIZE)
  -- end
  

  return 0
end


local function init_func()
  -- Called once when model is loaded, only need to get model name once...
  local modeldata = model.getInfo()
  if modeldata then
    modelName = modeldata['name']
  end
end


return { run=run, init=init_func  }
