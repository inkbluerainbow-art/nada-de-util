-- by ink (fixed & updated for NPCs and executions)
local Settings = {
	VisibleHitbox = true;
	Hitmarker = false
}
local RepoPath = "https://raw.githubusercontent.com/CoolCatUser/HacklordRepo/main/"
local loadedassets = {}
local getasset = getcustomasset or getsynasset or function(a) return "rbxasset://"..a end
do
	if not isfolder("HacklordPackages") then makefolder("HacklordPackages/") end
	local files = {"Asset.rbxmx","Layer1.mp3","Layer2.mp3","Layer3.mp3","Chase.mp3","LMS.mp3","Footstep.ogg","Footstep2.ogg","Slash.ogg","Entanglement.ogg","EntanglementThrow.ogg","MassInfection.ogg","UnstableEye.ogg","Rejuvenate.ogg","Execution.ogg","Unknown.ogg"}
	for _, v in next, files do
		if not isfile("HacklordPackages/"..v) then
			local success,response = pcall(game.HttpGet,game,RepoPath..v)
			if success then
				writefile("HacklordPackages/"..v,response)
				loadedassets[v] = getasset("HacklordPackages/"..v)
			end
		else
			loadedassets[v] = getasset("HacklordPackages/"..v)
		end
	end
end

local AnimationModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/CoolCatUser/KeyframePlayer/refs/heads/main/Transform.lua"))()
local script = game:GetObjects(loadedassets["Asset.rbxmx"])[1]
local Accessories = script.Accessories:Clone()
local Animations = script.Animations:Clone()
local Miscs = script.Miscs:Clone()
local Zombie = script.Zombie:Clone()
script:Destroy()

local Enum = Enum
local next = next
local New = Instance.new
local Vector3 = Vector3
local vector = vector
local CFrame = CFrame
local math = math
local table = table
local osclock = os.clock
local NewInstance = function(Class, Parent, Properties)
	local inst = New(Class)
	for prop, val in next, Properties do inst[prop] = val end
	inst.Parent = Parent
	return inst
end

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Heartbeat = RunService.Heartbeat
local PreRender = RunService.PreRender
local RespawnTime = Players.RespawnTime
local CleanUp = {}
local Direction = 0
local current = osclock()
local last = current
local deltatime = 0
local debouche = false
local HeadLook = true
local debouchepriority = 1
local IsSprinting = false
local TerrorRange = 100
local PlayerTable = {}
local RootParts = {}
local PauseEverything = false
local StopEverything = false
local ShiftlockOn = false
local UnstableEyeEffectActive = false
local SpeedMultiply = 1
local SpeedEffectEndTime = current
local SpeedStackLevel = NewInstance("IntValue", Character, {Value = 0})
local LMSActive = false
local ForceTriggerLMS = false
local TriggerExecution

-- ============================================================
-- SISTEMA SCAN REMOTES
-- ============================================================
local ScanRemotesActive = false
local FoundRemote = nil

local function TryScanRemotes()
	if FoundRemote then return end
	local checkTime = 0.5
	local wordList = {
		"delete","remove","destroy","clean","clear","bullet","shoot","shot","fire",
		"sword","attack","despawn","handto","close","deletar","apagar"
	}
	local testInstance = LocalPlayer:WaitForChild("StarterGear", 1)
	if not testInstance then return end
	local remotes = {}

	local function checkRemote(remote)
		if not remote.Parent then return end
		if remote.Parent.Name == "RobloxReplicatedStorage" then return end
		remote:FireServer(testInstance)
		task.wait(checkTime + (LocalPlayer:GetNetworkPing() * 2))
		if LocalPlayer:FindFirstChild("StarterGear") then return end
		FoundRemote = remote
		return true
	end

	local function softScan(instance)
		for _, v in next, instance:GetDescendants() do
			if FoundRemote then return end
			if not v:IsA("RemoteEvent") then continue end
			if table.find(remotes, v) then continue end
			table.insert(remotes, v)
			for _, phrase in next, wordList do
				if not v.Name:lower():find(phrase) then continue end
				checkRemote(v)
				break
			end
		end
	end

	local function hardScan(instance)
		for _, v in next, instance:GetDescendants() do
			if FoundRemote then return end
			if not v:IsA("RemoteEvent") then continue end
			if table.find(remotes, v) then continue end
			table.insert(remotes, v)
			checkRemote(v)
		end
	end

	local rStorage = game:GetService("ReplicatedStorage")
	softScan(rStorage)
	if not FoundRemote then softScan(LocalPlayer:FindFirstChildOfClass("PlayerGui")) end
	if not FoundRemote then softScan(Workspace) end
	if not FoundRemote then hardScan(rStorage) end
	if not FoundRemote then hardScan(LocalPlayer:FindFirstChildOfClass("PlayerGui")) end
	if not FoundRemote then hardScan(Workspace) end
	if not FoundRemote then
		for _, service in next, game:GetChildren() do
			if FoundRemote then break end
			pcall(function() hardScan(service) end)
		end
	end
end

local function DeleteViaRemote(instance)
	if not FoundRemote then return end
	if instance == FoundRemote then return end
	pcall(function() FoundRemote:FireServer(instance) end)
end

local function KillPlayerViaRemote(targetHum)
	if not FoundRemote or not ScanRemotesActive then return end
	if not targetHum then return end
	local char = targetHum.Parent
	if not char then return end
	-- Tenta matar via neck
	local head = char:FindFirstChild("Head")
	if head then
		local neck = head:FindFirstChild("Neck")
		if neck then pcall(function() DeleteViaRemote(neck) end) return end
	end
	local torso = char:FindFirstChild("Torso")
	if torso then
		local neck = torso:FindFirstChild("Neck")
		if neck then pcall(function() DeleteViaRemote(neck) end) end
	end
end
-- ============================================================

local HacklordInfo = {
	Health = 1100;
	Speed = 8;
	SprintSpeed = 27;
	SlashDamage = 20;
	SlashPoisonLevel = 1;
	SlashPoisonDuration = 5;
	SlashGlitchLevel = 1;
	SlashGlitchDuration = 5;
	ExecutionDamage = 20;
	MassInfectionSlashDamage = 5;
	MassInfectionCloseSlashDamage = 58.33;
	MassInfectionSlashPoisonLevel = 5;
	MassInfectionSlashPoisonDuration = 3;
	MassInfectionShockwaveSpeed = 120;
	MassInfectionShockwaveLifetime = 6;
	MassInfectionShockwaveDamage = 35;
	MassInfectionShockwavePoisonLevel = 1;
	MassInfectionShockwavePoisonDuration = 5;
	MassInfectionShockwaveAuraDuration = 2;
	EntanglementSpeed = 125;
	EntanglementDamage = 10;
	EntanglementLifetime = 10;
	EntanglementPoisonLevel = 2;
	EntanglementPoisonDuration = 16;
	EntanglementAuraDuration = 2;
	EntanglementKillerSpeedBuffDuration = 3;
	UnstableEyeBuffDuration = 6.5;
	UnstableEyeDebuffDuration = 6.5;
	UnstableEyeAuraDuration = 5;
	ZombieHealth = 10;
	ZombieWalkSpeed = 6;
	ZombieSprintSpeed = 17.5;
	ZombieAttackCooldown = 3;
	ZombieAttackDamage = 14;
	ZombieAttackRange = 5;
	ZombieTargetRange = 30;
	ZombieLoseFocusRange = 50;
	ZombieKillSpeedLevel = 1;
	ZombieKillSpeedDuration = 10;
	ZombieLifeTime = 20;
	HighlightProperties = {
		FillColor = Color3.fromRGB(113, 94, 255);
		OutlineColor = Color3.fromRGB(2, 59, 10);
		FillTransparency = 1;
		OutlineTransparency = 0;
	};
	TargetHighlightProperties = {
		FillColor = Color3.fromRGB(255, 224, 20);
		OutlineColor = Color3.fromRGB(255, 255, 0);
		FillTransparency = 0.4;
		OutlineTransparency = 0.25;
	};
	ShockwaveTemplate = Miscs.shockwave;
	SwordsTemplate = Miscs.Swords;
	SwordTrail = Accessories.HaxxedGripR.ErlkingWeaponLeft.Trail;
	SavedAnimations = {};
	Sounds = {
		Footsteps = {loadedassets["Footstep.ogg"], loadedassets["Footstep2.ogg"]};
		Swing = loadedassets["Slash.ogg"];
		Entanglement = loadedassets["Entanglement.ogg"];
		EntanglementThrow = loadedassets["EntanglementThrow.ogg"];
		MassInfection = loadedassets["MassInfection.ogg"];
		UnstableEye = loadedassets["UnstableEye.ogg"];
		Rejuvenate = loadedassets["Rejuvenate.ogg"];
		Execution = loadedassets["Execution.ogg"];
		Unknown = loadedassets["Unknown.ogg"]
	};
	Themes = {
		Layer1 = loadedassets["Layer1.mp3"];
		Layer2 = loadedassets["Layer2.mp3"];
		Layer3 = loadedassets["Layer3.mp3"];
		Layer4 = loadedassets["Chase.mp3"];
		LMS = loadedassets["LMS.mp3"]
	}
}

local CurrentSpeed = HacklordInfo.Speed
HacklordInfo.SwordTrail.Enabled = false

local RootPart = Character:WaitForChild("HumanoidRootPart")
local Head = Character.Head
local Torso = Character.Torso
local RightArm = Character["Right Arm"]
local LeftArm = Character["Left Arm"]
local RightLeg = Character["Right Leg"]
local LeftLeg = Character["Left Leg"]
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local FolderStorage = New("Folder", Workspace)
local Highlights = New("Model", FolderStorage)
local VictimFolder = New("Model", FolderStorage)
local AllyFolder = New("Model", FolderStorage)
local HitboxFolder = New("Model", FolderStorage)
local State = New("StringValue", Character)
local Layer = NewInstance("IntValue", Character, {Value = 0})
local Device = NewInstance("StringValue", Character, {Value = "PC"})
local WalkMagnitude = 0
local RunMagnitude = 0
local HitmarkerUI

local XRay = NewInstance("Highlight", Highlights, {
	Enabled = false, Adornee = Highlights,
	FillColor = HacklordInfo.TargetHighlightProperties.FillColor,
	OutlineColor = HacklordInfo.TargetHighlightProperties.OutlineColor,
	FillTransparency = 1, OutlineTransparency = 1
})
local BlurEffect = NewInstance("BlurEffect", Lighting, {Enabled = false, Size = 0})
local Neck = Torso:FindFirstChild("Neck") or NewInstance("Motor6D", Torso, {Name = "Neck"})
local RootJoint = RootPart:FindFirstChild("RootJoint") or NewInstance("Motor6D", RootPart, {Name = "RootJoint"})
local TerrorTheme = NewInstance("Sound", RootPart, {Volume = 3.5, Looped = true, MaxDistance = 10000})
local LMS = NewInstance("Sound", Character, {Volume = 2.5, Looped = true})
local Lerp = function(a, b, t) return a:Lerp(b, math.min(deltatime * 4 + t, 1)) end
local NLerp = function(a, b, t) return a + (b - a) * math.min(deltatime * 4 + t, 1) end
local LocalAnimator = AnimationModule.new(Humanoid)
local Animators = {LocalAnimator}
local AnimationTracks = {}

