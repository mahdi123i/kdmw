--[[
	ROBLOX STAND COMMAND SYSTEM v6.0 FINAL
	Professional Exploit Loader | Da Hood Compatible
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local CoreGui = game:GetService("CoreGui")

-- ============================================================================
-- CONFIGURATION LOADER
-- ============================================================================

local Config = {}
Config.Owner = getgenv().Owner or "Mahdirml123i"
Config.CrewID = (getgenv()._C and getgenv()._C.CrewID) or 1
Config.AutoReload = (getgenv()._C and getgenv()._C.AutoReload) ~= false
Config.Position = (getgenv()._C and getgenv()._C.Position) or "safe1"
Config.CustomPrefix = (getgenv()._C and getgenv()._C.CustomPrefix) or "."

-- ============================================================================
-- CHAT SYSTEM (FORCE-ENABLE)
-- ============================================================================

local ChatSystem = {}
ChatSystem.enabled = false

function ChatSystem:setupListeners()
	if self.enabled then
		return
	end
	
	self.enabled = true
	
	local player = Players.LocalPlayer
	if not player then return end
	
	-- Legacy Chatted event
	pcall(function()
		player.Chatted:Connect(function(message)
			if string.lower(player.Name) ~= string.lower(Config.Owner) then
				return
			end
			
			local prefix = string.sub(message, 1, 1)
			if prefix == Config.CustomPrefix or prefix == "." then
				CommandDispatcher:execute(message)
			end
		end)
	end)
	
	-- TextChatService listener
	pcall(function()
		if TextChatService then
			TextChatService.OnIncomingMessage = function(message)
				if message.TextSource and message.TextSource.Parent == player then
					if string.lower(player.Name) ~= string.lower(Config.Owner) then
						return
					end
					
					local text = message.Text
					local prefix = string.sub(text, 1, 1)
					if prefix == Config.CustomPrefix or prefix == "." then
						CommandDispatcher:execute(text)
					end
				end
			end
		end
	end)
end

-- ============================================================================
-- DA HOOD REMOTE DETECTION & HELPERS
-- ============================================================================

local DaHoodRemotes = {}
DaHoodRemotes.mainEvent = nil
DaHoodRemotes.detected = false
DaHoodRemotes.lastRemoteCall = 0
DaHoodRemotes.remoteCallCooldown = 0.05

function DaHoodRemotes:detectRemotes()
	if self.detected then
		return true
	end
	
	local mainEvent = ReplicatedStorage:FindFirstChild("MainEvent")
	if mainEvent and mainEvent:IsA("RemoteEvent") then
		self.mainEvent = mainEvent
		self.detected = true
		return true
	end
	
	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		if child:IsA("RemoteEvent") then
			self.mainEvent = child
			self.detected = true
			return true
		end
	end
	
	return false
end

function DaHoodRemotes:fireRemote(action, ...)
	if not self.mainEvent then
		if not self:detectRemotes() then
			return false
		end
	end
	
	local currentTime = tick()
	if currentTime - self.lastRemoteCall < self.remoteCallCooldown then
		return false
	end
	self.lastRemoteCall = currentTime
	
	local success = pcall(function()
		self.mainEvent:FireServer(action, ...)
	end)
	
	return success
end

function DaHoodRemotes:knock(targetCharacter)
	return self:fireRemote("Knock", targetCharacter)
end

function DaHoodRemotes:stomp(targetCharacter)
	return self:fireRemote("Stomp", targetCharacter)
end

function DaHoodRemotes:joinCrew(crewId)
	return self:fireRemote("JoinCrew", crewId)
end

function DaHoodRemotes:leaveCrew()
	return self:fireRemote("LeaveCrew")
end

function DaHoodRemotes:arrest(targetCharacter)
	return self:fireRemote("Arrest", targetCharacter)
end

function DaHoodRemotes:dropCash(amount)
	return self:fireRemote("DropCash", amount)
end

-- ============================================================================
-- STATE MACHINE CORE
-- ============================================================================

local StateManager = {}
StateManager.states = {
	IDLE = "IDLE",
	MOVE = "MOVE",
	KILL = "KILL"
}

StateManager.currentState = StateManager.states.IDLE
StateManager.stateLock = false
StateManager.attackEnabled = true
StateManager.standActive = false

function StateManager:setState(newState)
	if self.stateLock then
		return false
	end
	
	if not self.states[newState] then
		return false
	end
	
	self.currentState = newState
	return true
end

function StateManager:lockState()
	self.stateLock = true
end

function StateManager:unlockState()
	self.stateLock = false
end

function StateManager:isState(state)
	return self.currentState == state
end

-- ============================================================================
-- STAND MODEL SYSTEM
-- ============================================================================

local StandModel = {}
StandModel.stand = nil
StandModel.standHumanoidRootPart = nil
StandModel.floatOffset = 0
StandModel.floatSpeed = 0.05
StandModel.floatAmplitude = 0.5

function StandModel:create()
	if self.stand then
		return self.stand
	end
	
	local player = Players.LocalPlayer
	if not player or not player.Character then
		return nil
	end
	
	local stand = player.Character:Clone()
	stand.Name = "Stand"
	stand.Parent = workspace
	
	local humanoid = stand:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:Destroy()
	end
	
	for _, part in ipairs(stand:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0.2
			part.CanCollide = false
		end
	end
	
	self.stand = stand
	self.standHumanoidRootPart = stand:FindFirstChild("HumanoidRootPart")
	self.floatOffset = 0
	
	return stand
end

function StandModel:destroy()
	if self.stand then
		self.stand:Destroy()
		self.stand = nil
		self.standHumanoidRootPart = nil
	end
end

function StandModel:getPosition()
	if self.standHumanoidRootPart then
		return self.standHumanoidRootPart.Position
	end
	return nil
end

function StandModel:setPosition(cframe)
	if self.standHumanoidRootPart then
		self.standHumanoidRootPart.CFrame = cframe
	end
end

function StandModel:updateFloatAnimation()
	self.floatOffset = self.floatOffset + self.floatSpeed
	return math.sin(self.floatOffset) * self.floatAmplitude
end

-- ============================================================================
-- MOVEMENT ENGINE
-- ============================================================================

local MovementEngine = {}
MovementEngine.isActive = false
MovementEngine.targetCharacter = nil
MovementEngine.moveConnection = nil
MovementEngine.lastMoveTime = 0
MovementEngine.moveInterval = 0.05
MovementEngine.chaosLevel = 1.0

function MovementEngine:start(targetCharacter)
	if StateManager:isState(StateManager.states.KILL) then
		return
	end
	
	self.targetCharacter = targetCharacter
	self.isActive = true
	self.lastMoveTime = tick()
	
	if self.moveConnection then
		self.moveConnection:Disconnect()
	end
	
	self.moveConnection = RunService.Heartbeat:Connect(function()
		if not self.isActive or StateManager:isState(StateManager.states.KILL) then
			return
		end
		
		local currentTime = tick()
		if currentTime - self.lastMoveTime < self.moveInterval then
			return
		end
		
		self.lastMoveTime = currentTime
		self:executeMovement()
	end)
end

function MovementEngine:executeMovement()
	local player = Players.LocalPlayer
	if not player or not player.Character then
		return
	end
	
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end
	
	if not self.targetCharacter or not self.targetCharacter:FindFirstChild("HumanoidRootPart") then
		self:stop()
		return
	end
	
	local targetRoot = self.targetCharacter:FindFirstChild("HumanoidRootPart")
	local currentPos = humanoidRootPart.Position
	local targetPos = targetRoot.Position
	
	local direction = (targetPos - currentPos)
	if direction.Magnitude == 0 then
		return
	end
	direction = direction.Unit
	
	local deviationAngle = math.rad(math.random(-60, 60) * self.chaosLevel)
	local deviationMagnitude = math.random(3, 12) * self.chaosLevel
	
	local rotatedDir = CFrame.new(Vector3.new(0, 0, 0), direction)
	rotatedDir = rotatedDir * CFrame.Angles(0, deviationAngle, 0)
	local deviationVector = rotatedDir.LookVector * deviationMagnitude
	
	local moveDistance = math.random(6, 14)
	local newPos = currentPos + (direction * moveDistance) + Vector3.new(deviationVector.X, 0, deviationVector.Z)
	
	newPos = Vector3.new(newPos.X, currentPos.Y, newPos.Z)
	
	local newCFrame = CFrame.new(newPos, newPos + direction)
	humanoidRootPart.CFrame = newCFrame
end

function MovementEngine:stop()
	self.isActive = false
	self.targetCharacter = nil
	
	if self.moveConnection then
		self.moveConnection:Disconnect()
		self.moveConnection = nil
	end
end

-- ============================================================================
-- KILL ENGINE (gkill!)
-- ============================================================================

local KillEngine = {}
KillEngine.isExecuting = false
KillEngine.targets = {}
KillEngine.currentTargetIndex = 1
KillEngine.hitDelay = 0.4
KillEngine.moveResumeDelay = 0.15
KillEngine.aoeRange = 50

function KillEngine:acquireTargets()
	local player = Players.LocalPlayer
	if not player or not player.Character then
		return {}
	end
	
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return {}
	end
	
	local acquiredTargets = {}
	
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer == player then
			continue
		end
		
		if not otherPlayer.Character then
			continue
		end
		
		local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not otherRoot then
			continue
		end
		
		local otherHumanoid = otherPlayer.Character:FindFirstChild("Humanoid")
		if not otherHumanoid or otherHumanoid.Health <= 0 then
			continue
		end
		
		local distance = (otherRoot.Position - humanoidRootPart.Position).Magnitude
		if distance <= self.aoeRange then
			table.insert(acquiredTargets, otherPlayer)
		end
	end
	
	return acquiredTargets
end

function KillEngine:executeKill()
	if not StateManager.attackEnabled then
		return
	end
	
	if not StateManager.standActive then
		return
	end
	
	if StateManager:isState(StateManager.states.KILL) then
		return
	end
	
	if not StateManager:setState(StateManager.states.KILL) then
		return
	end
	StateManager:lockState()
	
	self.isExecuting = true
	self.targets = self:acquireTargets()
	self.currentTargetIndex = 1
	
	if #self.targets == 0 then
		self:cleanup()
		return
	end
	
	self:processNextTarget()
end

function KillEngine:processNextTarget()
	if self.currentTargetIndex > #self.targets then
		self:cleanup()
		return
	end
	
	local targetPlayer = self.targets[self.currentTargetIndex]
	if not targetPlayer or not targetPlayer.Character then
		self.currentTargetIndex = self.currentTargetIndex + 1
		task.wait(0.1)
		self:processNextTarget()
		return
	end
	
	local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		self.currentTargetIndex = self.currentTargetIndex + 1
		task.wait(0.1)
		self:processNextTarget()
		return
	end
	
	MovementEngine:stop()
	self:attackTarget(targetPlayer)
	
	task.wait(self.hitDelay)
	
	self.currentTargetIndex = self.currentTargetIndex + 1
	task.wait(self.moveResumeDelay)
	
	self:processNextTarget()
end

function KillEngine:attackTarget(targetPlayer)
	local player = Players.LocalPlayer
	if not player or not player.Character then
		return
	end
	
	local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return
	end
	
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end
	
	local targetPos = targetRoot.Position
	local direction = (targetPos - humanoidRootPart.Position)
	if direction.Magnitude > 0 then
		direction = direction.Unit
	end
	
	local attackPos = targetPos - (direction * 4)
	humanoidRootPart.CFrame = CFrame.new(attackPos, targetPos)
	
	DaHoodRemotes:knock(targetPlayer.Character)
	task.wait(0.1)
	DaHoodRemotes:stomp(targetPlayer.Character)
end

function KillEngine:cleanup()
	self.isExecuting = false
	self.targets = {}
	self.currentTargetIndex = 1
	
	StateManager:setState(StateManager.states.IDLE)
	StateManager:unlockState()
end

-- ============================================================================
-- COMMAND DISPATCHER
-- ============================================================================

local CommandDispatcher = {}
CommandDispatcher.commands = {}

function CommandDispatcher:register(commandName, callback)
	self.commands[string.lower(commandName)] = callback
end

function CommandDispatcher:execute(input)
	local parts = {}
	for part in string.gmatch(input, "%S+") do
		table.insert(parts, part)
	end
	
	if #parts == 0 then
		return
	end
	
	local commandName = string.lower(parts[1])
	local args = {}
	for i = 2, #parts do
		table.insert(args, parts[i])
	end
	
	local command = self.commands[commandName]
	if command then
		command(args)
	end
end

-- ============================================================================
-- TELEPORT SYSTEM
-- ============================================================================

local TeleportSystem = {}
TeleportSystem.places = {
	bank = 1, roof = 2, club = 3, casino = 4, ufo = 5, mil = 6, school = 7,
	shop1 = 8, shop2 = 9, rev = 10, db = 11, pool = 12, armor = 13,
	subway = 14, subway1 = 15, sewer = 16, wheel = 17,
	safe1 = 18, safe2 = 19, safe3 = 20, safe4 = 21, safe5 = 22,
	basketball = 23, boxing = 24, bull = 25
}

function TeleportSystem:teleportToPlace(placeName)
	local player = Players.LocalPlayer
	if not player or not player.Character then return end
	
	local placeId = self.places[string.lower(placeName)]
	if not placeId then
		return
	end
	
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position + Vector3.new(0, 50, 0))
	end
end

-- ============================================================================
-- CREW SYSTEM
-- ============================================================================

local CrewSystem = {}
CrewSystem.inCrew = false
CrewSystem.currentCrewId = nil

function CrewSystem:joinCrew(crewId)
	DaHoodRemotes:joinCrew(crewId)
	self.inCrew = true
	self.currentCrewId = crewId
end

function CrewSystem:leaveCrew()
	DaHoodRemotes:leaveCrew()
	self.inCrew = false
	self.currentCrewId = nil
end

-- ============================================================================
-- TARGET RESOLVER
-- ============================================================================

local function ResolveTarget(input)
	if not input or input == "" then
		return nil
	end
	
	local searchLower = string.lower(input)
	local localPlayer = Players.LocalPlayer
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player == localPlayer then continue end
		if not player.Character then continue end
		if string.lower(player.Name) == searchLower then
			return player
		end
	end
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player == localPlayer then continue end
		if not player.Character then continue end
		if player.DisplayName and string.lower(player.DisplayName) == searchLower then
			return player
		end
	end
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player == localPlayer then continue end
		if not player.Character then continue end
		if string.find(string.lower(player.Name), searchLower, 1, true) then
			return player
		end
	end
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player == localPlayer then continue end
		if not player.Character then continue end
		if player.DisplayName and string.find(string.lower(player.DisplayName), searchLower, 1, true) then
			return player
		end
	end
	
	return nil
end

-- ============================================================================
-- OWNER SYSTEM (AUTO-INIT SEQUENCE)
-- ============================================================================

local OwnerSystem = {}
OwnerSystem.ownerUsername = Config.Owner
OwnerSystem.ownerPlayer = nil
OwnerSystem.initCompleted = false
OwnerSystem.hasResetOnce = false

function OwnerSystem:autoInit()
	if self.initCompleted then
		return
	end
	
	local player = Players.LocalPlayer
	if not player then
		return
	end
	
	if string.lower(player.Name) ~= string.lower(self.ownerUsername) then
		return
	end
	
	if not player.Character then
		return
	end
	
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end
	
	self.initCompleted = true
	self.ownerPlayer = player
	
	task.spawn(function()
		-- Force character reset ONCE on script load
		if not self.hasResetOnce then
			self.hasResetOnce = true
			humanoid.Health = 0
			task.wait(1.5)
		end
		
		-- After respawn: teleport to configured position
		if player.Character then
			TeleportSystem:teleportToPlace(Config.Position)
			task.wait(0.5)
		end
		
		-- Join configured crew
		if Config.CrewID and Config.CrewID > 0 then
			CrewSystem:joinCrew(Config.CrewID)
			task.wait(0.3)
		end
		
		-- Summon stand automatically
		StateManager:setState(StateManager.states.IDLE)
		StateManager.standActive = true
		StateManager.attackEnabled = true
		MovementEngine:stop()
		StandModel:create()
	end)
end

-- ============================================================================
-- AUTO RELOAD SYSTEM
-- ============================================================================

local AutoReloadSystem = {}
AutoReloadSystem.lastCheckTime = 0
AutoReloadSystem.checkCooldown = 0.5
AutoReloadSystem.wasAlive = true

function AutoReloadSystem:tick()
	if not Config.AutoReload then
		return
	end
	
	local player = Players.LocalPlayer
	if not player or not player.Character then
		return
	end
	
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end
	
	local currentTime = tick()
	if currentTime - self.lastCheckTime < self.checkCooldown then
		return
	end
	
	self.lastCheckTime = currentTime
	
	local isAlive = humanoid.Health > 0
	
	if self.wasAlive and not isAlive then
		self.wasAlive = false
		task.wait(2.0)
		
		if player.Character then
			OwnerSystem.initCompleted = false
			OwnerSystem:autoInit()
			StateManager:setState(StateManager.states.IDLE)
			MovementEngine:stop()
		end
	elseif not self.wasAlive and isAlive then
		self.wasAlive = true
	end
end

-- ============================================================================
-- STAND HOVER ENGINE
-- ============================================================================

local StandHoverEngine = {}
StandHoverEngine.hoverConnection = nil
StandHoverEngine.lastHoverTime = 0
StandHoverEngine.hoverInterval = 0.03
StandHoverEngine.hoverDistance = 6
StandHoverEngine.hoverHeight = 2.5
StandHoverEngine.hoverOffsetX = 0
StandHoverEngine.lerpSpeed = 0.12

function StandHoverEngine:start()
	if self.hoverConnection then
		return
	end
	
	self.lastHoverTime = tick()
	
	self.hoverConnection = RunService.Heartbeat:Connect(function()
		if not StateManager.standActive then
			return
		end
		
		if StateManager:isState(StateManager.states.KILL) then
			return
		end
		
		local currentTime = tick()
		if currentTime - self.lastHoverTime < self.hoverInterval then
			return
		end
		
		self.lastHoverTime = currentTime
		self:executeHover()
	end)
end

function StandHoverEngine:executeHover()
	local player = Players.LocalPlayer
	if not player or not player.Character then
		return
	end
	
	if not StandModel.standHumanoidRootPart then
		return
	end
	
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end
	
	local ownerPos = humanoidRootPart.Position
	local ownerCFrame = humanoidRootPart.CFrame
	
	local backVector = -ownerCFrame.LookVector * self.hoverDistance
	local sideVector = ownerCFrame.RightVector * self.hoverOffsetX
	local floatAnimation = StandModel:updateFloatAnimation()
	local upVector = Vector3.new(0, self.hoverHeight + floatAnimation, 0)
	
	local targetHoverPos = ownerPos + backVector + sideVector + upVector
	
	local currentPos = StandModel.standHumanoidRootPart.Position
	local smoothPos = currentPos:Lerp(targetHoverPos, self.lerpSpeed)
	
	local groundY = math.max(smoothPos.Y, ownerPos.Y - 1.5)
	smoothPos = Vector3.new(smoothPos.X, groundY, smoothPos.Z)
	
	local newCFrame = CFrame.new(smoothPos, ownerPos)
	StandModel:setPosition(newCFrame)
end

function StandHoverEngine:stop()
	if self.hoverConnection then
		self.hoverConnection:Disconnect()
		self.hoverConnection = nil
	end
end

-- ============================================================================
-- COMMAND REGISTRATION
-- ============================================================================

CommandDispatcher:register("gkill!", function(args)
	if not StateManager.attackEnabled then return end
	if not StateManager.standActive then return end
	if StateManager:isState(StateManager.states.KILL) then return end
	KillEngine:executeKill()
end)

CommandDispatcher:register(".bring", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		MovementEngine:start(targetPlayer.Character)
	end
end)

CommandDispatcher:register(".gbring", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		MovementEngine:start(targetPlayer.Character)
	end
end)

CommandDispatcher:register("gauto", function(args)
	local player = Players.LocalPlayer
	if not player or not player.Character then return end
	
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local nearestPlayer = nil
	local nearestDistance = math.huge
	
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer == player or not otherPlayer.Character then continue end
		local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not otherRoot then continue end
		
		local distance = (otherRoot.Position - humanoidRootPart.Position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestPlayer = otherPlayer
		end
	end
	
	if nearestPlayer then
		MovementEngine:start(nearestPlayer.Character)
	end
end)

CommandDispatcher:register("stop!", function(args)
	MovementEngine:stop()
end)

CommandDispatcher:register("walk!", function(args)
	MovementEngine:stop()
end)

CommandDispatcher:register("left!", function(args) end)
CommandDispatcher:register("right!", function(args) end)
CommandDispatcher:register("back!", function(args) end)
CommandDispatcher:register("under!", function(args) end)
CommandDispatcher:register("alt!", function(args) end)
CommandDispatcher:register("upright!", function(args) end)
CommandDispatcher:register("upleft!", function(args) end)
CommandDispatcher:register("upcenter!", function(args) end)

CommandDispatcher:register("goto!", function(args)
	if #args < 1 then return end
	TeleportSystem:teleportToPlace(args[1])
end)

CommandDispatcher:register("tp!", function(args)
	if #args < 1 then return end
	TeleportSystem:teleportToPlace(args[1])
end)

CommandDispatcher:register("to!", function(args)
	if #args < 1 then return end
	TeleportSystem:teleportToPlace(args[1])
end)

CommandDispatcher:register(".goto", function(args)
	if #args < 1 then return end
	TeleportSystem:teleportToPlace(args[1])
end)

CommandDispatcher:register(".tp", function(args)
	if #args < 1 then return end
	TeleportSystem:teleportToPlace(args[1])
end)

CommandDispatcher:register(".to", function(args)
	if #args < 1 then return end
	TeleportSystem:teleportToPlace(args[1])
end)

CommandDispatcher:register("hide!", function(args) end)
CommandDispatcher:register(".surgeon", function(args) end)
CommandDispatcher:register(".paintball", function(args) end)
CommandDispatcher:register(".pumpkin", function(args) end)
CommandDispatcher:register(".hockey", function(args) end)
CommandDispatcher:register(".ninja", function(args) end)
CommandDispatcher:register(".riot", function(args) end)

CommandDispatcher:register("hover", function(args) end)
CommandDispatcher:register("flyv1", function(args) end)
CommandDispatcher:register("flyv2", function(args) end)
CommandDispatcher:register("glide", function(args) end)
CommandDispatcher:register("heaven", function(args) end)

CommandDispatcher:register("blow", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("doggy", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("bring", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("smite", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("view", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("view!", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("frame", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("bag", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("arrest", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		DaHoodRemotes:arrest(targetPlayer.Character)
	end
end)

CommandDispatcher:register("knock", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		DaHoodRemotes:knock(targetPlayer.Character)
	end
end)

CommandDispatcher:register("k", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		DaHoodRemotes:knock(targetPlayer.Character)
	end
end)

CommandDispatcher:register("pull", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("taser", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("autokill", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("stomp", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		DaHoodRemotes:stomp(targetPlayer.Character)
	end
end)

CommandDispatcher:register("annoy", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("kannoy", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("gknock", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		DaHoodRemotes:knock(targetPlayer.Character)
	end
end)

CommandDispatcher:register("gstomp", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		DaHoodRemotes:stomp(targetPlayer.Character)
	end
end)

CommandDispatcher:register("fstomp", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		DaHoodRemotes:stomp(targetPlayer.Character)
	end
end)

CommandDispatcher:register("fknock", function(args)
	if #args < 1 then return end
	local targetPlayer = ResolveTarget(args[1])
	if targetPlayer and targetPlayer.Character then
		DaHoodRemotes:knock(targetPlayer.Character)
	end
end)

CommandDispatcher:register("rk", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("rm", function(args)
	if #args < 1 then return end
	ResolveTarget(args[1])
end)

CommandDispatcher:register("combat!", function(args) end)
CommandDispatcher:register("knife!", function(args) end)
CommandDispatcher:register("pitch!", function(args) end)
CommandDispatcher:register("sign!", function(args) end)
CommandDispatcher:register("whip!", function(args) end)

CommandDispatcher:register("hidden!", function(args) end)
CommandDispatcher:register("default!", function(args) end)
CommandDispatcher:register("drop!", function(args) end)
CommandDispatcher:register("throw!", function(args) end)

CommandDispatcher:register("resolver!", function(args) end)
CommandDispatcher:register("unresolver!", function(args) end)

CommandDispatcher:register("attack!", function(args)
	StateManager.attackEnabled = true
end)

CommandDispatcher:register("unattack!", function(args)
	StateManager.attackEnabled = false
	if StateManager:isState(StateManager.states.KILL) then
		KillEngine:cleanup()
	end
	MovementEngine:stop()
end)

CommandDispatcher:register("stab!", function(args)
	StateManager.attackEnabled = true
end)

CommandDispatcher:register("unstab!", function(args)
	StateManager.attackEnabled = false
	if StateManager:isState(StateManager.states.KILL) then
		KillEngine:cleanup()
	end
	MovementEngine:stop()
end)

CommandDispatcher:register("s", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("/e q", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("/e q1", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("/e q2", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("/e q3", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("summon!", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("summon1!", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("summon2!", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("summon3!", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("killer queen", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("star platinum", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("star platinum: the world", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("star platinum over heaven", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("za warudo", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("c-moon", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("d4c", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("king crimson", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("made in heaven", function(args)
	StateManager.standActive = true
	if not StandModel.stand then
		StandModel:create()
	end
end)

CommandDispatcher:register("vanish!", function(args)
	StateManager.standActive = false
	if StateManager:isState(StateManager.states.KILL) then
		KillEngine:cleanup()
	end
	MovementEngine:stop()
	StateManager:setState(StateManager.states.IDLE)
	StandModel:destroy()
end)

CommandDispatcher:register("desummon!", function(args)
	StateManager.standActive = false
	if StateManager:isState(StateManager.states.KILL) then
		KillEngine:cleanup()
	end
	MovementEngine:stop()
	StateManager:setState(StateManager.states.IDLE)
	StandModel:destroy()
end)

CommandDispatcher:register("/e w", function(args)
	StateManager.standActive = false
	if StateManager:isState(StateManager.states.KILL) then
		KillEngine:cleanup()
	end
	MovementEngine:stop()
	StateManager:setState(StateManager.states.IDLE)
	StandModel:destroy()
end)

CommandDispatcher:register("ora!", function(args) end)
CommandDispatcher:register("muda!", function(args) end)
CommandDispatcher:register("barrage!", function(args) end)
CommandDispatcher:register("ac!", function(args) end)

CommandDispatcher:register("rj!", function(args)
	task.wait(0.5)
	TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
end)

CommandDispatcher:register("rejoin!", function(args)
	task.wait(0.5)
	TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
end)

CommandDispatcher:register("leave!", function(args)
	Players.LocalPlayer:Kick("User initiated leave")
end)

CommandDispatcher:register("autosave!", function(args) end)
CommandDispatcher:register("unautosave!", function(args) end)
CommandDispatcher:register("re!", function(args) end)

CommandDispatcher:register("heal!", function(args)
	local player = Players.LocalPlayer
	if player and player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end)

CommandDispatcher:register("song!", function(args) end)
CommandDispatcher:register("stopaudio!", function(args) end)

CommandDispatcher:register("crew!", function(args)
	CrewSystem:joinCrew(Config.CrewID)
end)

CommandDispatcher:register("uncrew!", function(args)
	CrewSystem:leaveCrew()
end)

CommandDispatcher:register("moveset1", function(args) end)
CommandDispatcher:register("moveset2", function(args) end)
CommandDispatcher:register("weld!", function(args) end)
CommandDispatcher:register("boxing!", function(args) end)
CommandDispatcher:register("unblock!", function(args) end)
CommandDispatcher:register("pose1", function(args) end)
CommandDispatcher:register("pose2", function(args) end)
CommandDispatcher:register("pose3", function(args) end)
CommandDispatcher:register("police!", function(args) end)
CommandDispatcher:register("autoweight!", function(args) end)
CommandDispatcher:register("lettuce!", function(args) end)
CommandDispatcher:register("unlettuce!", function(args) end)
CommandDispatcher:register("lowgfx!", function(args) end)
CommandDispatcher:register("redeem!", function(args) end)
CommandDispatcher:register("power!", function(args) end)
CommandDispatcher:register("sneak!", function(args) end)
CommandDispatcher:register("unjail!", function(args) end)

CommandDispatcher:register("autodrop!", function(args) end)
CommandDispatcher:register("unautodrop!", function(args) end)

CommandDispatcher:register("wallet!", function(args) end)
CommandDispatcher:register("unwallet!", function(args) end)
CommandDispatcher:register("caura!", function(args) end)
CommandDispatcher:register("uncaura!", function(args) end)

CommandDispatcher:register("dcash", function(args)
	DaHoodRemotes:dropCash(5000)
end)

CommandDispatcher:register("gun!", function(args) end)
CommandDispatcher:register(".rifle", function(args) end)
CommandDispatcher:register(".lmg", function(args) end)
CommandDispatcher:register(".aug", function(args) end)

CommandDispatcher:register(".give", function(args) end)
CommandDispatcher:register(".return", function(args) end)

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

local mainLoopConnection = nil

local function mainLoop()
	mainLoopConnection = RunService.Heartbeat:Connect(function()
		OwnerSystem:autoInit()
		AutoReloadSystem:tick()
		
		if StateManager.standActive and not StateManager:isState(StateManager.states.KILL) then
			if not StandHoverEngine.hoverConnection then
				StandHoverEngine:start()
			end
		elseif not StateManager.standActive and StandHoverEngine.hoverConnection then
			StandHoverEngine:stop()
		end
	end)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function init()
	if not Players.LocalPlayer then
		return
	end
	
	DaHoodRemotes:detectRemotes()
	ChatSystem:setupListeners()
	mainLoop()
	
	_G.CommandDispatcher = CommandDispatcher
	_G.StateManager = StateManager
	_G.MovementEngine = MovementEngine
	_G.KillEngine = KillEngine
	_G.TeleportSystem = TeleportSystem
	_G.DaHoodRemotes = DaHoodRemotes
	_G.CrewSystem = CrewSystem
	_G.OwnerSystem = OwnerSystem
	_G.AutoReloadSystem = AutoReloadSystem
	_G.ResolveTarget = ResolveTarget
	_G.StandHoverEngine = StandHoverEngine
	_G.ChatSystem = ChatSystem
	_G.StandModel = StandModel
end

init()

return {
	CommandDispatcher = CommandDispatcher,
	StateManager = StateManager,
	MovementEngine = MovementEngine,
	KillEngine = KillEngine,
	TeleportSystem = TeleportSystem,
	DaHoodRemotes = DaHoodRemotes,
	CrewSystem = CrewSystem,
	OwnerSystem = OwnerSystem,
	AutoReloadSystem = AutoReloadSystem,
	ResolveTarget = ResolveTarget,
	StandHoverEngine = StandHoverEngine,
	ChatSystem = ChatSystem,
	StandModel = StandModel
}
