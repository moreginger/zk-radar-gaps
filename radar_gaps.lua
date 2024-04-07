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

-- Config
local UPDATE_ALLY_RADAR_POSITION_FRAMES = 10
local UPDATE_ENEMY_UNIT_POSITION_FRAMES = 30
local SHOW_RADAR_MARK_FRAMES = 30 * 20;

local shader, VBO

local function lengthSq(x, y, z)
	return x * x + y * y + (z and z * z or 0)
end

-- unitID: { frameLastPolled, radius^2, x, y, z }
local allyRadars = {}
-- unitID: { frameLastPolled, x, y, z, vx, vy, vz }
local enemyUnits = {}
-- index: deleteOnFrame
local marks = {}
local markIndex = 1

local function UpdateAllyRadar(unitID, frame, data)
	data[1] = frame
	local x, y, z = Spring.GetUnitPosition(unitID)
	if not x or not y or not z then
		return false
	end

	data[3], data[4], data[5] = x, y, z
	return true
end

local function AddAllyRadar(unitID)
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

	local radarDistanceSq = radarDistance * radarDistance * 0.95 -- 5% margin
	local data = { 0, radarDistanceSq, 0, 0, 0 }
	if UpdateAllyRadar(unitID, Spring.GetGameFrame(), data) then
		allyRadars[unitID] = data
	end
end

-- return true if the position was updated
local function UpdateUnit(unitID, frame, data)
	data[1] = frame
	
	local x, y, z = Spring.GetUnitPosition(unitID)
	if not x or not y or not z then
		return false
	end

	data[2], data[3], data[4]  = x, y, z
	local vx, vy, vz = Spring.GetUnitVelocity(unitID)
	data[5], data[6], data[7]  = vx or 0, vy or 0, vz or 0

	return true
end

local function TrackEnemyUnit(unitID)
	if Spring.IsUnitAllied(unitID) then
		return
	end

	local data = {}
	if UpdateUnit(unitID, Spring.GetGameFrame(), data) then
		enemyUnits[unitID] = data
	end
end

local function UpdatePositions(frame)
	-- for unitID, data in pairs(allyRadars) do
	-- 	if frame - data[1] >= UPDATE_ALLY_RADAR_POSITION_FRAMES then
	-- 		UpdateAllyRadar(unitID, frame, data)
	-- 	end
	-- end
	for unitID, data in pairs(enemyUnits) do
		if frame - data[1] >= UPDATE_ENEMY_UNIT_POSITION_FRAMES then
			UpdateUnit(unitID, frame, data)
		end
	end
end

local function InRadarRange(x, y, z)
	for _, radar in pairs(allyRadars) do
		local lengthSq = lengthSq(radar[3] - x, radar[4] - y)
		Spring.Echo('InRadarRange', lengthSq, radar[2])
		if lengthSq < radar[2] then
			Spring.Echo('in range')
			return true
		end
	end
	return false
end

----------------------------------------------------------------
--callins
----------------------------------------------------------------

function widget:DrawWorld()
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
		AddAllyRadar(unitID)
		TrackEnemyUnit(unitID)
	end
end

function widget:Shutdown()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	AddAllyRadar(unitID)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	allyRadars[unitID] = nil
	enemyUnits[unitID] = nil
end

function widget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
	TrackEnemyUnit(unitID)
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

	Spring.Echo('Disappeared at ' .. x .. ', ' .. y .. ', ' .. z)
	local key = markIndex
	markIndex = markIndex + 1
	marks[key] = frame + SHOW_RADAR_MARK_FRAMES
	pushElementInstance(
		VBO,
		{
			x, y, z, 1.0, -- pos
			frame -- frame
		},
		key
	)
end