table.insert(CleanUp, FolderStorage)
table.insert(CleanUp, BlurEffect)

local AddDebris = function(Object, Time)
	task.spawn(function()
		local stop = osclock() + Time
		while osclock() <= stop do Heartbeat:Wait() end
		if Object then Object:Destroy() end
	end)
end

pcall(function()
	local Description = Humanoid:GetAppliedDescription()
	Zombie.Parent = FolderStorage
	local zModel = Zombie.Zombie
	if zModel then
		if not zModel:FindFirstChild("HumanoidRootPart") then
			local hrp = Instance.new("Part")
			hrp.Name = "HumanoidRootPart"
			hrp.Size = Vector3.new(2, 2, 1)
			hrp.Transparency = 1
			hrp.CanCollide = false
			hrp.Parent = zModel
			zModel.PrimaryPart = hrp
			local torso = zModel:FindFirstChild("Torso") or zModel:FindFirstChild("UpperTorso")
			if torso then
				local weld = Instance.new("Motor6D", hrp)
				weld.Name = "RootJoint"
				weld.Part0 = hrp
				weld.Part1 = torso
			end
		end
		if not zModel:FindFirstChild("Head") then
			local torso = zModel:FindFirstChild("Torso") or zModel:FindFirstChild("UpperTorso")
			if torso then
				local head = Instance.new("Part")
				head.Name = "Head"
				head.Size = Vector3.new(2, 1, 1)
				head.Transparency = 1
				head.CanCollide = false
				head.Massless = true
				head.CastShadow = false
				head.Parent = zModel
				local neck = Instance.new("Motor6D", torso)
				neck.Name = "Neck"
				neck.Part0 = torso
				neck.Part1 = head
				neck.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
				neck.C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
			end
		end
	end
	Zombie.Zombie:FindFirstChildOfClass("Humanoid"):ApplyDescription(Description)
	PreRender:Wait()
	Zombie.Parent = nil
end)

Accessories.Parent = Character
pcall(function()
	for _, v in next, Accessories:GetChildren() do
		local Weld = v:FindFirstChildOfClass("Weld") or v:FindFirstChildOfClass("Motor6D")
		if Weld then
			if v:FindFirstChild("HaxxedGripR") then
				Weld.Part0 = RootPart
				v.Parent = RootPart
			elseif v:FindFirstChild("HaxxedGripL") then
				Weld.Part0 = RootPart
				v.Parent = RootPart
			else
				if v:FindFirstChild("BodyBackAttachment") then
					Weld.Part1 = Torso
					Weld.C0 *= CFrame.new(0,-0.2,0)
				elseif v:FindFirstChild("LeftShoulderAttachment") then
					Weld.Part1 = LeftArm
					Weld.C0 *= CFrame.new(0,-0.3,0)
				elseif v:FindFirstChild("RightShoulderAttachment") then
					Weld.Part1 = RightArm
					Weld.C0 *= CFrame.new(0,-0.3,0)
				elseif v:FindFirstChild("HatAttachment") then
					Weld.Part1 = Head
				elseif v:FindFirstChild("FaceCenterAttachment") then
					Weld.Part1 = Head
				elseif v:FindFirstChild("BodyFrontAttachment") then
					Weld.Part1 = Torso
					Weld.C0 *= CFrame.new(0,-0.2,0)
				elseif v:FindFirstChild("HairAttachment") then
					Weld.Part1 = Head
				elseif v:FindFirstChild("RightGripAttachment") then
					Weld.Part0 = RightArm
				elseif v:FindFirstChild("LeftHipAttachment") then
					Weld.Part1 = LeftLeg
				elseif v:FindFirstChild("RightKneeRigAttachment") then
					Weld.Part1 = RightLeg
				elseif v:FindFirstChild("LeftKneeRigAttachment") then
					Weld.Part1 = LeftLeg
				elseif v:FindFirstChild("LeftElbowRigAttachment") then
					Weld.Part1 = LeftArm
				elseif v:FindFirstChild("RightElbowRigAttachment") then
					Weld.Part1 = RightArm
				end
			end
			v.Anchored = false
		end
	end
end)

for _, v in next, Animations:GetChildren() do
	local Name = v.Name
	HacklordInfo.SavedAnimations[Name] = v
	v.Parent = Humanoid
	if not string.find(Name, "Zombie") then
		AnimationTracks[Name] = LocalAnimator:LoadAnimation(v)
	end
end

NewInstance("Highlight", Character, {
	Adornee = Character,
	DepthMode = Enum.HighlightDepthMode.Occluded,
	FillColor = HacklordInfo.HighlightProperties.FillColor,
	OutlineColor = HacklordInfo.HighlightProperties.OutlineColor,
	FillTransparency = HacklordInfo.HighlightProperties.FillTransparency,
	OutlineTransparency = HacklordInfo.HighlightProperties.OutlineTransparency
})
NewInstance("Highlight", AllyFolder, {
	Adornee = AllyFolder,
	DepthMode = Enum.HighlightDepthMode.Occluded,
	FillColor = HacklordInfo.HighlightProperties.FillColor,
	OutlineColor = HacklordInfo.HighlightProperties.OutlineColor,
	FillTransparency = HacklordInfo.HighlightProperties.FillTransparency,
	OutlineTransparency = HacklordInfo.HighlightProperties.OutlineTransparency
})

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.RespectCanCollide = true
RayParams.FilterDescendantsInstances = {Character}

local OverlayParams = OverlapParams.new()
OverlayParams.FilterType = Enum.RaycastFilterType.Exclude
OverlayParams.RespectCanCollide = false
OverlayParams.FilterDescendantsInstances = {Character}

local ReturnRoot = function(c)
	return c:FindFirstChild("HumanoidRootPart")
		or c:FindFirstChild("Torso")
		or c:FindFirstChild("UpperTorso")
		or c:FindFirstChild("Head")
		or c.PrimaryPart
end

local FWait = function(t)
	if t then
		local stop = osclock() + t
		while osclock() <= stop do Heartbeat:Wait() end
		return osclock() - stop
	else
		return Heartbeat:Wait()
	end
end

local RWait = function(t)
	if t then
		local stop = osclock() + t
		while osclock() <= stop do PreRender:Wait() end
		return osclock() - stop
	else
		return PreRender:Wait()
	end
end

local lastsync = current
local IsRightTime = function(ContinueTime)
	if ContinueTime then
		local Now = osclock()
		if Now - lastsync >= ContinueTime / 2 then
			lastsync = Now
			return true
		else
			return false
		end
	end
	return false
end

if Character:FindFirstChild("Animate") then Character.Animate:Destroy() end
if Humanoid:FindFirstChildOfClass("Animator") then Humanoid:FindFirstChildOfClass("Animator"):Destroy() end
for _, v in next, Character:GetDescendants() do
	if v:IsA("Motor6D") then v.Transform = CFrame.identity end
end

local NewSFX = function(ContentId, CF, Volume, Speed, TimePos)
	local SoundPart = NewInstance("Part", RootPart, {
		CFrame = CF or RootPart.CFrame,
		Size = Vector3.new(0.1, 0.1, 0.1),
		CanCollide = false, Anchored = true, Transparency = 1,
		Massless = true, CanQuery = false, CanTouch = false, CastShadow = false
	})
	local Sound = New("Sound", SoundPart)
	Sound.SoundId = ContentId or ""
	Sound.Volume = Volume or 0.5
	Sound.PlaybackSpeed = Speed or 1
	Sound.TimePosition = TimePos or 0
	Sound.Playing = true
	Sound.Ended:Once(function() SoundPart:Destroy() end)
end

local NewHitmarker = function(ContentId, Volume)
	local Sound = New("Sound", Character)
	Sound.SoundId = ContentId or ""
	Sound.Volume = Volume or 0.5
	Sound.Playing = true
	Sound.Ended:Once(function() Sound:Destroy() end)
end

local TriggerLMS = function(Bool)
	if Bool == true then
		LMSActive = true
		if not LMS.Playing then
			LMS.SoundId = HacklordInfo.Themes.LMS
			LMS.Volume = 4.5
			LMS.TimePosition = 0
			LMS.Looped = true
			LMS.Playing = true
		end
	else
		LMSActive = false
		LMS.Playing = false
	end
end

