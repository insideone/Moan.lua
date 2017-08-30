--
-- Möan.lua
--
-- Copyright (c) 2017 twentytwoo
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local PATH = (...):match('^(.*[%./])[^%.%/]+$') or ''
Moan = {
	indicatorCharacter = ">",	-- Next message indicator
	indicatorDelay = 15,		-- Delay between each flash of indicator
	selectButton = "space",		-- Key that advances message
	typeSpeed = 0.01,			-- Delay per character typed out
	debug = true,				-- Display some debugging

	currentMessage  = "",
	currentMsgInstance = 1, 	-- The Moan.new function instance
	currentMsgKey= 1,			-- Key of value in the Moan.new messages
	currentOption = 1,			-- Key of option function in Moan.new option array
	currentImage = nil,			-- Avatar image

	_VERSION     = '0.2.5',
	_URL         = 'https://github.com/twentytwoo/Moan.lua',
	_DESCRIPTION = 'A simple visual-novel messagebox for LÖVE',
}

-- Require libs
local utf8 = require("utf8")

-- Create the message instance container
allMessages = {}

local printedText  = "" -- Section of the text printed so far
-- Timer to know when to print a new letter
local typeTimer    = Moan.typeSpeed
local typeTimerMax = Moan.typeSpeed
-- Current position in the text
local typePosition = 0
-- Initialise timer for the indicator
local indicatorTimer = 0
local defaultFont = love.graphics.newFont()
local colors = {
	red    = {255, 0, 0},
	blue   = {0, 0, 255},
	yellow = {255, 255, 0}
}

if Moan.font == nil then
	Moan.font = defaultFont
end

