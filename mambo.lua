--------------------------------------------------------------------------
--     Doug Haacke for TBS Mambo 128 x 64 for use with long range
--------------------------------------------------------------------------

------- GLOBALS -------
-- The model name when it can't detect a model name  from the handset
-- Mambo Voltage
local lowVoltage        = 3.2
local currentVoltage    = 4.2
local highVoltage       = 4.2
-- For our timer tracking
local timerLeft         = 0
local maxTimerValue     = 0
-- For armed status
local armed             = 0
local isArmed           = 0
-- For flight mode drawing
local mode              = 0
local modeText          = ''
-- Our global to get our link_quality
local linkQuality       = 0
-- Remember last good GPS coords
local prevGPSCoords     = ''

local logFilename       = "/LOGS/GPSpositions.txt"
local logWriteWaitTime  = 10
local oldTimeWrite      = 0
local oldTimeWrite2     = 0
local update            = true
local string_gmatch     = string.gmatch
local now               = 0
local ctr               = 0
local prevCoordinates   = 0
local currCoordinates   = 0
local wait              = 100

local gpsLAT            = 0
local gpsLON            = 0
local gpsLAT_H          = 0
local gpsLON_H          = 0
local gpsPrevLAT        = 0
local gpsPrevLON        = 0
local gpsSATS           = 0
local gpsFIX            = 0
local gpsDtH            = 0
local gpsTotalDist      = 0
local minSats           = 0


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

  -- Transitter Voltage 
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

local function processEvents(event)
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

local function rnd(v,d)
	if d then
		return math.floor((v*10^d)+0.5)/(10^d)
	else
		return math.floor(v+0.5)
	end
end

local function SecondsToClock(seconds)
  local seconds = tonumber(seconds)
  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));    
	return hours..":"..mins..":"..secs
  end
end

local function getTelemetryId(name)    
	field = getFieldInfo(name)
	if field then
		return field.id
	else
		return - 1
	end
end
------- END OF HELPERS -------


------- GPS HELPERS --------
local function write_log()
	now = getTime()
  if oldTimeWrite + logWriteWaitTime < now then
	  ctr = ctr + 1		
		timePowerOn = SecondsToClock(getGlobalTimer()["session"])
						
		file = io.open(logFilename, "a")    						
		io.write(file, currCoordinates ..",".. timePowerOn ..", "..  gpsSATS, "\r\n")			
		io.close(file)			

		if ctr >= 99 then
			ctr = 0				
			-- clear log
			file = io.open(logFilename, "w") 
			io.close(file)	
			-- reopen log for appending data
			file = io.open(logFilename, "a")    			
		end	
		oldTimeWrite = now
	end	
end


local function getTelemetryId(name)    
	field = getFieldInfo(name)
	if field then
		return field.id
	else
		return - 1
	end
end

local function gpsInit()
	gpsId = getTelemetryId("GPS")
	--number of satellites crossfire
	gpssatId = getTelemetryId("Sats")
end


----------------------------------------------------------------------
	-- get Latitude, Longitude
	----------------------------------------------------------------------
local function gpsBackground()	
  gpsLatLon = getValue(gpsId)
	if (type(gpsLatLon) == "table") then 			
		gpsLAT = rnd(gpsLatLon["lat"], 6)
		gpsLON = rnd(gpsLatLon["lon"], 6)			
		--set home postion only if more than 5 sats available
		if (tonumber(gpsSATS) > minSats) then
			gpsLAT_H = rnd(gpsLatLon["pilot-lat"], 6)
			gpsLON_H = rnd(gpsLatLon["pilot-lon"], 6)	
		end
		update = true	
	else
		update = false
	end
	
	----------------------------------------------------------------------
	-- get number of satellites and GPS fix type
	----------------------------------------------------------------------	
	gpsSATS = getValue(gpssatId)
    -- CROSSFIRE stores only the active GPS satellite
	gpsSATS = string.sub (gpsSATS, 0,3)		

	-- status message "guess"
	-- 2D Mode - A 2D (two dimensional) position fix that includes only horizontal coordinates. It requires a minimum of three visible satellites.)
	-- 3D Mode - A 3D (three dimensional) position fix that includes horizontal coordinates plus altitude. It requires a minimum of four visible satellites.
	if (tonumber(gpsSATS) < 2) then gpsFIX = "No GPS fix" end
	if (tonumber(gpsSATS) >= 3) and (tonumber(gpsSATS) <= 4)  then gpsFIX = "GPS 2D fix" end
	if (tonumber(gpsSATS) >= 5) then gpsFIX = "GPS 3D fix" end
		
	----------------------------------------------------------------------
    -- get calculated distance from home and write log
	----------------------------------------------------------------------		
	if (tonumber(gpsSATS) >= minSats) then
      if (gpsLAT ~= gpsPrevLAT) and (gpsLON ~=  gpsPrevLON) and (gpsLAT_H ~= 0) and  (gpsLON_H ~= 0) then		
        -- distance to home
        gpsDtH = rnd(calc_Distance(gpsLAT, gpsLON, gpsLAT_H, gpsLON_H),2)			
        gpsDtH = string.format("%.2f",gpsDtH)		
        -- total distance traveled					
        if (gpsPrevLAT ~= 0) and  (gpsPrevLON ~= 0) then	
          gpsTotalDist = rnd(tonumber(gpsTotalDist) + calc_Distance(gpsLAT, gpsLON, gpsPrevLAT, gpsPrevLON), 2)
          gpsTotalDist = string.format("%.2f",gpsTotalDist)					
        end
        prevCoordinates = string.format("%02d",ctr) ..", ".. gpsPrevLAT..", " .. gpsPrevLON
        currCoordinates = string.format("%02d",ctr+1) ..", ".. gpsLAT..", " .. gpsLON 
        gpsPrevLAT = gpsLAT
        gpsPrevLON = gpsLON

        write_log()
		  end 
	end

