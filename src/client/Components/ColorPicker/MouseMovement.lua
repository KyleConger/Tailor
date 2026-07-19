local UserInputService = game:GetService("UserInputService")

local MouseMovement = {}
MouseMovement.__index = MouseMovement

function MouseMovement.new(callback)
	local self = setmetatable({}, MouseMovement)
	self.CallbackFunc = callback
	self.Connected = false

	return self
end

function MouseMovement:Connect(...)
	if self.Connected then
		return
	end
	self.Connected = true

	local args = { ... }
	self.CallbackFunc(...)

	self._mouseMovement = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			self.CallbackFunc(table.unpack(args))
		end
	end)

	self._mouseUp = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if self.DisconnectCallback then
				self.DisconnectCallback()
			end

			self:Disconnect()
		end
	end)
end

function MouseMovement:Disconnect()
	self.Connected = false
	if self._mouseMovement then
		self._mouseMovement:Disconnect()
		self._mouseMovement = nil
	end

	if self._mouseUp then
		self._mouseUp:Disconnect()
		self._mouseUp = nil
	end
end

function MouseMovement:OnDisconnect(func)
	self.DisconnectCallback = func
end

function MouseMovement:Destroy()
	self:Disconnect()
	self = nil
end

return MouseMovement