function Moan.new(title, messages, config)
	-- Config checking / defaulting
	config = config or {}
	x = config.x or 0
	y = config.y or 0
	image = config.image or "nil"
	options = config.options or {{"",function()end},{"",function()end},{"",function()end}}
	onstart = config.onstart or function() end
	oncomplete = config.oncomplete or function() end
	if image == nil or love.filesystem.exists(image) == false then
		image = "Moan/noImg.png"
	end

	-- Insert the Moan.new into its own instance (table)
	allMessages[#allMessages+1] = { title=title, messages=messages, x=x, y=y, image=image, options=options, onstart=onstart, oncomplete=oncomplete }

	-- Set the last message as "\n", an indicator to change currentMsgInstance
	allMessages[#allMessages].messages[#messages+1] = "\n"
	Moan.showingMessage = true

	-- Only run .onstart()/setup if first message instance on first Moan.new
	-- Prevents oncomplete=Moan.new(... recursion crashing the game.
	if Moan.currentMsgInstance == 1 then
		-- Set the first message up, after this is set up via advanceMsg()
		typePosition = 0
		Moan.currentMessage = allMessages[Moan.currentMsgInstance].messages[Moan.currentMsgKey]
		Moan.currentTitle = allMessages[Moan.currentMsgInstance].title
		Moan.currentImage = love.graphics.newImage(allMessages[Moan.currentMsgInstance].image)
		Moan.showingOptions = false
		-- Run the first startup function
		allMessages[Moan.currentMsgInstance].onstart()
	end
end

function Moan.update(dt)
	-- Check if the output string is equal to final string, else we must be still typing it
	if printedText == Moan.currentMessage then
		typing = false else typing = true
	end

	if Moan.showingMessage then
		-- Tiny timer for the message indicator
		if (Moan.paused or not typing) then
			indicatorTimer = indicatorTimer + 1
			if indicatorTimer > Moan.indicatorDelay then
				Moan.showIndicator = not Moan.showIndicator
				indicatorTimer = 0
			end
		else
			Moan.showIndicator = false
		end

		-- Check if we're on the 2nd to last message in the instance, on the next advance we should be able to select an option
		-- Be wary of updating the camera every dt..
		Moan.moveCamera()
		if allMessages[Moan.currentMsgInstance].messages[Moan.currentMsgKey+1] == "\n" then
			Moan.showingOptions = true
		end
		if Moan.showingOptions then
			-- Constantly update the option prefix
			for i=1, 3 do
				-- Remove the indicators from other selections
				allMessages[Moan.currentMsgInstance].options[i][1] = string.gsub(allMessages[Moan.currentMsgInstance].options[i][1], Moan.indicatorCharacter.." " , "")
			end
			-- Add an indicator to the current selection
			if allMessages[Moan.currentMsgInstance].options[Moan.currentOption][1] ~= "" then
				allMessages[Moan.currentMsgInstance].options[Moan.currentOption][1] = Moan.indicatorCharacter.." ".. allMessages[Moan.currentMsgInstance].options[Moan.currentOption][1]
			end
		end

		-- Detect a 'pause' by checking the content of the last two characters in the printedText
		if string.sub(Moan.currentMessage, string.len(printedText)+1, string.len(printedText)+2) == "--" then
			Moan.paused = true
			else Moan.paused = false
		end

		--https://www.reddit.com/r/love2d/comments/4185xi/quick_question_typing_effect/
		if typePosition <= string.len(Moan.currentMessage) then

		    -- Only decrease the timer when not paused
		    if not Moan.paused then
			    typeTimer = typeTimer - dt
			end

		    -- Timer done, we need to print a new letter:
		    -- Adjust position, use string.sub to get sub-string
		    if typeTimer <= 0 then
		    	-- Check if we have an audio file
	        	if type(Moan.typeSound) == "userdata" then
		    	-- Only make the keypress sound if the next character is a letter
			        if string.sub(Moan.currentMessage, typePosition, typePosition) ~= " " and typing then
						Moan.typeSound:play()
			        end
				end
		        typeTimer = typeTimerMax
		        typePosition = typePosition + 1

		        -- UTF8 support, thanks @FluffySifilis
				local byteoffset = utf8.offset(Moan.currentMessage, typePosition)
				if byteoffset then
					printedText = string.sub(Moan.currentMessage, 0, byteoffset - 1)
				end
		    end
		end
	end
end

function Moan.advanceMsg()
	if Moan.showingMessage then
		-- Check if we're at the last message in the instances queue (+1 because "\n" indicated end of instance)
		if allMessages[Moan.currentMsgInstance].messages[Moan.currentMsgKey+1] == "\n" then
			-- Last message in instance, so run the final function.
			allMessages[Moan.currentMsgInstance].oncomplete()

			-- Check if we're the last instance in allMessages
			if allMessages[Moan.currentMsgInstance+1] == nil then
				Moan.currentMsgInstance = 1
				Moan.currentMsgKey = 1
				Moan.currentOption = 1
				typing = false
				Moan.showingMessage = false
				typePosition = 0
				Moan.showingOptions = false
				allMessages = {}
			else
				-- We're not the last instance, so we can go to the next one
				-- Reset the msgKey such that we read the first msg of the new instance
				Moan.currentMsgInstance = Moan.currentMsgInstance + 1
				Moan.currentMsgKey = 1
				Moan.currentOption = 1
				typePosition = 0
				Moan.showingOptions = false
				Moan.moveCamera()
			end
		else
			-- We're not the last message and we can show the next one
			-- Reset type position to restart typing
			typePosition = 0
			Moan.currentMsgKey = Moan.currentMsgKey + 1
		end
	end

	-- Check showingMessage - throws an error if next instance is nil
	if Moan.showingMessage then
		if Moan.currentMsgKey == 1 then
			allMessages[Moan.currentMsgInstance].onstart()
		end
		Moan.currentMessage = allMessages[Moan.currentMsgInstance].messages[Moan.currentMsgKey] or ""
		Moan.currentTitle = allMessages[Moan.currentMsgInstance].title or ""
		Moan.currentImage = love.graphics.newImage(allMessages[Moan.currentMsgInstance].image)
	end
end

function Moan.draw()
	love.graphics.setDefaultFilter( "nearest", "nearest")
	if Moan.showingMessage then
		local scale = 0.30
		local padding = 10
		local boxH = 133
		local boxW = love.graphics.getWidth()-(2*padding)
		local boxX = padding
		local boxY = love.graphics.getHeight()-(boxH+padding)
		local imgX = (boxX+padding)*(1/scale)
		local imgY = (boxY+padding)*(1/scale)
		local imgW = Moan.currentImage:getWidth()
		local imgH = Moan.currentImage:getHeight()
		local textX = (imgX+imgW)/(1/scale)+padding
		local textY = boxY+padding
		local msgTextY = textY+Moan.font:getHeight()
		local msgLimit = boxW-(imgW/(1/scale))-(2*padding)
		local fontColour = { 255, 255, 255, 255 }
		local boxColour = { 0, 0, 0, 222 }
		love.graphics.setColor(boxColour)
		love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
		love.graphics.setColor(fontColour)
		love.graphics.push()
			love.graphics.scale(scale, scale)
			love.graphics.draw(Moan.currentImage, imgX, imgY)
		love.graphics.pop()
		love.graphics.setFont(Moan.font)
		love.graphics.printf(Moan.currentTitle, textX, textY, boxW)
		love.graphics.printf(printedText, textX, msgTextY, msgLimit)
		if Moan.showingOptions and typing == false then
			love.graphics.print(allMessages[Moan.currentMsgInstance].options[1][1], textX+padding, msgTextY+1*(2.4*padding))
			love.graphics.print(allMessages[Moan.currentMsgInstance].options[2][1], textX+padding, msgTextY+2*(2.4*padding))
			love.graphics.print(allMessages[Moan.currentMsgInstance].options[3][1], textX+padding, msgTextY+3*(2.4*padding))
		end
		if Moan.showIndicator then
			love.graphics.print(">", boxX+boxW-(2.5*padding), boxY+boxH-(3*padding))
		end
	end
	-- Reset fonts
	love.graphics.setFont(defaultFont)
	if Moan.debug then
		Moan.debug()
	end
end

function Moan.keyreleased(key)
	if Moan.showingOptions then
		if key == Moan.selectButton and not typing then
			if Moan.currentOption == 1 then
				-- First key is option (string), 2nd is function
				-- options[option][function]
				allMessages[Moan.currentMsgInstance].options[1][2]()
			elseif Moan.currentOption == 2 then
				allMessages[Moan.currentMsgInstance].options[2][2]()
			elseif Moan.currentOption == 3 then
				allMessages[Moan.currentMsgInstance].options[3][2]()
			end
		-- Option selection
		elseif key == "down" or key == "s" then
			Moan.currentOption = Moan.currentOption + 1
		elseif key == "up" or key == "w" then
			Moan.currentOption = Moan.currentOption - 1
		end
		-- Return to top/bottom of options on overflow
		if Moan.currentOption < 1 then
			Moan.currentOption = 3
		elseif Moan.currentOption > 3 then
			Moan.currentOption = 1
		end
	end
	-- Check if we're still typing, if we are we can skip it
	-- If not, then go to next message/instance
	if key == Moan.selectButton then
		if Moan.paused then
			-- Get the text left and right of "--"
			leftSide = string.sub(Moan.currentMessage, 1, string.len(printedText))
			rightSide = string.sub(Moan.currentMessage, string.len(printedText)+3, string.len(Moan.currentMessage))
			-- And then concatenate them, thanks @pfirsich
			Moan.currentMessage = leftSide .. " " .. rightSide
			-- Put the typerwriter back a bit and start up again
			typePosition = typePosition - 1
			typeTimer = 0
		else
			if typing == true then
				-- Skip the typing completely
				printedText = Moan.currentMessage
				typePosition = string.len(Moan.currentMessage)
			else
				Moan.advanceMsg()
			end
		end
	end
end

function Moan.setSpeed(speed)
	if speed == "fast" then
		Moan.typeSpeed = 0.01
	elseif speed == "medium" then
		Moan.typeSpeed = 0.04
	elseif speed == "slow" then
		Moan.typeSpeed = 0.08
	else
		assert(tonumber(speed), "Moan.setSpeed() - Expected number, got " .. tostring(speed))
		Moan.typeSpeed = speed
	end
	-- Update the timeout timer.
	typeTimerMax = Moan.typeSpeed
end

function Moan.setCamera(camToUse)
	Moan.currentCamera = camToUse
end

function Moan.moveCamera()
	-- Only move the camera if one exists
	if Moan.currentCamera ~= nil then
		-- Move the camera to the new instances position
		if (allMessages[Moan.currentMsgInstance].x and allMessages[Moan.currentMsgInstance].y) ~= nil then
			flux.to(Moan.currentCamera, 1, { x = allMessages[Moan.currentMsgInstance].x, y = allMessages[Moan.currentMsgInstance].y }):ease("cubicout")
		end
	end
end

function Moan.clearMessages()
	Moan.showingMessage = false	-- Prevents crashing
	allMessages = {}
end

function Moan.debug()
	log = { -- literally the poorest solution on gods green earth.
		"typing", typing,
		"paused", Moan.paused,
		"indicatorTimer", indicatorTimer,
		"showIndicator", Moan.showIndicator,
		"printedText", printedText,
		"textToPrint", Moan.currentMessage,
		"currentMsgInstance", Moan.currentMsgInstance,
		"currentMsgKey", Moan.currentMsgKey,
		"currentOption", Moan.currentOption,
		"currentHeader", utf8.sub(Moan.currentMessage, utf8.len(printedText)+1, utf8.len(printedText)+2),
		"typeSpeed", Moan.typeSpeed,
		"typeSound", type(Moan.typeSound) .. " " .. tostring(Moan.typeSound)
	}
	for i=1, #log, 2 do
		love.graphics.print(tostring(log[i]) .. ":  " .. tostring(log[i+1]), 10, 7*i)
	end
end

-- External UTF8 functions
-- https://github.com/alexander-yakushev/awesompd/blob/master/utf8.lua
function utf8.charbytes (s, i)
   -- argument defaults
   i = i or 1
   local c = string.byte(s, i)

   -- determine bytes needed for character, based on RFC 3629
   if c > 0 and c <= 127 then
      -- UTF8-1
      return 1
   elseif c >= 194 and c <= 223 then
      -- UTF8-2
      local c2 = string.byte(s, i + 1)
      return 2
   elseif c >= 224 and c <= 239 then
      -- UTF8-3
      local c2 = s:byte(i + 1)
      local c3 = s:byte(i + 2)
      return 3
   elseif c >= 240 and c <= 244 then
      -- UTF8-4
      local c2 = s:byte(i + 1)
      local c3 = s:byte(i + 2)
      local c4 = s:byte(i + 3)
      return 4
   end
end

function utf8.sub (s, i, j)
   j = j or -1

   if i == nil then
      return ""
   end

   local pos = 1
   local bytes = string.len(s)
   local len = 0

   -- only set l if i or j is negative
   local l = (i >= 0 and j >= 0) or utf8.len(s)
   local startChar = (i >= 0) and i or l + i + 1
   local endChar = (j >= 0) and j or l + j + 1

   -- can't have start before end!
   if startChar > endChar then
      return ""
   end

   -- byte offsets to pass to string.sub
   local startByte, endByte = 1, bytes

   while pos <= bytes do
      len = len + 1

      if len == startChar then
	 startByte = pos
      end

      pos = pos + utf8.charbytes(s, pos)

      if len == endChar then
	 endByte = pos - 1
	 break
      end
   end

   return string.sub(s, startByte, endByte)
end

return Moan