end
------- END OF GPS HELPERS --------


------- DRAW FUNCTIONS -------

local function drawFrames()
    -- Draw a horizontal line separating the header
    lcd.drawLine(0, 7, 128, 7, SOLID, FORCE)
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

local function drawDemo()
    lcd.drawText(0,   9, "RxBt: ", SMLSIZE)
    lcd.drawText(30,  9,  rnd(rxBat, 2), SMLSIZE)
    lcd.drawText(0,  19, "Bat_: ", SMLSIZE)
    lcd.drawText(30, 19,  rnd(bat, 1) .. "%", SMLSIZE)
    lcd.drawText(0,  29, "Arm: ", SMLSIZE)
    lcd.drawText(30, 29,  armed, SMLSIZE)
    lcd.drawText(0,  39, "Mode: ", SMLSIZE)
    lcd.drawText(30, 39,  modeText, SMLSIZE)
    lcd.drawText(30, 49,  gpsFIX, SMLSIZE)
    if (type(gpsLatLon) == "table") then
      lcd.drawText(0,  59, gpsLAT_H .. ", " .. gpsLON_H, SMLSIZE)
    end
    now = getTime()
    lcd.drawText(70,  9,  (oldTimeWrite + logWriteWaitTime), SMLSIZE)
    lcd.drawText(70, 19,  now, SMLSIZE)
end
------- END OF DRAW FUNCTIONS -------


local function gatherInput(event)

    -- Get the link quality
    linkQuality = getValue("RQly")
    -- Get the output power of the transmitter
    outputPower = getValue("TPWR")
    -- Get GPS values
    coords = getValue("GPS")
    -- Get the number of satellites
    sats = getValue("Sats")
    -- Get the distance
    dist = getValue("Dst")
    -- Get the altitude
    alt = getValue("Alt")
    -- Get the heading
    hdg = getValue("Hdg")
    -- Get the speed
    speed = getValue("GSpd")
    -- Get the Bat_
    bat = getValue("Bat_")
    -- Get the RxBt
    rxBat = getValue("RxBt")

    -- Get the seconds left in our timer
    timerLeft = getValue('timer1')
    -- And set our max timer if it's bigger than our current max timer
    if timerLeft > maxTimerValue then
      maxTimerValue = timerLeft
    end
    -- Get our current transmitter voltage
    currentVoltage = getValue('tx-voltage')
    -- Armed / Disarm / Reset
    armed = getValue("sd")
    reset = getValue('sd')
    -- Our "mode" switch
    mode = getValue('sb')
    -- Reset
    
    modeText = getModeText()
    
    -- Do some event handling to figure out what button(s) were pressed
    processEvents(event)

  end




  local function run(event)

    -- Now begin drawing...
    lcd.clear()
    -- lcd.drawText(46, 58, mode, SMLSIZE)

    -- Gather input from the user
    gatherInput(event)
      
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

    gpsBackground() 
  
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

    drawDemo()

    --reset telemetry data / total distance on "long press enter"
    if reset == 0 then
      gpsDtH          = 0
      gpsTotalDist    = 0
      gpsLAT_H        = 0
      gpsLON_H        = 0
    end 
    
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
  
  