local IndicateDamage = function(Humanoid, Value)
	if not Humanoid then return end
	if not Settings.Hitmarker then return end
	local c = Humanoid.Parent
	local Root = c:FindFirstChild("HumanoidRootPart")
		or c:FindFirstChild("Torso")
		or c:FindFirstChild("UpperTorso")
		or c:FindFirstChild("Head")
		or c.PrimaryPart
	if HitmarkerUI and RootPart then
		local Part = NewInstance("Part", RootPart, {
			CFrame = Root.CFrame * CFrame.new(math.random(-2,2), math.random(-2,2), math.random(-2,2)),
			Size = Vector3.new(1,1,1), CanCollide = false, Anchored = true,
			Transparency = 1, Massless = true, CanQuery = false, CanTouch = false, CastShadow = false
		})
		local HMClone = HitmarkerUI:Clone()
		local Title = HMClone.Title
		HMClone.Adornee = Part
		HMClone.Parent = Part
		local Size = HMClone.Size + UDim2.fromScale(2,2)
		Title.Text = math.round(Value * 100) / 100
		TweenService:Create(HMClone, TweenInfo.new(0.25), {Size = Size}):Play()
		FWait(1)
		AddDebris(Part, 1.5)
		TweenService:Create(Title, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
		TweenService:Create(Title.UIStroke, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
	end
end

local InitHealthSystem = function(Humanoid)
	local HealthInstance = Humanoid:FindFirstChild("HacklordingIt_Health")
	if HealthInstance then
		if HealthInstance.Value <= 0 then
			HealthInstance.Value = Humanoid.Health > 0 and Humanoid.Health or 100
		end
		return HealthInstance, HealthInstance.Value
	else
		local CurrentHealth = Humanoid.Health > 0 and Humanoid.Health or 100
		HealthInstance = NewInstance("NumberValue", Humanoid, {Name = "HacklordingIt_Health", Value = CurrentHealth})
		return HealthInstance, CurrentHealth
	end
end

local Damage = function(Humanoid, Value, OnDeathFunction)
	if typeof(Humanoid) ~= "Instance" then return end
	if Humanoid:FindFirstChild("HacklordIsHere") or Humanoid:FindFirstChild("HacklordAllies") then return end
	local HealthInstance, Health = InitHealthSystem(Humanoid)
	if Health <= 0 then return end
	local CurrentHealth = math.max(Health - Value, 0)
	local DamageDealt = Health - CurrentHealth

	-- Dano local sempre (NPCs e efeitos visuais)
	pcall(function() Humanoid.Health = math.max(Humanoid.Health - Value, 0) end)

	-- Se ScanRemotes ativo e for jogador real, tenta matar via remote
	if ScanRemotesActive and FoundRemote then
		local isPlayer = Players:GetPlayerFromCharacter(Humanoid.Parent) ~= nil
		if isPlayer then
			task.spawn(KillPlayerViaRemote, Humanoid)
		end
	end

	NewHitmarker("rbxassetid://1129547534", 2.5)
	task.spawn(IndicateDamage, Humanoid, DamageDealt)

	if CurrentHealth <= 5 then
		HealthInstance.Value = 0
		pcall(function() Humanoid.Health = 0 end)
		if OnDeathFunction then task.spawn(OnDeathFunction, Humanoid) end
		if Humanoid:FindFirstChild("HacklordAllies") then
			SpeedStackLevel.Value += 1
			SpeedEffectEndTime = osclock() + 6
		end
	else
		HealthInstance.Value = CurrentHealth
	end
end

local VisualHitbox = function(Origin, RangeOrVector)
	if not Settings.VisibleHitbox then return nil end
	if typeof(RangeOrVector) == "Vector3" then
		local HB = NewInstance("Part", HitboxFolder, {
			Name = "VisualHitbox_Debug", Anchored = true, CanCollide = false,
			CanTouch = false, CanQuery = false, Massless = true, CastShadow = false,
			Size = RangeOrVector, CFrame = Origin, Transparency = 0.5,
			Color = Color3.new(1,0,0), Material = "ForceField"
		})
		AddDebris(HB, 0.3)
		return HB
	elseif typeof(RangeOrVector) == "number" then
		local HB = NewInstance("Part", HitboxFolder, {
			Name = "VisualHitbox_Debug", Anchored = true, CanCollide = false,
			CanTouch = false, CanQuery = false, Massless = true, CastShadow = false,
			Size = Vector3.new(RangeOrVector, RangeOrVector, RangeOrVector) * 2,
			CFrame = Origin, Transparency = 0.5, Color = Color3.new(1,0,0), Material = "ForceField"
		})
		AddDebris(HB, 0.3)
		return HB
	end
end

local DamageFromHitbox = function(ScanCount, WaitEachScan, From, Offset, Size, Value, StopAfterHit, HitOneTargetOnly, OnDeathFunction)
	if not From then return end
	local Humanoids = {}
	local Stop = false
	local StopEntirely = false
	Offset = Offset or CFrame.identity
	local HB = NewInstance("Part", RootPart, {
		Name = "Hitbox", Anchored = true, CanCollide = false,
		CanTouch = false, CanQuery = false, Massless = true, CastShadow = false,
		Size = Size, Transparency = 1
	})
	task.spawn(function()
		for _ = 1, ScanCount or 1 do
			if Stop then if HB then HB:Destroy() end break end
			local Origin = From.CFrame * Offset
			HB.CFrame = Origin
			local Parts = Workspace:GetPartsInPart(HB, OverlayParams)
			local VisualHB = VisualHitbox(Origin, Size)
			for _, Part in next, Parts do
				if StopEntirely then break end
				local Model = Part.Parent
				if Model:IsA("Model") then
					local Humanoid = Model:FindFirstChildOfClass("Humanoid")
					if Humanoid then
						local HealthInstance, Health = InitHealthSystem(Humanoid)
						if Health ~= 0 and not table.find(Humanoids, Humanoid) then
							table.insert(Humanoids, Humanoid)
							Damage(Humanoid, Value, OnDeathFunction)
							if VisualHB then VisualHB.Color = Color3.new(0,0.8,0) end
							if HitOneTargetOnly then StopEntirely = true Stop = true end
							if StopAfterHit then Stop = true end
						end
					end
				end
			end
			RWait(WaitEachScan or 0.1)
		end
		if HB then HB:Destroy() end
	end)
	return function() Stop = true end
end

local BaseIdle = AnimationTracks["Idle"]
local BaseWalk = AnimationTracks["Walk"]
local BaseRun = AnimationTracks["Run"]
local BaseSlash = AnimationTracks["Slash"]
local Introduction = AnimationTracks["Introduction"]
local Execution = AnimationTracks["ExecutionKillerRig"]
local BaseEntanglement = AnimationTracks["Entanglement"]
local BaseMassInfection = AnimationTracks["MassInfection"]
local BaseUnstableEye = AnimationTracks["UnstableEye"]
local BaseRejuvenateTheRotten = AnimationTracks["RejuvenateTheRotten"]

BaseIdle.Priority = Enum.AnimationPriority.Idle
BaseWalk.Priority = Enum.AnimationPriority.Movement
BaseRun.Priority = Enum.AnimationPriority.Movement
BaseSlash.Priority = Enum.AnimationPriority.Action
BaseEntanglement.Priority = Enum.AnimationPriority.Action2
BaseMassInfection.Priority = Enum.AnimationPriority.Action2
BaseUnstableEye.Priority = Enum.AnimationPriority.Action2
BaseRejuvenateTheRotten.Priority = Enum.AnimationPriority.Action2
Introduction.Priority = Enum.AnimationPriority.Action3
Execution.Priority = Enum.AnimationPriority.Action3

local ApplyRagdoll = function(Character)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		for _, v in next, Character:GetDescendants() do
			if v:IsA("Motor6D") then
				local Part0, Part1 = v.Part0, v.Part1
				if Part0 and Part1 then
					local Att0 = NewInstance("Attachment", Part0, {CFrame = v.C0})
					local Att1 = NewInstance("Attachment", Part1, {CFrame = v.C1})
					NewInstance("BallSocketConstraint", Character, {
						Attachment0 = Att0, Attachment1 = Att1,
						LimitsEnabled = true, TwistLimitsEnabled = true,
						UpperAngle = 90, TwistLowerAngle = -45, TwistUpperAngle = 45
					})
					v.Enabled = false
				end
			elseif v:IsA("BasePart") then
				v.CanCollide = false
				v.Anchored = false
				v.Massless = false
			end
		end
	end
end

local function CreateVictimRig()
	local char = New("Model")
	char.Name = "_ExecutionVictimRig"
	local hum = New("Humanoid", char)
	hum.Name = "Humanoid"
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.Health = 100
	hum.MaxHealth = 100
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local function makePart(name, size, pos)
		local part = New("Part", char)
		part.Name = name
		part.Size = size
		part.Position = pos
		part.Anchored = false
		part.CanCollide = false
		part.Transparency = 1
		part.CastShadow = false
		part.Massless = true
		return part
	end
	local root     = makePart("HumanoidRootPart", Vector3.new(2,2,1),   Vector3.new(0,0,0))
	local torso    = makePart("Torso",            Vector3.new(2,2,1),   Vector3.new(0,0,0))
	local head     = makePart("Head",             Vector3.new(2,1,1),   Vector3.new(0,1.5,0))
	local leftArm  = makePart("Left Arm",         Vector3.new(1,2,1),   Vector3.new(-1.5,0,0))
	local rightArm = makePart("Right Arm",        Vector3.new(1,2,1),   Vector3.new(1.5,0,0))
	local leftLeg  = makePart("Left Leg",         Vector3.new(1,2,1),   Vector3.new(-0.5,-2,0))
	local rightLeg = makePart("Right Leg",        Vector3.new(1,2,1),   Vector3.new(0.5,-2,0))
	local function makeMotor(name, p0, p1, c0, c1)
		local m = Instance.new("Motor6D", p0)
		m.Name = name m.Part0 = p0 m.Part1 = p1 m.C0 = c0 m.C1 = c1
		return m
	end
	makeMotor("RootJoint",      root,   torso,    CFrame.new(0,0,0,-1,0,0,0,0,1,0,1,0),    CFrame.new(0,0,0,-1,0,0,0,0,1,0,1,0))
	makeMotor("Neck",           torso,  head,     CFrame.new(0,1,0,-1,0,0,0,0,1,0,1,0),    CFrame.new(0,-0.5,0,-1,0,0,0,0,1,0,1,0))
	makeMotor("Left Shoulder",  torso,  leftArm,  CFrame.new(-1,0.5,0,0,0,-1,0,1,0,1,0,0), CFrame.new(0.5,0.5,0,0,0,-1,0,1,0,1,0,0))
	makeMotor("Right Shoulder", torso,  rightArm, CFrame.new(1,0.5,0,0,0,1,0,1,0,-1,0,0),  CFrame.new(-0.5,0.5,0,0,0,1,0,1,0,-1,0,0))
	makeMotor("Left Hip",       torso,  leftLeg,  CFrame.new(-1,-1,0,0,0,-1,0,1,0,1,0,0),  CFrame.new(-0.5,1,0,0,0,-1,0,1,0,1,0,0))
	makeMotor("Right Hip",      torso,  rightLeg, CFrame.new(1,-1,0,0,0,1,0,1,0,-1,0,0),   CFrame.new(0.5,1,0,0,0,1,0,1,0,-1,0,0))
	char.PrimaryPart = root
	return char, hum, root
end

local function SetMotor6DTransform(motor, transform)
	motor.MaxVelocity = 9e9
	pcall(function()
		local axis, angle = transform:ToAxisAngle()
		sethiddenproperty(motor, "ReplicateCurrentOffset6D", transform.Position)
		sethiddenproperty(motor, "ReplicateCurrentAngle6D", axis * angle)
	end)
	pcall(function() motor.Transform = transform end)
end

local function SetMotor6DOffset(motor, offset)
	SetMotor6DTransform(motor, motor.C0:Inverse() * offset * motor.C1)
end

local VICTIM_LIMB_MAPPING = {
	{RPart0="ROOT",  RPart1="Torso",     Part0=nil,     Part1="Torso",     Type=2, C0={0,0,0,-1,0,0,0,0,1,0,1,0},    C1={0,0,0,-1,0,0,0,0,1,0,1,0}},
	{RPart0="Torso", RPart1="Head",      Part0="Torso", Part1="Head",      Type=2, C0={0,1,0,-1,0,0,0,0,1,0,1,0},    C1={0,-0.5,0,-1,0,0,0,0,1,0,1,0}},
	{RPart0="Torso", RPart1="Left Arm",  Part0="Torso", Part1="Left Arm",  Type=2, C0={-1,0.5,0,0,0,-1,0,1,0,1,0,0}, C1={0.5,0.5,0,0,0,-1,0,1,0,1,0,0}},
	{RPart0="Torso", RPart1="Right Arm", Part0="Torso", Part1="Right Arm", Type=2, C0={1,0.5,0,0,0,1,0,1,0,-1,0,0},  C1={-0.5,0.5,0,0,0,1,0,1,0,-1,0,0}},
	{RPart0="Torso", RPart1="Left Leg",  Part0="Torso", Part1="Left Leg",  Type=2, C0={-1,-1,0,0,0,-1,0,1,0,1,0,0},  C1={-0.5,1,0,0,0,-1,0,1,0,1,0,0}},
	{RPart0="Torso", RPart1="Right Leg", Part0="Torso", Part1="Right Leg", Type=2, C0={1,-1,0,0,0,1,0,1,0,-1,0,0},   C1={0.5,1,0,0,0,1,0,1,0,-1,0,0}},
}

local function TableToCFrame(t)
	return CFrame.new(t[1],t[2],t[3], t[4],t[7],t[10], t[5],t[8],t[11], t[6],t[9],t[12])
end

local function BuildVictimMotorMap(npcChar, rigChar)
	local npcMotors = {}
	for _, v in next, npcChar:GetDescendants() do
		if v:IsA("Motor6D") and v.Part0 and v.Part1 then
			npcMotors[v.Part0.Name.."|"..v.Part1.Name] = v
		end
	end
	local result = {}
	for _, map in next, VICTIM_LIMB_MAPPING do
		local motor = nil
		if map.Part1 then
			if map.Part0 then motor = npcMotors[map.Part0.."|"..map.Part1] end
			if not motor then
				for _, v in next, npcChar:GetDescendants() do
					if v:IsA("Motor6D") and v.Part1 and v.Part1.Name == map.Part1 then
						motor = v break
					end
				end
			end
		end
		local rigP0 = map.RPart0 == "ROOT" and rigChar:FindFirstChild("HumanoidRootPart") or rigChar:FindFirstChild(map.RPart0)
		local rigP1 = rigChar:FindFirstChild(map.RPart1)
		if motor and rigP0 and rigP1 then
			table.insert(result, {
				motor = motor, rigP0 = rigP0, rigP1 = rigP1,
				mapType = map.Type,
				C0 = map.C0 and TableToCFrame(map.C0) or CFrame.identity,
				C1 = map.C1 and TableToCFrame(map.C1) or CFrame.identity,
			})
		end
	end
	return result
end

TriggerExecution = function(Hum)
	if Hum:FindFirstChild("HacklordIsHere") or Hum:FindFirstChild("HacklordAllies") then return end
	NewInstance("StringValue", Hum, {Name = "HacklordIsHere"})
	local NpcCharacter = Hum.Parent
	if not NpcCharacter then return end
	local NpcRoot = ReturnRoot(NpcCharacter)
	if not NpcRoot then return end
	local SavedShiftlockOn = ShiftlockOn
	ShiftlockOn = nil
	local oldDebouchePriority = debouchepriority
	debouchepriority = 999
	debouche = true
	Hum.BreakJointsOnDeath = false
	pcall(function() Hum.WalkSpeed  = 0 end)
	pcall(function() Hum.JumpHeight = 0 end)
	pcall(function() Hum.JumpPower  = 0 end)
	pcall(function() Hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
	local VictimRig, VictimHum, VictimRoot = CreateVictimRig()
	VictimRig.Parent = VictimFolder
	local execOffset = CFrame.new(0, 0, -3)
	if RootPart then VictimRoot.CFrame = RootPart.CFrame * execOffset end
	local VictimAnimator = AnimationModule.new(VictimHum)
	local VictimTrack = nil
	pcall(function()
		if HacklordInfo.SavedAnimations["ExecutionVictimRig"] then
			VictimTrack = VictimAnimator:LoadAnimation(HacklordInfo.SavedAnimations["ExecutionVictimRig"])
			VictimTrack.Priority = Enum.AnimationPriority.Action4
			VictimTrack:Play(1, 10)
		end
	end)
	local MotorMap = BuildVictimMotorMap(NpcCharacter, VictimRig)
	local MirrorConn = PreRender:Connect(function()
		if not VictimRig or not VictimRig.Parent then return end
		if not NpcCharacter or not NpcCharacter.Parent then return end
		if NpcRoot and RootPart and RootPart.Parent then
			pcall(function()
				NpcRoot.CFrame = RootPart.CFrame * execOffset
				NpcRoot.AssemblyLinearVelocity = Vector3.zero
				NpcRoot.AssemblyAngularVelocity = Vector3.zero
			end)
		end
		for _, entry in next, MotorMap do
			pcall(function()
				local motor = entry.motor
				local p0 = entry.rigP0
				local p1 = entry.rigP1
				local cf = CFrame.identity
				if entry.mapType == 1 then
					cf = p0.CFrame:ToObjectSpace(p1.CFrame)
				elseif entry.mapType == 2 then
					local transform = (p0.CFrame * entry.C0):ToObjectSpace(p1.CFrame * entry.C1)
					cf = motor.C0 * transform * motor.C1:Inverse()
				end
				SetMotor6DOffset(motor, cf)
			end)
		end
	end)
	if Execution then Execution:Play(1, 10) end
	NewSFX(HacklordInfo.Sounds.Execution, RootPart.CFrame, 4, 1)
	task.delay(0.75, function() if RootPart and RootPart.Parent then DamageFromHitbox(1,0,RootPart,CFrame.new(0,0,-4),Vector3.new(6.6,5.5,8),HacklordInfo.ExecutionDamage) end end)
	task.delay(1.40, function() if RootPart and RootPart.Parent then DamageFromHitbox(1,0,RootPart,CFrame.new(0,0,-4),Vector3.new(6.6,5.5,8),HacklordInfo.ExecutionDamage) end end)
	task.delay(2.05, function() if RootPart and RootPart.Parent then DamageFromHitbox(1,0,RootPart,CFrame.new(0,0,-4),Vector3.new(6.6,5.5,8),HacklordInfo.ExecutionDamage) end end)
	local function OnExecutionEnded()
		MirrorConn:Disconnect()
		if VictimTrack    then pcall(function() VictimTrack:Stop() end) end
		if VictimAnimator then pcall(function() VictimAnimator:Destroy() end) end
		if VictimRig      then pcall(function() VictimRig:Destroy() end) end
		if NpcCharacter and NpcCharacter.Parent then
			pcall(function() Hum.WalkSpeed=0 Hum.JumpHeight=0 Hum.JumpPower=0 Hum.Health=0 end)
			for _, v in next, NpcCharacter:GetDescendants() do
				if v:IsA("BasePart") or v:IsA("Decal") then
					pcall(function() TweenService:Create(v,TweenInfo.new(0.5),{Transparency=1}):Play() end)
				end
			end
			task.delay(0.55, function() pcall(function() NpcCharacter:Destroy() end) end)
		end
		if Execution then Execution:Stop(0.3) end
		ShiftlockOn = SavedShiftlockOn ~= nil and SavedShiftlockOn or false
		debouchepriority = oldDebouchePriority
		debouche = false
	end
	if Execution then
		Execution.Ended:Once(OnExecutionEnded)
		task.delay(8, function() if debouche then OnExecutionEnded() end end)
	else
		task.delay(3.5, OnExecutionEnded)
	end
end

local function FixZombieJoints(Model)
	local Torso    = Model:FindFirstChild("Torso")
	local Head     = Model:FindFirstChild("Head")
	local LeftArm  = Model:FindFirstChild("Left Arm")
	local RightArm = Model:FindFirstChild("Right Arm")
	local LeftLeg  = Model:FindFirstChild("Left Leg")
	local RightLeg = Model:FindFirstChild("Right Leg")
	local HRP      = Model:FindFirstChild("HumanoidRootPart")
	if not Torso then return end
	if not HRP then
		HRP = Instance.new("Part")
		HRP.Name = "HumanoidRootPart"
		HRP.Size = Vector3.new(2,2,1)
		HRP.Transparency = 1
		HRP.CanCollide = false
		HRP.Massless = true
		HRP.CastShadow = false
		HRP.Parent = Model
		Model.PrimaryPart = HRP
	else
		HRP.Transparency = 1
		HRP.CanCollide = false
	end
	if not Head then
		Head = Instance.new("Part")
		Head.Name = "Head"
		Head.Size = Vector3.new(2,1,1)
		Head.Transparency = 1
		Head.CanCollide = false
		Head.Massless = true
		Head.CastShadow = false
		Head.Parent = Model
	end
	local function ensureMotor(name, p0, p1, c0, c1)
		if not p0 or not p1 then return end
		for _, v in next, p0:GetChildren() do
			if v:IsA("Motor6D") and v.Name == name then v:Destroy() end
		end
		local m = Instance.new("Motor6D", p0)
		m.Name = name m.Part0 = p0 m.Part1 = p1 m.C0 = c0 m.C1 = c1
		return m
	end
	ensureMotor("RootJoint",      HRP,   Torso,    CFrame.new(0,0,0,-1,0,0,0,0,1,0,1,0),    CFrame.new(0,0,0,-1,0,0,0,0,1,0,1,0))
	ensureMotor("Neck",           Torso, Head,     CFrame.new(0,1,0,-1,0,0,0,0,1,0,1,0),    CFrame.new(0,-0.5,0,-1,0,0,0,0,1,0,1,0))
	if LeftArm  then ensureMotor("Left Shoulder",  Torso, LeftArm,  CFrame.new(-1,0.5,0,0,0,-1,0,1,0,1,0,0), CFrame.new(0.5,0.5,0,0,0,-1,0,1,0,1,0,0)) end
	if RightArm then ensureMotor("Right Shoulder", Torso, RightArm, CFrame.new(1,0.5,0,0,0,1,0,1,0,-1,0,0),  CFrame.new(-0.5,0.5,0,0,0,1,0,1,0,-1,0,0)) end
	if LeftLeg  then ensureMotor("Left Hip",       Torso, LeftLeg,  CFrame.new(-1,-1,0,0,0,-1,0,1,0,1,0,0),  CFrame.new(-0.5,1,0,0,0,-1,0,1,0,1,0,0)) end
	if RightLeg then ensureMotor("Right Hip",      Torso, RightLeg, CFrame.new(1,-1,0,0,0,1,0,1,0,-1,0,0),   CFrame.new(0.5,1,0,0,0,1,0,1,0,-1,0,0)) end
	for _, v in next, Model:GetDescendants() do
		if v:IsA("BasePart") then
			v.Anchored = true
			v.Velocity = Vector3.zero
			v.RotVelocity = Vector3.zero
			v.AssemblyLinearVelocity = Vector3.zero
			v.AssemblyAngularVelocity = Vector3.zero
		end
	end
	for _, v in next, Model:GetDescendants() do
		if v:IsA("Motor6D") then v.Transform = CFrame.identity end
	end
	task.defer(function()
		for _, v in next, Model:GetDescendants() do
			if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
				v.Anchored = false
			end
		end
	end)
	Model.PrimaryPart = HRP
end

local ApplyAI = function(Model)
	local Humanoid = Model:FindFirstChildOfClass("Humanoid")
	FixZombieJoints(Model)
	local MinionRoot = Model:FindFirstChild("HumanoidRootPart")
	local LifeTime       = HacklordInfo.ZombieLifeTime
	local AttackRange    = HacklordInfo.ZombieAttackRange
	local AttackCooldown = HacklordInfo.ZombieAttackCooldown
	local AttackDamage   = HacklordInfo.ZombieAttackDamage
	if not Humanoid then return end
	local Descendants    = Model:GetDescendants()
	local HealthInstance = InitHealthSystem(Humanoid)
	NewInstance("StringValue", Humanoid, {Name = "HacklordAllies"})
	Humanoid.BreakJointsOnDeath = false
	Humanoid.RequiresNeck       = false
	pcall(function() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
	local AAnimator = AnimationModule.new(Humanoid)
	local Idle   = AAnimator:LoadAnimation(HacklordInfo.SavedAnimations["ZombieIdle"])
	local Walk   = AAnimator:LoadAnimation(HacklordInfo.SavedAnimations["ZombieWalk"])
	local Run    = AAnimator:LoadAnimation(HacklordInfo.SavedAnimations["ZombieRun"])
	local Attack = AAnimator:LoadAnimation(HacklordInfo.SavedAnimations["ZombieAttack"])
	local Summon = AAnimator:LoadAnimation(HacklordInfo.SavedAnimations["ZombieSummon"])
	Idle.Priority   = Enum.AnimationPriority.Movement
	Walk.Priority   = Enum.AnimationPriority.Movement
	Run.Priority    = Enum.AnimationPriority.Movement
	Attack.Priority = Enum.AnimationPriority.Action
	Summon.Priority = Enum.AnimationPriority.Action2
	if MinionRoot then MinionRoot.Anchored = true end
	Summon:Play(1, 10)
	Summon.Ended:Wait()
	Summon:Stop(1)
	if MinionRoot then MinionRoot.Anchored = false end
	local MinionState   = "WAITING"
	local TargetHum     = nil
	local TargetRoot    = nil
	local cooldownasync = AttackCooldown
	local DetectionZone = nil
	if MinionRoot then
		DetectionZone = NewInstance("Part", Model, {
			Name = "DetectionZone",
			Size = Vector3.new(18, 10, 18),
			Anchored = true, CanCollide = false, CanTouch = false,
			CanQuery = false, CastShadow = false, Transparency = 1,
			Massless = true, CFrame = MinionRoot.CFrame
		})
	end
	local DetectionParams = OverlapParams.new()
	DetectionParams.FilterType = Enum.RaycastFilterType.Exclude
	DetectionParams.RespectCanCollide = false
	DetectionParams.FilterDescendantsInstances = {Character, Model}
	local function IsValidTarget(char)
		if not char then return false end
		if char == Character then return false end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return false end
		if hum:FindFirstChild("HacklordAllies") then return false end
		if hum:FindFirstChild("HacklordIsHere") then return false end
		local custHP = hum:FindFirstChild("HacklordingIt_Health")
		if custHP and custHP.Value <= 0 then return false end
		if hum.Health <= 0 then return false end
		return true, hum
	end
	local function ScanZone()
		if not DetectionZone then return nil, nil end
		local parts = Workspace:GetPartsInPart(DetectionZone, DetectionParams)
		for _, part in next, parts do
			local model = part.Parent
			if model and model:IsA("Model") then
				local valid, hum = IsValidTarget(model)
				if valid then
					local hrp = model:FindFirstChild("HumanoidRootPart")
						or model:FindFirstChild("Torso")
						or model:FindFirstChild("UpperTorso")
					if hrp then return hum, hrp end
				end
			end
		end
		return nil, nil
	end
	local function GoWaiting()
		MinionState = "WAITING"
		TargetHum   = nil
		TargetRoot  = nil
		if DetectionZone then DetectionZone.Size = Vector3.new(18, 10, 18) end
		pcall(function() Humanoid.WalkSpeed = 0 end)
	end
	local Con
	local End = function()
		for _, v in next, Descendants do
			if v:IsA("BasePart") or v:IsA("Decal") then
				if v.Transparency ~= 1 then
					TweenService:Create(v, TweenInfo.new(0.3), {Transparency = 1}):Play()
				end
			end
		end
		task.delay(0.3, function()
			if Model then Model:Destroy() end
			if AAnimator and not AAnimator._destroyed then AAnimator:Destroy() end
		end)
	end
	local detectionTimer = 0
	local DETECTION_INTERVAL = 0.2
	Con = Heartbeat:Connect(function(dt)
		if PauseEverything then return end
		if StopEverything then
			if AAnimator and not AAnimator._destroyed then AAnimator:Destroy() end
			Con:Disconnect()
			return
		end
		if Humanoid:FindFirstChild("HacklordEntangled") then return end
		cooldownasync += dt
		if MinionState == "WAITING" then
			pcall(function() Humanoid.WalkSpeed = 0 end)
			if DetectionZone and MinionRoot then
				DetectionZone.CFrame = MinionRoot.CFrame
			end
			if not Idle.IsPlaying then
				Idle:Play(1, 10)
				Walk:Stop(0.3)
				Run:Stop(0.3)
			end
			detectionTimer += dt
			if detectionTimer >= DETECTION_INTERVAL then
				detectionTimer = 0
				local foundHum, foundRoot = ScanZone()
				if foundHum and foundRoot then
					MinionState = "CHASING"
					TargetHum   = foundHum
					TargetRoot  = foundRoot
					if DetectionZone then DetectionZone.Size = Vector3.zero end
					task.delay(0.3, function()
						if MinionState == "CHASING" then
							pcall(function() Humanoid.WalkSpeed = HacklordInfo.ZombieSprintSpeed end)
						end
					end)
				end
			end
		elseif MinionState == "CHASING" then
			if not TargetRoot or not TargetRoot.Parent then GoWaiting() return end
			local valid = IsValidTarget(TargetRoot.Parent)
			if not valid then GoWaiting() return end
			Humanoid:MoveTo(TargetRoot.Position)
			if not Run.IsPlaying then
				Run:Play(1, 10)
				Idle:Stop(0.3)
				Walk:Stop(0.3)
			end
			if MinionRoot then
				local dist = (MinionRoot.Position - TargetRoot.Position).Magnitude
				if dist <= AttackRange then MinionState = "ATTACKING" end
			end
		elseif MinionState == "ATTACKING" then
			if not TargetRoot or not TargetRoot.Parent then GoWaiting() return end
			local valid = IsValidTarget(TargetRoot.Parent)
			if not valid then GoWaiting() return end
			pcall(function() Humanoid.WalkSpeed = 0 end)
			if MinionRoot then
				local dist = (MinionRoot.Position - TargetRoot.Position).Magnitude
				if dist > AttackRange + 2 then
					MinionState = "CHASING"
					pcall(function() Humanoid.WalkSpeed = HacklordInfo.ZombieSprintSpeed end)
					return
				end
			end
			if cooldownasync >= AttackCooldown then
				cooldownasync = 0
				Attack:Play(1, 10)
				Damage(TargetHum, AttackDamage)
			end
			if not Attack.IsPlaying and not Idle.IsPlaying then
				Idle:Play(1, 10)
				Run:Stop(0.3)
				Walk:Stop(0.3)
			end
		end
	end)
	Humanoid.Died:Once(function()
		if Con then Con:Disconnect() end
		if DetectionZone then pcall(function() DetectionZone:Destroy() end) end
		if Model then task.spawn(End) end
	end)
	task.spawn(function()
		local stop = osclock() + LifeTime
		while osclock() <= stop do
			if not Model or not Model.Parent then break end
			Heartbeat:Wait()
		end
		if Con then Con:Disconnect() end
		if DetectionZone then pcall(function() DetectionZone:Destroy() end) end
		if Model and Model.Parent then End() end
	end)
	Idle:Play(1, 10)
end

local Sprinting = function()
	IsSprinting = not IsSprinting
end

local Shiftlock = function()
	if ShiftlockOn == nil then return end
	ShiftlockOn = not ShiftlockOn
end

local PlayIntroduction = function()
	if StopEverything or debouche then return end
	HeadLook = false
	debouchepriority = 2
	debouche = true
	Introduction:Play(1,10)
	Introduction.Speed = 0.65
	Introduction.TimePosition = 3.2
	FWait(2.676)
	debouchepriority = 1
	debouche = false
	HeadLook = true
end

local Slash = function()
	if StopEverything or debouche then return end
	local isExecuting = false
	local AttackFunc = function()
		FWait(0.4)
		DamageFromHitbox(10, 0.02, RootPart, CFrame.new(0,0,-3-3*RunMagnitude), Vector3.new(6,5.75,7.5), HacklordInfo.SlashDamage, true, false, function(Hum)
			if Hum:FindFirstChild("HacklordIsHere") or Hum:FindFirstChild("HacklordAllies") then return end
			isExecuting = true
			if TriggerExecution then TriggerExecution(Hum) end
		end)
	end
	debouchepriority = 1
	debouche = true
	HacklordInfo.SwordTrail.Enabled = true
	BaseSlash:Play(1,10)
	NewSFX(HacklordInfo.Sounds.Swing, RootPart.CFrame, 4, 1)
	task.spawn(AttackFunc)
	BaseSlash.Ended:Wait()
	if not isExecuting then
		debouche = false
		HacklordInfo.SwordTrail.Enabled = false
	end
end

local Entanglement = function()
	if StopEverything or debouche then return end
	local CF = RootPart.CFrame * CFrame.new(0, 0, -5)
	local AttackFunc = function()
		FWait(0.48)
		local deltaRadius = 0
		local Speed = HacklordInfo.EntanglementSpeed
		local LifeTime = HacklordInfo.EntanglementLifetime
		local EntanglementDamage = HacklordInfo.EntanglementDamage
		NewSFX(HacklordInfo.Sounds.Entanglement, CF, 2.5, 0.75)
		local Swords = HacklordInfo.SwordsTemplate:Clone()
		local Core = Swords.Core
		Core.Anchored = true
		Core.CFrame = CF
		local EntangledNPCs = {}
		local StopFunc = DamageFromHitbox(2500, 0.01, Core, nil, Core.Size + Vector3.new(2.5,0,5), EntanglementDamage, false, false, nil)
		local EntanglementHitConn
		EntanglementHitConn = Heartbeat:Connect(function()
			if not Core or not Core.Parent then EntanglementHitConn:Disconnect() return end
			local OverParams = OverlapParams.new()
			OverParams.FilterType = Enum.RaycastFilterType.Exclude
			OverParams.RespectCanCollide = false
			OverParams.FilterDescendantsInstances = {Character}
			local Parts = Workspace:GetPartsInPart(Core, OverParams)
			for _, Part in next, Parts do
				local Model = Part.Parent
				if Model and Model:IsA("Model") then
					local TargetHum = Model:FindFirstChildOfClass("Humanoid")
					if TargetHum
						and not TargetHum:FindFirstChild("HacklordAllies")
						and not TargetHum:FindFirstChild("HacklordIsHere")
						and not TargetHum:FindFirstChild("HacklordEntangled")
						and not EntangledNPCs[TargetHum]
					then
						local custHealth = TargetHum:FindFirstChild("HacklordingIt_Health")
						local isAlive = true
						if custHealth and custHealth.Value <= 0 then isAlive = false
						elseif TargetHum.Health <= 0 then isAlive = false end
						if isAlive then
							EntangledNPCs[TargetHum] = true
							task.spawn(function()
								local NpcChar = TargetHum.Parent
								if not NpcChar then return end
								local OriginalWalkSpeed  = TargetHum.WalkSpeed
								local OriginalJumpHeight = TargetHum.JumpHeight
								local OriginalJumpPower  = 0
								pcall(function() OriginalJumpPower = TargetHum.JumpPower end)
								local EntangleTag = NewInstance("StringValue", TargetHum, {Name = "HacklordEntangled"})
								pcall(function() TargetHum.WalkSpeed  = 0 end)
								pcall(function() TargetHum.JumpHeight = 0 end)
								pcall(function() TargetHum.JumpPower  = 0 end)
								local NpcAnimator = AnimationModule.new(TargetHum)
								local EntangleIdleTrack = nil
								pcall(function()
									if HacklordInfo.SavedAnimations["ZombieIdle"] then
										EntangleIdleTrack = NpcAnimator:LoadAnimation(HacklordInfo.SavedAnimations["ZombieIdle"])
										EntangleIdleTrack.Priority = Enum.AnimationPriority.Action4
										EntangleIdleTrack:Play(0.3, 10)
									end
								end)
								local EntangleHighlight = NewInstance("Highlight", NpcChar, {
									Adornee = NpcChar,
									FillColor = Color3.fromRGB(0, 255, 80),
									OutlineColor = Color3.fromRGB(0, 200, 50),
									FillTransparency = 0.4,
									OutlineTransparency = 0
								})
								local ParticleList = {}
								for _, v in next, NpcChar:GetDescendants() do
									if v:IsA("BasePart") then
										pcall(function()
											local PE = NewInstance("ParticleEmitter", v, {
												Color = ColorSequence.new(Color3.fromRGB(0,255,80)),
												LightEmission = 0.5, LightInfluence = 0.5,
												Size = NumberSequence.new(0.15),
												Transparency = NumberSequence.new(0.3),
												Lifetime = NumberRange.new(0.4, 0.8),
												Rate = 15,
												Speed = NumberRange.new(0.5, 1.5),
												SpreadAngle = Vector2.new(180, 180),
												RotSpeed = NumberRange.new(-45, 45),
												Rotation = NumberRange.new(0, 360)
											})
											table.insert(ParticleList, PE)
										end)
									end
								end
								local EntangleEndTime = osclock() + 5
								local StayStillConn
								StayStillConn = Heartbeat:Connect(function()
									if osclock() >= EntangleEndTime then StayStillConn:Disconnect() return end
									pcall(function()
										if TargetHum and TargetHum.Parent then
											TargetHum.WalkSpeed  = 0
											TargetHum.JumpHeight = 0
										end
									end)
								end)
								FWait(5)
								pcall(function() StayStillConn:Disconnect() end)
								for _, PE in next, ParticleList do pcall(function() PE.Enabled = false end) end
								task.delay(1, function()
									for _, PE in next, ParticleList do pcall(function() PE:Destroy() end) end
								end)
								pcall(function()
									if EntangleHighlight and EntangleHighlight.Parent then
										TweenService:Create(EntangleHighlight, TweenInfo.new(0.5), {FillTransparency=1,OutlineTransparency=1}):Play()
										task.delay(0.5, function() pcall(function() EntangleHighlight:Destroy() end) end)
									end
								end)
								pcall(function() if EntangleIdleTrack then EntangleIdleTrack:Stop(0.5) end end)
								task.delay(0.6, function()
									pcall(function()
										if NpcAnimator and not NpcAnimator._destroyed then NpcAnimator:Destroy() end
									end)
								end)
								pcall(function() if EntangleTag and EntangleTag.Parent then EntangleTag:Destroy() end end)
								if TargetHum and TargetHum.Parent then
									local custHP = TargetHum:FindFirstChild("HacklordingIt_Health")
									local stillAlive = true
									if custHP and custHP.Value <= 0 then stillAlive = false
									elseif TargetHum.Health <= 0 then stillAlive = false end
									if stillAlive then
										pcall(function() TargetHum.WalkSpeed  = OriginalWalkSpeed  end)
										pcall(function() TargetHum.JumpHeight = OriginalJumpHeight end)
										pcall(function() TargetHum.JumpPower  = OriginalJumpPower  end)
									end
								end
								EntangledNPCs[TargetHum] = nil
							end)
						end
					end
				end
			end
		end)
		Swords.Parent = FolderStorage
		table.insert(CleanUp, Swords)
		local stop = osclock() + LifeTime
		while osclock() <= stop do
			deltaRadius += (deltatime * Speed)
			Core.CFrame = CF * CFrame.new(0, 0, -deltaRadius)
			Heartbeat:Wait()
		end
		StopFunc()
		EntanglementHitConn:Disconnect()
		Swords:Destroy()
	end
	debouchepriority = 2
	debouche = true
	BaseEntanglement:Play(1, 10, 1.2)
	NewSFX(HacklordInfo.Sounds.EntanglementThrow, CF, 2.5, 0.735)
	task.spawn(AttackFunc)
	BaseEntanglement.Ended:Wait()
	debouchepriority = 1
	debouche = false
end

local MassInfection = function()
	if StopEverything or debouche then return end
	local AttackFunc = function()
		FWait(1.65)
		local CF = RootPart.CFrame * CFrame.new(0, 0, -12)
		local deltaRadius = 0
		local Speed = HacklordInfo.MassInfectionShockwaveSpeed
		local LifeTime = HacklordInfo.MassInfectionShockwaveLifetime
		local ShockwaveDamage = HacklordInfo.MassInfectionShockwaveDamage
		local SlashDamage = HacklordInfo.MassInfectionSlashDamage
		local CloseUpSlashDamage = HacklordInfo.MassInfectionCloseSlashDamage
		NewSFX(HacklordInfo.Sounds.EntanglementThrow, CF, 2.5, 1)
		local Shockwave = HacklordInfo.ShockwaveTemplate:Clone()
		local Root = Shockwave.Root
		Root.Anchored = true
		Root.CFrame = CF
		Shockwave.Parent = FolderStorage
		table.insert(CleanUp, Shockwave)
		DamageFromHitbox(1, 0.035, RootPart, CFrame.new(0,0,-3.5), Vector3.new(10,5.5,10), SlashDamage)
		DamageFromHitbox(1, 0.035, RootPart, CFrame.new(0,0,-3),   Vector3.new(8,4,8),     CloseUpSlashDamage)
		local StopFunc = DamageFromHitbox(2500, 0.01, Root, nil, Root.Size + Vector3.new(0,0,10), ShockwaveDamage)
		local stop = osclock() + LifeTime
		while osclock() <= stop do
			deltaRadius += (deltatime * Speed)
			Root.CFrame = CF * CFrame.new(0, 0, -deltaRadius)
			Heartbeat:Wait()
		end
		StopFunc()
		Shockwave:Destroy()
	end
	debouchepriority = 2
	debouche = true
	HacklordInfo.SwordTrail.Enabled = true
	BaseMassInfection:Play(1, 10)
	NewSFX(HacklordInfo.Sounds.MassInfection, RootPart.CFrame, 10, 0.9)
	NewSFX(HacklordInfo.Sounds.Rejuvenate, RootPart.CFrame, 3.5, 1)
	task.spawn(AttackFunc)
	BaseMassInfection.Ended:Wait()
	HacklordInfo.SwordTrail.Enabled = false
	debouchepriority = 1
	debouche = false
end

local UnstableEye = function()
	if StopEverything or debouche then return end
	if UnstableEyeEffectActive then return end
	local AttackFunc = function()
		UnstableEyeEffectActive = true
		SpeedEffectEndTime = osclock() + 6
		SpeedStackLevel.Value = 1
		FWait(0.75)
		XRay.Enabled = true
		BlurEffect.Enabled = true
		TweenService:Create(XRay,TweenInfo.new(1),{FillTransparency=HacklordInfo.TargetHighlightProperties.FillTransparency,OutlineTransparency=HacklordInfo.TargetHighlightProperties.OutlineTransparency}):Play()
		TweenService:Create(BlurEffect,TweenInfo.new(1),{Size=30}):Play()
		FWait(6)
		TweenService:Create(XRay,TweenInfo.new(1),{FillTransparency=1,OutlineTransparency=1}):Play()
		TweenService:Create(BlurEffect,TweenInfo.new(1),{Size=0}):Play()
		FWait(1)
		XRay.Enabled = false
		BlurEffect.Enabled = false
		UnstableEyeEffectActive = false
	end
	debouchepriority = 2
	debouche = true
	BaseUnstableEye:Play(1, 10)
	NewSFX(HacklordInfo.Sounds.UnstableEye, RootPart.CFrame, 2.5, 1)
	task.spawn(AttackFunc)
	BaseUnstableEye.Ended:Wait()
	debouchepriority = 1
	debouche = false
end

local RejuvenateTheRotten = function()
	if StopEverything or debouche then return end
	local AttackFunc = function()
		FWait(2.2)
		local StartPos = RootPart.Position + Vector3.new(0, 500, 0)
		for i = 1, 5 do
			local SpawnOffset = Vector3.new(math.random(-65,65), 0, math.random(-65,65))
			local CastResult  = Workspace:Raycast(StartPos + SpawnOffset, -Vector3.new(0,600,0), RayParams)
			if CastResult then
				local ClonedZombie = Zombie.Zombie:Clone()
				for _, v in next, ClonedZombie:GetDescendants() do
					if v:IsA("BasePart") then
						v.Anchored = true
						v.Velocity = Vector3.zero
						v.RotVelocity = Vector3.zero
						v.AssemblyLinearVelocity  = Vector3.zero
						v.AssemblyAngularVelocity = Vector3.zero
					end
					if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then v:Destroy() end
				end
				for _, v in next, ClonedZombie:GetDescendants() do
					if v:IsA("Motor6D") then
						v.Enabled   = true
						v.Transform = CFrame.identity
					end
				end
				ClonedZombie:PivotTo(CFrame.new(CastResult.Position + Vector3.new(0,3,0)))
				ClonedZombie.Parent = AllyFolder
				table.insert(CleanUp, ClonedZombie)
				task.defer(function() ApplyAI(ClonedZombie) end)
			end
		end
	end
	debouchepriority = 2
	debouche = true
	HacklordInfo.SwordTrail.Enabled = true
	BaseRejuvenateTheRotten:Play(1, 10)
	NewSFX(HacklordInfo.Sounds.Rejuvenate, RootPart.CFrame, 4.5, 1)
	task.spawn(AttackFunc)
	BaseRejuvenateTheRotten.Ended:Wait()
	HacklordInfo.SwordTrail.Enabled = false
	debouchepriority = 1
	debouche = false
end

Device.Value = UserInputService.KeyboardEnabled and "PC" or "Mobile"

-- ============================================================
-- GUI PRINCIPAL
-- ============================================================
local ScreenGui = NewInstance("ScreenGui", LocalPlayer.PlayerGui, {Name = "HacklordGUI"})

-- Botões de habilidades (SEMPRE VISÍVEIS)
local MassInfectionButton        = NewInstance("ImageButton", ScreenGui, {Size=UDim2.fromOffset(65,65), Position=UDim2.new(1,-90,1,-160),  ImageColor3=Color3.new(1,1,1), Image="rbxassetid://112065267803856", BackgroundTransparency=1, Active=true})
local EntanglementButton         = NewInstance("ImageButton", ScreenGui, {Size=UDim2.fromOffset(65,65), Position=UDim2.new(1,-90,1,-230),  ImageColor3=Color3.new(1,1,1), Image="rbxassetid://119069138923680", BackgroundTransparency=1, Active=true})
local UnstableEyeButton          = NewInstance("ImageButton", ScreenGui, {Size=UDim2.fromOffset(65,65), Position=UDim2.new(1,-90,1,-300),  ImageColor3=Color3.new(1,1,1), Image="rbxassetid://135373963092918", BackgroundTransparency=1, Active=true})
local RejuvenateTheRottenButtton = NewInstance("ImageButton", ScreenGui, {Size=UDim2.fromOffset(65,65), Position=UDim2.new(1,-90,1,-370),  ImageColor3=Color3.new(1,1,1), Image="rbxassetid://102037518703784", BackgroundTransparency=1, Active=true})
local SlashButton                = NewInstance("ImageButton", ScreenGui, {Size=UDim2.fromOffset(65,65), Position=UDim2.new(1,-165,1,-85),  ImageColor3=Color3.new(1,1,1), Image="rbxassetid://120590195585579", BackgroundTransparency=1, Active=true})
local SprintingButton            = NewInstance("ImageButton", ScreenGui, {Size=UDim2.fromOffset(65,65), Position=UDim2.new(1,-235,1,-85),  ImageColor3=Color3.new(1,1,1), Image="rbxassetid://132640025048316", BackgroundTransparency=1, Active=true})
local ShiftlockButton            = NewInstance("ImageButton", ScreenGui, {Size=UDim2.fromOffset(65,65), Position=UDim2.new(1,-165,1,-160), ImageColor3=Color3.new(1,1,1), Image="rbxassetid://77581797168866",  BackgroundTransparency=1, Active=true})

-- ============================================================
-- BOTÃO TOGGLE SCAN REMOTES (canto superior esquerdo)
-- Só afeta dano em JOGADORES via remote
-- Visuais, animações, minions e habilidades SEMPRE funcionam
-- ============================================================
local ScanToggleFrame = NewInstance("Frame", ScreenGui, {
	Size = UDim2.fromOffset(175, 46),
	Position = UDim2.new(0, 10, 0, 10),
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0
})
NewInstance("UICorner", ScanToggleFrame, {CornerRadius = UDim.new(0, 12)})
NewInstance("UIStroke", ScanToggleFrame, {
	Color = Color3.fromRGB(60, 60, 60),
	Thickness = 1.5
})

local ScanToggleButton = NewInstance("TextButton", ScanToggleFrame, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "🔴  Scan Remotes: OFF",
	TextColor3 = Color3.fromRGB(255, 80, 80),
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextWrapped = true
})

local ScanStatusLabel = NewInstance("TextLabel", ScreenGui, {
	Size = UDim2.fromOffset(175, 18),
	Position = UDim2.new(0, 10, 0, 58),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(160, 160, 160),
	TextSize = 11,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true
})

-- Atualiza visual do botão
local function UpdateScanToggleVisual()
	if ScanRemotesActive then
		ScanToggleButton.Text = "🟢  Scan Remotes: ON"
		ScanToggleButton.TextColor3 = Color3.fromRGB(80, 255, 120)
		ScanToggleFrame.BackgroundColor3 = Color3.fromRGB(10, 35, 10)
		TweenService:Create(ScanToggleFrame, TweenInfo.new(0.3), {
			BackgroundColor3 = Color3.fromRGB(10, 35, 10)
		}):Play()
	else
		ScanToggleButton.Text = "🔴  Scan Remotes: OFF"
		ScanToggleButton.TextColor3 = Color3.fromRGB(255, 80, 80)
		TweenService:Create(ScanToggleFrame, TweenInfo.new(0.3), {
			BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		}):Play()
	end
end

-- Ativa o Scan Remotes
local function ActivateScanRemotes()
	-- Feedback visual de carregamento
	ScanToggleButton.Text = "⏳  Escaneando..."
	ScanToggleButton.TextColor3 = Color3.fromRGB(255, 220, 50)
	TweenService:Create(ScanToggleFrame, TweenInfo.new(0.3), {
		BackgroundColor3 = Color3.fromRGB(35, 30, 0)
	}):Play()
	ScanStatusLabel.Text = "🔍 Procurando remote..."

	task.spawn(function()
		TryScanRemotes()

		if FoundRemote then
			ScanRemotesActive = true
			ScanStatusLabel.Text = "✅  "..FoundRemote.Name
		else
			ScanRemotesActive = false
			ScanStatusLabel.Text = "❌  Sem remote neste jogo"
		end

		UpdateScanToggleVisual()
	end)
end

-- Desativa o Scan Remotes
local function DeactivateScanRemotes()
	ScanRemotesActive = false
	FoundRemote = nil
	ScanStatusLabel.Text = ""
	UpdateScanToggleVisual()
end

-- Clique no botão
ScanToggleButton.Activated:Connect(function()
	if ScanRemotesActive then
		DeactivateScanRemotes()
	else
		ActivateScanRemotes()
	end
end)

-- Labels dos botões de habilidade
NewInstance("TextLabel", SlashButton,                {Text="Slash",                 Size=UDim2.fromScale(1,0.5), Position=UDim2.fromScale(0,0.65), TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=20, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", SlashButton,                {Text="LMB",                   Size=UDim2.fromScale(1,0.25),Position=UDim2.fromScale(0,0),    TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=10, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", MassInfectionButton,        {Text="Mass Infection",        Size=UDim2.fromScale(1,0.5), Position=UDim2.fromScale(0,0.65), TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=14, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", MassInfectionButton,        {Text="Q",                     Size=UDim2.fromScale(1,0.25),Position=UDim2.fromScale(0,0),    TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=10, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", EntanglementButton,         {Text="Entanglement",          Size=UDim2.fromScale(1,0.5), Position=UDim2.fromScale(0,0.65), TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=16, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", EntanglementButton,         {Text="E",                     Size=UDim2.fromScale(1,0.25),Position=UDim2.fromScale(0,0),    TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=10, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", UnstableEyeButton,          {Text="Unstable Eye",          Size=UDim2.fromScale(1,0.5), Position=UDim2.fromScale(0,0.65), TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=15, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", UnstableEyeButton,          {Text="R",                     Size=UDim2.fromScale(1,0.25),Position=UDim2.fromScale(0,0),    TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=10, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", RejuvenateTheRottenButtton, {Text="Rejuvenate The Rotten", Size=UDim2.fromScale(1,0.5), Position=UDim2.fromScale(0,0.65), TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=10, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})
NewInstance("TextLabel", RejuvenateTheRottenButtton, {Text="T",                     Size=UDim2.fromScale(1,0.25),Position=UDim2.fromScale(0,0),    TextColor3=Color3.new(1,1,1), TextStrokeColor3=Color3.new(0,0,0), TextSize=10, FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold), BackgroundTransparency=1, TextStrokeTransparency=0})

HitmarkerUI = NewInstance("BillboardGui", nil, {AlwaysOnTop = true, Size = UDim2.new(2,15,0.5,15) - UDim2.fromScale(2,2)})
local Title = NewInstance("TextLabel", HitmarkerUI, {
	Name = "Title", Size = UDim2.fromScale(1,1), BackgroundTransparency = 1,
	FontFace = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold),
	RichText = true, TextColor3 = Color3.new(1,1,1), TextScaled = true
})
NewInstance("UIStroke", Title, {Color = Color3.new(0,0,0)})

-- Conexões dos botões
SprintingButton.Activated:Connect(Sprinting)
SlashButton.Activated:Connect(Slash)
MassInfectionButton.Activated:Connect(MassInfection)
EntanglementButton.Activated:Connect(Entanglement)
UnstableEyeButton.Activated:Connect(UnstableEye)
RejuvenateTheRottenButtton.Activated:Connect(RejuvenateTheRotten)
ShiftlockButton.Activated:Connect(Shiftlock)

local HideTouchUI = function(Bool)
	ScreenGui.Enabled = Bool
end

table.insert(CleanUp, UserInputService.WindowFocusReleased:Connect(function()
	PauseEverything = true
end))
table.insert(CleanUp, UserInputService.WindowFocused:Connect(function()
	PauseEverything = false
end))

table.insert(CleanUp, UserInputService.InputBegan:Connect(function(Input, gp)
	if gp then return end
	local KeyCode, UserInputType = Input.KeyCode, Input.UserInputType
	if UserInputType == Enum.UserInputType.Keyboard then
		HideTouchUI(false)
		if KeyCode == Enum.KeyCode.LeftShift then
			Shiftlock()
		elseif KeyCode == Enum.KeyCode.RightShift then
			Sprinting()
		elseif KeyCode == Enum.KeyCode.F then
			Slash()
		elseif KeyCode == Enum.KeyCode.Q then
			MassInfection()
		elseif KeyCode == Enum.KeyCode.E then
			Entanglement()
		elseif KeyCode == Enum.KeyCode.R then
			UnstableEye()
		elseif KeyCode == Enum.KeyCode.T then
			RejuvenateTheRotten()
		elseif KeyCode == Enum.KeyCode.U then
			PlayIntroduction()
		elseif KeyCode == Enum.KeyCode.P then
			ForceTriggerLMS = not ForceTriggerLMS
			TriggerLMS(ForceTriggerLMS)
		elseif KeyCode == Enum.KeyCode.G then
			-- Tecla G: toggle Scan Remotes pelo teclado
			if ScanRemotesActive then
				DeactivateScanRemotes()
			else
				ActivateScanRemotes()
			end
		end
	elseif UserInputType == Enum.UserInputType.Touch then
		HideTouchUI(true)
	end
end))

BaseIdle:Play(1, 10)

local Movements = function(Magnitude)
	if Magnitude == 0 then
		State.Value = "Idle"
	else
		if debouchepriority >= 2 then
			State.Value = "Idle"
		else
			if IsSprinting then
				State.Value = "Sprint"
				BaseRun.Speed = RunMagnitude
			else
				State.Value = "Walk"
				BaseWalk.Speed = WalkMagnitude
			end
		end
	end
end

local CreateFakeRoot = function(part)
	if not part then return end
	local FakeRoot = NewInstance("Part", Highlights, {
		Size = part.Size / 1.05, CFrame = part.CFrame,
		CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false
	})
	NewInstance("WeldConstraint", FakeRoot, {Part0 = FakeRoot, Part1 = part})
	part.Destroying:Once(function() FakeRoot:Destroy() end)
	return FakeRoot
end

local OnCharacter = function(v)
	local ThisPlayer = v
	local Clear = function(Character, RootPart, Cons)
		local getreal = table.find(RootParts, RootPart)
		if getreal then
			table.remove(RootParts, getreal)
			for _, v in next, Cons do if v then v:Disconnect() end end
			if Highlights:FindFirstChild(ThisPlayer.Name) then
				Highlights[ThisPlayer.Name]:Destroy()
			end
		end
	end
	if ThisPlayer and ThisPlayer ~= LocalPlayer then
		local Character = ThisPlayer.Character
		if Character then
			local RootPart = ReturnRoot(Character)
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			CreateFakeRoot(RootPart).Name = ThisPlayer.Name
			table.insert(RootParts, RootPart)
			local LeaveConnect, DiedConnect
			if Humanoid then
				DiedConnect = Humanoid.Died:Connect(function()
					Clear(Character, RootPart, {LeaveConnect, DiedConnect})
				end)
			end
			LeaveConnect = Players.PlayerRemoving:Connect(function(plr)
				if plr == ThisPlayer then Clear(Character, RootPart, {LeaveConnect, DiedConnect}) end
			end)
			table.insert(CleanUp, DiedConnect)
			table.insert(CleanUp, LeaveConnect)
		end
		table.insert(CleanUp, ThisPlayer:GetPropertyChangedSignal("Character"):Connect(function()
			local c = ThisPlayer.Character
			if c then
				PreRender:Wait()
				local RootPart = ReturnRoot(c) or c:WaitForChild("HumanoidRootPart")
				if RootPart then
					table.insert(RootParts, RootPart)
					CreateFakeRoot(RootPart).Name = ThisPlayer.Name
					local LeaveConnect, DiedConnect
					local Humanoid = c:FindFirstChildOfClass("Humanoid")
					if Humanoid then
						DiedConnect = Humanoid.Died:Connect(function()
							Clear(Character, RootPart, {LeaveConnect, DiedConnect})
						end)
						table.insert(CleanUp, DiedConnect)
					end
					LeaveConnect = Players.PlayerRemoving:Connect(function(plr)
						if plr == ThisPlayer then Clear(Character, RootPart, {LeaveConnect, DiedConnect}) end
					end)
					table.insert(CleanUp, LeaveConnect)
				end
			end
		end))
	end
end

local PlayerCount = New("IntValue", Character)

table.insert(CleanUp, PlayerCount:GetPropertyChangedSignal("Value"):Connect(function()
	local PlayerCount = PlayerCount.Value
	if PlayerCount == 1 then
		TriggerLMS(true)
		if not LMS.Playing then
			repeat LMS.Playing = true PreRender:Wait() until LMS.Playing == true
			LMS.SoundId = HacklordInfo.Themes.LMS
			LMS.Volume = 0
			LMS.TimePosition = 0
			LMS.Playing = true
		end
	else
		TriggerLMS(false)
	end
end))

for _, v in next, Players:GetPlayers() do
	if v ~= LocalPlayer then
		table.insert(PlayerTable, v)
		OnCharacter(v)
		PlayerCount.Value += 1
	end
end
table.insert(CleanUp, Players.PlayerAdded:Connect(function(v)
	table.insert(PlayerTable, v)
	OnCharacter(v)
	PlayerCount.Value += 1
end))
table.insert(CleanUp, Players.PlayerRemoving:Connect(function(v)
	if table.find(PlayerTable, v) then
		table.remove(PlayerTable, table.find(PlayerTable, v))
		PlayerCount.Value -= 1
	end
end))

table.insert(CleanUp, State:GetPropertyChangedSignal("Value"):Connect(function()
	local State = State.Value
	if State == "Idle" then
		if not BaseIdle.IsPlaying then
			BaseIdle:Play(1,10) BaseWalk:Stop(1) BaseRun:Stop(1)
		end
	elseif State == "Walk" then
		if not BaseWalk.IsPlaying then
			BaseWalk:Play(1,10) BaseIdle:Stop(1) BaseRun:Stop(1)
		end
	elseif State == "Sprint" then
		if not BaseRun.IsPlaying then
			BaseRun:Play(1,10) BaseIdle:Stop(1) BaseWalk:Stop(1)
		end
	end
end))

table.insert(CleanUp, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local CurrentCamera = Workspace.CurrentCamera
	if CurrentCamera then Camera = CurrentCamera end
end))

table.insert(CleanUp, Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
	local Health = Humanoid.Health
	if Health == 0 then
		for _, v in next, CleanUp do
			if v then
				if typeof(v) == "Instance" then v:Destroy() else v:Disconnect() end
			end
		end
		for _, v in next, Animators do v:Destroy() end
		StopEverything = true
	end
end))

table.insert(CleanUp, SpeedStackLevel:GetPropertyChangedSignal("Value"):Connect(function()
	SpeedMultiply = 1 + 0.25 * SpeedStackLevel.Value
end))

table.insert(CleanUp, Layer:GetPropertyChangedSignal("Value"):Connect(function()
	local Layer = Layer.Value
	if Layer == 1 then
		if TerrorTheme.SoundId ~= HacklordInfo.Themes.Layer1 then
			TerrorTheme.SoundId = HacklordInfo.Themes.Layer1
			TerrorTheme.Volume = 3.5
			TerrorTheme.TimePosition = 0.7
			TerrorTheme.Playing = true
		end
	elseif Layer == 2 then
		if TerrorTheme.SoundId ~= HacklordInfo.Themes.Layer2 then
			TerrorTheme.SoundId = HacklordInfo.Themes.Layer2
			TerrorTheme.Volume = 3.5
			TerrorTheme.TimePosition = 0
			TerrorTheme.Playing = true
		end
	elseif Layer == 3 then
		if TerrorTheme.SoundId ~= HacklordInfo.Themes.Layer3 then
			TerrorTheme.SoundId = HacklordInfo.Themes.Layer3
			TerrorTheme.Volume = 3.5
			TerrorTheme.TimePosition = 0
			TerrorTheme.Playing = true
		end
	elseif Layer == 4 then
		if TerrorTheme.SoundId ~= HacklordInfo.Themes.Layer4 then
			TerrorTheme.SoundId = HacklordInfo.Themes.Layer4
			TerrorTheme.Volume = 3.5
			TerrorTheme.TimePosition = 0
			TerrorTheme.Playing = true
		end
	end
end))

table.insert(CleanUp, Heartbeat:Connect(function()
	if PauseEverything then return end
	last = current
	current = osclock()
	deltatime = current - last
	local MoveDirection = Humanoid.MoveDirection
	DirectionMagnitude = MoveDirection.Magnitude
	local Dist = (Head.CFrame.Position - Camera.CFrame.Position).Magnitude
	local Diff = Head.CFrame.Y - Camera.CFrame.Y
	if not debouche then
		Humanoid.WalkSpeed = CurrentSpeed
	else
		if debouchepriority == 2 then
			Humanoid.WalkSpeed = 1
		elseif debouchepriority >= 3 then
			Humanoid.WalkSpeed = 0
		end
	end
	if HeadLook == true then
		Neck.C1 = Lerp(Neck.C1,
			CFrame.new(0,-0.5,0,-1,0,0,0,0,1,0,1,-0)
			* CFrame.fromEulerAngles(
				(math.asin(Diff/Dist)*0.7),
				0,
				((Head.CFrame.Position-Camera.CFrame.Position).Unit):Cross(Torso.CFrame.LookVector).Y*0.8
			), 0.05)
	else
		Neck.C1 = Lerp(Neck.C1, CFrame.new(0,-0.5,0,-1,0,0,0,0,1,0,1,-0), 0.05)
	end
	Movements(DirectionMagnitude)
end))

table.insert(CleanUp, PreRender:Connect(function()
	if PauseEverything then return end
	local LastDistance, Distance = 125, 125
	for _, v in next, RootParts do
		if typeof(v) == "Instance" and v:IsDescendantOf(Workspace) then
			local RootDistance = LocalPlayer:DistanceFromCharacter(v.Position)
			LastDistance = Distance
			if LastDistance > RootDistance then Distance = RootDistance end
		end
	end
	WalkMagnitude = (RootPart.Velocity * Vector3.new(1,0,1)).Magnitude / HacklordInfo.Speed
	RunMagnitude  = (RootPart.Velocity * Vector3.new(1,0,1)).Magnitude / HacklordInfo.SprintSpeed
	if osclock() > SpeedEffectEndTime then SpeedStackLevel.Value = 0 end
	if IsSprinting then
		CurrentSpeed = HacklordInfo.SprintSpeed * SpeedMultiply
	else
		CurrentSpeed = HacklordInfo.Speed * SpeedMultiply
	end
	if Distance < TerrorRange * 0.3 then
		Layer.Value = 4
	elseif Distance < TerrorRange * 0.6 then
		Layer.Value = 3
	elseif Distance < TerrorRange * 0.8 then
		Layer.Value = 2
	elseif Distance <= TerrorRange then
		Layer.Value = 1
	elseif Distance > TerrorRange then
		Layer.Value = 0
	end
	if ShiftlockOn == true then
		if not RootPart.Anchored and Camera then
			if LocalPlayer:DistanceFromCharacter(Camera.CFrame.Position) > 1 then
				Humanoid.AutoRotate = false
				RootPart.CFrame = Lerp(RootPart.CFrame,
					CFrame.new(RootPart.Position,
						Vector3.new(
							Camera.CFrame.LookVector.X*900000,
							RootPart.Position.Y,
							Camera.CFrame.LookVector.Z*900000
						)
					), 0.25)
				Camera.CFrame = Camera.CFrame * CFrame.new(1.7, 0, 0)
				Camera.Focus = CFrame.fromMatrix(
					Camera.Focus.Position,
					Camera.CFrame.RightVector,
					Camera.CFrame.UpVector
				) * CFrame.new(1.7, 0, 0)
			else
				Humanoid.AutoRotate = true
			end
		else
			Humanoid.AutoRotate = true
		end
	else
		Humanoid.AutoRotate = true
	end
	if LMSActive or Layer.Value == 0 then
		TerrorTheme.Volume = NLerp(TerrorTheme.Volume, 0, 0.05)
	end
	if Humanoid.FloorMaterial.Name ~= "Air" and State.Value ~= "Idle" then
		if IsSprinting then
			if IsRightTime(1.5 - math.min(RunMagnitude, 1)) then
				NewSFX(HacklordInfo.Sounds.Footsteps[math.random(1,2)], RootPart.CFrame, 1.25)
			end
		else
			if IsRightTime(2.15 - math.min(WalkMagnitude, 1)) then
				NewSFX(HacklordInfo.Sounds.Footsteps[math.random(1,2)], RootPart.CFrame, 0.86)
			end
		end
	end
end))