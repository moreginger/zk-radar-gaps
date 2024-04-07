function widget:GetInfo()
	return {
		name        = 'Radar Gaps',
		desc        = 'Highlight areas within radar range where units disappear',
		author      = 'moreginger',
		date        = '2024-04-03',
		license     = 'GNU LGPL, v2.1 or later',
		layer       = 1001, -- more than Chili
		-- alwaysStart = true,
		enabled     = true
	}
end

local GL_POINTS = GL.POINTS

local luaWidgetsDir = 'LuaUI/Widgets/'
local LuaShader = VFS.Include(luaWidgetsDir .. "Include/LuaShader.lua")
VFS.Include(luaWidgetsDir .. 'Include/instancevbotable.lua')

local shader, VBO

local updatePositionFrames = 30
local forgetUnitFrames = 30 * 30;

local function lengthSq(x, y, z)
	return x * x + y * y + (z and z * z or 0)
end

local function RemoveElement(table, index)
	local length = #table
	table[index] = table[length]
	table[length] = nil
end

-- unitID: { x, y, z, radius^2 }
local allyRadars = {}
-- unitID: { frameLastPolled, x, y, z, vx, vy, vz }
local enemyUnits = {}
-- index: { frame, unitID, x, y, z }
local blackspots = {}

local function AddRadar(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if not unitDefID or not Spring.IsUnitAllied(unitID) then
		return
	end

	-- FIXME: Only working for comms?
	-- ud.radarDistance?
	local radarDistance = (Spring.GetUnitRulesParam(unitID, 'radarRangeOverride') or 0)

	if radarDistance == 0 then
		return
	end
	
	radarDistance = radarDistance * 0.95 -- 5% margin
	local x, y, z = Spring.GetUnitPosition(unitID)

	-- FIXME: mobile radars
	allyRadars[unitID] = { x, y, z, radarDistance * radarDistance }
end

local function UpdateUnit(unitID, frame, data)
	local x, y, z = Spring.GetUnitPosition(unitID)
	local vx, vy, vz = Spring.GetUnitVelocity(unitID)
	
	if x and y and z then
		data = data or {}
		data[1] = frame
		data[2], data[3], data[4]  = x, y, z
		data[5], data[6], data[7]  = vx or 0, vy or 0, vz or 0
	end

	return data
end

local function TrackUnit(unitID)
	if Spring.IsUnitAllied(unitID) then
		return
	end

	local data = UpdateUnit(unitID, Spring.GetGameFrame(), nil)
	enemyUnits[unitID] = data
end

local function UpdatePositions(frame)
	for unitID, data in pairs(enemyUnits) do
		if frame - data[1] >= updatePositionFrames then
			UpdateUnit(unitID, frame, data)
			if frame - data[1] >= forgetUnitFrames then
				enemyUnits[unitID] = nil
			end
		end
	end
end

local function InRadarRange(x, y, z)
	for _, radar in pairs(allyRadars) do
		-- FIXME: Cylindrical not spherical
		local dx, dy, dz = radar[1] - x, radar[2] - y, radar[3] - z
		if lengthSq(dx, dy, dz) < radar[4] then
			return true
		end
	end
	return false
end

----------------------------------------------------------------
--callins
----------------------------------------------------------------

function widget:DrawWorld()
	-- for _, blackspot in pairs(blackspots) do
	-- 	local _, _, x, y, z = unpack(blackspot)
	-- 	gl.DrawGroundCircle(x, y, z, 50, 16)
	-- end

	gl.DepthTest(false)
	shader:Activate()
	VBO.VAO:DrawArrays(GL_POINTS, VBO.usedElements)
	shader:Deactivate()
	gl.DepthTest(true)
end

function widget:GameFrame(frame)
	UpdatePositions(frame)
end

local function InitGl()
	local wname = widget:GetInfo().name
	-- Shader
	local glname = 'radarGapsVBO'
	local shaderSourceCache = {
		vssrcpath = luaWidgetsDir .. 'Shaders/radar_gaps.vert.glsl',
		gssrcpath = luaWidgetsDir .. 'Shaders/radar_gaps.geom.glsl',
		fssrcpath = luaWidgetsDir .. 'Shaders/radar_gaps.frag.glsl',
		shaderConfig = {},
		shaderName = glname,
		uniformFloat = {},
		uniformInt = {},
	}
	shader = LuaShader.CheckShaderUpdates(shaderSourceCache)

	if not shader then
		Spring.Echo('Failed to create shader ' .. glname .. ' in ' .. wname)
		return false
	end

	-- VBO
	VBO = makeInstanceVBOTable(
		{
			{ id = 0, name = 'pos', size = 4, },
			{ id = 1, name = 'frame', size = 1, type = GL.UNSIGNED_INT, },
		},
		64,
		glname
	)
	if VBO == nil then
		Spring.Echo('Failed to create VBO ' .. glname .. ' in ' .. wname)
		return false
	end
	local VAO = gl.GetVAO()
	VAO:AttachVertexBuffer(VBO.instanceVBO)
	VBO.VAO = VAO

	return true
end

function widget:Initialize()
	if not InitGl() then
		return false
	end

	-- Bootstrap all units
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		AddRadar(unitID)
		TrackUnit(unitID)
	end
end

function widget:Shutdown()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	AddRadar(unitID)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	allyRadars[unitID] = nil
	enemyUnits[unitID] = nil
	for index, value in ipairs(blackspots) do
		if value[2] == unitID then
			blackspots[index] = nil
		end
	end
end

function widget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
	TrackUnit(unitID)
end

function widget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
	local data = enemyUnits[unitID]
	if not data then
		return
	end

	local frame = Spring.GetGameFrame()
	local frameLastPolled, x, y, z, vx, vy, vz = unpack(data)
	local secondsSinceLastPolled = (frame - frameLastPolled) / 30
	x, y, z = x + vx * secondsSinceLastPolled, y + vy * secondsSinceLastPolled, z + vz * secondsSinceLastPolled

	if not InRadarRange(x, y, z) then
		return
	end

	local key = #blackspots + 1
	blackspots[key] = {
		frame,
		unitID,
		x + vx * secondsSinceLastPolled,
		y + vy * secondsSinceLastPolled,
		z + vz * secondsSinceLastPolled
	}

	-- FIXME: Key (when removing)
	Spring.Echo('Blackspot at ' .. x .. ', ' .. y .. ', ' .. z)
	pushElementInstance(
		VBO,
		{
			x, y, z, 1.0, -- pos
			frame -- frame
		},
		key
	)
	-- TODO: Add to table to tidy vbos
end
