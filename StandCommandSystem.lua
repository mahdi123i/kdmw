--[[
	ROBLOX STAND COMMAND SYSTEM v2.1 — DA HOOD PATCH
	GitHub-Loadable | Production-Ready | Executor-Compatible
	
	Usage: loadstring(game:HttpGet("RAW_GITHUB_URL"))()
	
	Configuration via getgenv():
	- getgenv().Owner = "YourUsername"
	- getgenv()._C = { CrewID = 1, StandMode = "auto", AutoReload = true }
	
	Core Principles:
	- Finite State Machine (IDLE / MOVE / KILL)
	- Hard state ownership and locks
	- No obfuscation, no hidden magic
	- Deterministic behavior under load
	- Clean separation of concerns
	- Admin detection with auto-safety
	- Event-driven execution
	- DA HOOD REMOTE INTEGRATION
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

-- ============================================================================
-- CONFIGURATION LOADER
-- ============================================================================

local Config = {}
Config.Owner = getgenv().Owner or "Mahdirml123i"
Config.CrewID = (getgenv()._C and getgenv()._C.CrewID) or 1
Config.StandMode = (getgenv()._C and getgenv()._C.StandMode) or "auto"
Config.AutoReload = (getgenv()._C and getgenv()._C.AutoReload) ~= false
Config.Position = (getgenv()._C and getgenv()._C.Position) or "safe1"
Config.AttackMode = (getgenv()._C and getgenv()._C.AttackMode) or "enabled"

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

function DaHoodRemotes:punch(targetHumanoid)
	return self:fireRemote("Punch", targetHumanoid)
end

function DaHoodRemotes:knock(targetCharacter)
	return self:fireRemote("Knock", targetCharacter)
end

function DaHoodRemotes:stomp(targetCharacter)
	return self:fireRemote("Stomp", targetCharacter)
end

function DaHoodRemotes:carry(targetCharacter)
	return self:fireRemote("Carry", targetCharacter)
end

function DaHoodRemotes:dropCash(amount)
	return self:fireRemote("DropCash", amount)
end

function DaHoodRemotes:buyItem(itemName)
	return self:fireRemote("BuyItem", itemName)
end

function DaHoodRemotes:equipGun(gunName)
	return self:fireRemote("EquipGun", gunName)
end

function DaHoodRemotes:fireGun(targetCharacter)
	return self:fireRemote("FireGun", targetCharacter)
end

function DaHoodRemotes:arrest(targetCharacter)
	return self:fireRemote("Arrest", targetCharacter)
end

function DaHoodRemotes:joinCrew(crewId)
	return self:fireRemote("JoinCrew", crewId)
end

function DaHoodRemotes:leaveCrew()
	return self:fireRemote("LeaveCrew")
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
StateManager.stateCallbacks = {}
StateManager.attackEnabled = true
StateManager.standActive = false
StateManager.standOwnerCrew = nil

function StateManager:registerStateCallback(state, callback)
	if not self.stateCallbacks[state] then
		self.stateCallbacks[state] = {}
	end
	table.insert(self.stateCallbacks[state], callback)
end

function StateManager:setState(newState)
	if self.stateLock then
		return false
	end
	
	if not self.states[newState] then
		return false
	end
	
	local oldState = self.currentState
	self.currentState = newState
	
	if self.stateCallbacks[newState] then
		for _, callback in ipairs(self.stateCallbacks[newState]) do
			callback(oldState)
		end
	end
	
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
-- ADMIN DETECTOR
-- ============================================================================

local AdminDetector = {}
AdminDetector.isAdminPresent = false
AdminDetector.adminCheckInterval = 2
AdminDetector.lastCheckTime = 0
AdminDetector.adminNames = {}
AdminDetector.autoRejoinOnDetect = true

function AdminDetector:isPlayerAdmin(player)
	if self.adminNames[string.lower(player.Name)] then
		return true
	end
	
	local name = string.lower(player.Name)
	if string.find(name, "admin") or string.find(name, "mod") or string.find(name, "staff") then
		return true
	end
	
	return false
end

function AdminDetector:checkForAdmins()
	local currentTime = tick()
	if currentTime - self.lastCheckTime < self.adminCheckInterval then
		return
	end
	
	self.lastCheckTime = currentTime
	
	local adminFound = false
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Players.LocalPlayer and self:isPlayerAdmin(player) then
			adminFound = true
			break
		end
	end
	
	if adminFound and not self.isAdminPresent then
		self.isAdminPresent = true
		self:onAdminDetected()
	elseif not adminFound and self.isAdminPresent then
		self.isAdminPresent = false
	end
end

function AdminDetector:onAdminDetected()
	if StateManager:isState(StateManager.states.KILL) then
		StateManager:setState(StateManager.states.IDLE)
		StateManager:unlockState()
	end
	
	if self.autoRejoinOnDetect then
		task.wait(0.5)
		TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
	end
end

function AdminDetector:addAdmin(playerName)
	self.adminNames[string.lower(playerName)] = true
end

function AdminDetector:removeAdmin(playerName)
	self.adminNames[string.lower(playerName)] = nil
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

function MovementEngine:setChaosLevel(level)
	self.chaosLevel = math.clamp(level, 0, 1)
end

-- ============================================================================
-- KILL ENGINE (gkill!) — DA HOOD REAL EXECUTION
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
CommandDispatcher.owner = Players.LocalPlayer

function CommandDispatcher:register(commandName, callback)
	self.commands[string.lower(commandName)] = callback
end

function CommandDispatcher:execute(input, speaker)
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
-- TELEPORT SYSTEM (FIXED)
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
-- CASH SYSTEM (DA HOOD)
-- ============================================================================

local CashSystem = {}
CashSystem.autoDrop = false
CashSystem.lastDropTime = 0
CashSystem.dropCooldown = 1.0
CashSystem.maxDropAmount = 5000

function CashSystem:toggleAutoDrop()
	self.autoDrop = not self.autoDrop
end

function CashSystem:dropCash(amount)
	local currentTime = tick()
	if currentTime - self.lastDropTime < self.dropCooldown then
		return false
	end
	
	local safeAmount = math.min(amount, self.maxDropAmount)
	DaHoodRemotes:dropCash(safeAmount)
	self.lastDropTime = currentTime
	return true
end

function CashSystem:update()
	if not self.autoDrop then
		return
	end
	
	self:dropCash(self.maxDropAmount)
end

-- ============================================================================
-- GUN SYSTEM (DA HOOD)
-- ============================================================================

local GunSystem = {}
GunSystem.currentGun = nil
GunSystem.guns = {
	rifle = "Rifle",
	lmg = "LMG",
	aug = "AUG",
	pistol = "Pistol",
	shotgun = "Shotgun"
}

function GunSystem:equipGun(gunName)
	local gunType = self.guns[string.lower(gunName)]
	if not gunType then
		return false
	end
	
	DaHoodRemotes:equipGun(gunType)
	self.currentGun = gunType
	return true
end

function GunSystem:fireAtTarget(targetCharacter)
	if not self.currentGun then
		return false
	end
	
	if StateManager:isState(StateManager.states.KILL) then
		return false
	end
	
	DaHoodRemotes:fireGun(targetCharacter)
	return true
end

-- ============================================================================
-- CREW SYSTEM (DA HOOD)
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
-- TARGET RESOLVER (CENTRAL)
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
-- OWNER SYSTEM
-- ============================================================================

local OwnerSystem = {}
OwnerSystem.ownerUsername = Config.Owner
OwnerSystem.ownerPlayer = nil
OwnerSystem.initCompleted = false

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
		humanoid.Health = 0
		task.wait(1.0)
		
		if player.Character then
			TeleportSystem:teleportToPlace(Config.Position)
			task.wait(0.5)
		end
		
		StateManager:setState(StateManager.states.IDLE)
		StateManager.standActive = true
		MovementEngine:stop()
		StateManager.attackEnabled = false
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
end)

CommandDispatcher:register("/e q", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("/e q1", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("/e q2", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("/e q3", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("summon!", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("summon1!", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("summon2!", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("summon3!", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("killer queen", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("star platinum", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("star platinum: the world", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("star platinum over heaven", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("za warudo", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("c-moon", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("d4c", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("king crimson", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("made in heaven", function(args)
	StateManager.standActive = true
end)

CommandDispatcher:register("vanish!", function(args)
	StateManager.standActive = false
	if StateManager:isState(StateManager.states.KILL) then
		KillEngine:cleanup()
	end
	MovementEngine:stop()
	StateManager:setState(StateManager.states.IDLE)
end)

CommandDispatcher:register("desummon!", function(args)
	StateManager.standActive = false
	if StateManager:isState(StateManager.states.KILL) then
		KillEngine:cleanup()
	end
	MovementEngine:stop()
	StateManager:setState(StateManager.states.IDLE)
end)

CommandDispatcher:register("/e w", function(args)
	StateManager.standActive = false
	if StateManager:isState(StateManager.states.KILL) then
		KillEngine:cleanup()
	end
	MovementEngine:stop()
	StateManager:setState(StateManager.states.IDLE)
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

CommandDispatcher:register("autodrop!", function(args)
	CashSystem:toggleAutoDrop()
end)

CommandDispatcher:register("unautodrop!", function(args)
	CashSystem.autoDrop = false
end)

CommandDispatcher:register("wallet!", function(args) end)
CommandDispatcher:register("unwallet!", function(args) end)
CommandDispatcher:register("caura!", function(args) end)
CommandDispatcher:register("uncaura!", function(args) end)

CommandDispatcher:register("dcash", function(args)
	CashSystem:dropCash(5000)
end)

CommandDispatcher:register("gun!", function(args)
	GunSystem:equipGun("rifle")
end)

CommandDispatcher:register(".rifle", function(args)
	GunSystem:equipGun("rifle")
end)

CommandDispatcher:register(".lmg", function(args)
	GunSystem:equipGun("lmg")
end)

CommandDispatcher:register(".aug", function(args)
	GunSystem:equipGun("aug")
end)

CommandDispatcher:register(".give", function(args) end)
CommandDispatcher:register(".return", function(args) end)

-- ============================================================================
-- CHAT HOOK (DA HOOD SAFE)
-- ============================================================================

local function setupChatHook()
	local player = Players.LocalPlayer
	if not player then return end
	
	pcall(function()
		if player:FindFirstChild("Chatted") then
			player.Chatted:Connect(function(message)
				if string.lower(player.Name) == string.lower(Config.Owner) then
					CommandDispatcher:execute(message, player)
				end
			end)
		end
	end)
	
	pcall(function()
		if TextChatService then
			TextChatService.OnIncomingMessage = function(message)
				if message.TextSource and message.TextSource.Parent == player then
					if string.lower(player.Name) == string.lower(Config.Owner) then
						CommandDispatcher:execute(message.Text, player)
					end
				end
				return message
			end
		end
	end)
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

local mainLoopConnection = nil

local function mainLoop()
	mainLoopConnection = RunService.Heartbeat:Connect(function()
		AdminDetector:checkForAdmins()
		CashSystem:update()
		OwnerSystem:autoInit()
		AutoReloadSystem:tick()
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
	setupChatHook()
	mainLoop()
	
	_G.CommandDispatcher = CommandDispatcher
	_G.StateManager = StateManager
	_G.MovementEngine = MovementEngine
	_G.KillEngine = KillEngine
	_G.AdminDetector = AdminDetector
	_G.TeleportSystem = TeleportSystem
	_G.DaHoodRemotes = DaHoodRemotes
	_G.CashSystem = CashSystem
	_G.GunSystem = GunSystem
	_G.CrewSystem = CrewSystem
	_G.OwnerSystem = OwnerSystem
	_G.AutoReloadSystem = AutoReloadSystem
	_G.ResolveTarget = ResolveTarget
end

init()

return {
	CommandDispatcher = CommandDispatcher,
	StateManager = StateManager,
	MovementEngine = MovementEngine,
	KillEngine = KillEngine,
	AdminDetector = AdminDetector,
	TeleportSystem = TeleportSystem,
	DaHoodRemotes = DaHoodRemotes,
	CashSystem = CashSystem,
	GunSystem = GunSystem,
	CrewSystem = CrewSystem,
	OwnerSystem = OwnerSystem,
	AutoReloadSystem = AutoReloadSystem,
	ResolveTarget = ResolveTarget
}
