--[[

	Canteen
	(c) 2011 by Siarkowy

]]

Canteen = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceDB-2.0", "FuBarPlugin-2.0")

local Canteen = Canteen
local tablet = AceLibrary("Tablet-2.0")
local colors = RAID_CLASS_COLORS

local format = format
local pairs, ipairs, sort = pairs, ipairs, sort
local tinsert, tremove = tinsert, tremove
local table_concat, tContains = table.concat, tContains
local GetNumRaidMembers = GetNumRaidMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetRealZoneText = GetRealZoneText
local GetSpellInfo = GetSpellInfo
local UnitBuff = UnitBuff
local UnitIsConnected = UnitIsConnected
local UnitInRaid = UnitInRaid

Canteen.clickableTooltip		= false
Canteen.defaultMinimapPosition	= 160
Canteen.hasIcon					= [[Interface\Icons\Spell_Misc_Food]]
Canteen.hasNoColor				= true

do
	local function sinfo(id)
		return select(1, GetSpellInfo(id)) or "?"
	end

	Canteen.general = {
		sinfo(1459),	-- Arcane Intellect
		sinfo(23028),	-- Arcane Brilliance
		sinfo(1243),	-- Power Word: Fortitude
		sinfo(21562),	-- Prayer of Fortitude
		sinfo(1126),	-- Mark of the Wild
		sinfo(21849),	-- Gift of the Wild
		sinfo(976),		-- Shadow Protection
		sinfo(27683),	-- Prayer of Shadow Protection
		sinfo(14752),	-- Divine Spirit
		sinfo(27681),	-- Prayer of Spirit
		sinfo(33946),	-- Amplify Magic
	}

	Canteen.paladin = {
		sinfo(20217),	-- Blessing of Kings
		sinfo(25898),	-- Greater Blessing of Kings
		sinfo(19977),	-- Blessing of Light
		sinfo(25890),	-- Greater Blessing of Light
		sinfo(19740),	-- Blessing of Might
		sinfo(25782),	-- Greater Blessing of Might
		sinfo(1038),	-- Blessing of Salvation
		sinfo(25895),	-- Greater Blessing of Salvation
		sinfo(19742),	-- Blessing of Wisdom
		sinfo(25894),	-- Greater Blessing of Wisdom
		sinfo(27168),	-- Blessing of Sanctuary
		sinfo(27169),	-- Greater Blessing of Sanctuary
	}

	Canteen.consumables = {
		-- elixirs --
		sinfo(11348),	-- Greater Armor
		sinfo(11390),	-- Arcane Elixir
		sinfo(11396),	-- Greater Intellect
		sinfo(11406),	-- Elixir of Demonslaying
		sinfo(17538),	-- Elixir of the Mongoose
		sinfo(17539),	-- Greater Arcane Elixir
		sinfo(24363),	-- Mana Regeneration
		sinfo(28490),	-- Major Strength
		sinfo(28491),	-- Healing Power
		sinfo(28493),	-- Major Frost Power
		sinfo(28497),	-- Major Agility
		sinfo(28501),	-- Major Firepower
		sinfo(28502),	-- Major Armor
		sinfo(28503),	-- Major Shadow Power
		sinfo(28509),	-- Greater Mana Regeneration
		sinfo(28514),	-- Empowerment
		sinfo(29626),	-- Earthen Elixir
		sinfo(38954),	-- Fel Strength Elixir
		sinfo(39625),	-- Elixir of Major Fortitude
		sinfo(33720),	-- Onslaught Elixir
		sinfo(33721),	-- Adept's Elixir
		sinfo(33726),	-- Elixir of Mastery
		sinfo(39627),	-- Elixir of Draenic Wisdom
		sinfo(39628),	-- Elixir of Ironskin
		sinfo(45373),	-- Bloodberry
		-- flasks --
		sinfo(17626),	-- Flask of the Titans
		sinfo(17627),	-- Flask of Distilled Wisdom
		sinfo(17628),	-- Flask of Supreme Power
		sinfo(17629),	-- Flask of Chromatic Resistance
		sinfo(28518),	-- Flask of Fortification
		sinfo(28519),	-- Flask of Mighty Restoration
		sinfo(28520),	-- Flask of Relentless Assault
		sinfo(28521),	-- Flask of Blinding Light
		sinfo(28540),	-- Flask of Pure Death
		sinfo(33053),	-- Mr. Pinchy's Blessing
		sinfo(42735),	-- Flask of Chromatic Wonder
		sinfo(40567),	-- Unstable Flask of the Bandit
		sinfo(40568),	-- Unstable Flask of the Elder
		sinfo(40572),	-- Unstable Flask of the Beast
		sinfo(40573),	-- Unstable Flask of the Physician
		sinfo(40575),	-- Unstable Flask of the Soldier
		sinfo(40576),	-- Unstable Flask of the Sorcerer
		sinfo(41608),	-- Relentless Assault of Shattrath
		sinfo(41609),	-- Fortification of Shattrath
		sinfo(41610),	-- Mighty Restoration of Shattrath
		sinfo(41611),	-- Sureme Power of Shattrath
		sinfo(46837),	-- Pure Death of Shattrath
		sinfo(46839),	-- Blinding Light of Shattrath
		-- other --
		sinfo(35272),	-- Well Fed
		sinfo(44106),	-- Brewfest Well Fed
		sinfo(43730),	-- Electrified
		sinfo(43722),	-- Enlightened
		-- scrolls --
		sinfo(33077),	-- Agility
		sinfo(33078),	-- Intellect
		sinfo(33079),	-- Armor
		sinfo(33080),	-- Spirit
		sinfo(33081),	-- Stamina
		sinfo(33082),	-- Strength
		-- food --
		sinfo(33262),	-- Food
		sinfo(44166),	-- Refreshment
		sinfo(25804),	-- Rumsey Rum Black Label
	}

	Canteen.special = {
		(select(3, GetSpellInfo(34477))),	-- Misdirection
		(select(3, GetSpellInfo(27239))),	-- Soulstone Resurrection
	}
end

local esq = "|T%s:16|t"

local function wipe(t) for k, v in pairs(t) do t[k] = nil end end

function Canteen.GetPlayerColor(unit)
	local r, g, b = .5, .5, .5
	if UnitIsConnected(unit) then
		local color = colors[select(2, UnitClass(unit)) or "PRIEST"]
		r, g, b = color.r, color.g, color.b
	end
	return r, g, b
end

function Canteen.IsInGroup()
	return UnitInRaid("player") or GetNumPartyMembers() > 0
end

local general, paladin, consumables = {}, {}, {}
local ids = { {}, {}, {}, {}, {}, {}, {}, {} }

function Canteen:GetGroupedBuffs(unit)
	wipe(general)
	wipe(paladin)
	wipe(consumables)

	local n = 0
	local special

	while true do
		n = n + 1
		local buff, _, icon = UnitBuff(unit, n)
		if not buff then
			break
		elseif not special and tContains(self.special, icon) then
			special = icon
		elseif tContains(self.general, buff) then
			tinsert(general, format(esq, icon))
		elseif tContains(self.paladin, buff) then
			tinsert(paladin, format(esq, icon))
		elseif tContains(self.consumables, buff) then
			tinsert(consumables, format(esq, icon))
		end
	end

	sort(general)
	sort(paladin)
	sort(consumables)

	return general, paladin, consumables, special
end

function Canteen:OnInitialize()
	self:RegisterDB("CanteenDB")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "Update")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "Update")
	self:ScheduleRepeatingEvent(function() self:Update() end, 1)
end

function Canteen:OnTooltipUpdate()
	if not self.IsInGroup() then
		tablet:SetHint("You need to be in a group.")
		return
	end

	if not GetRaidRosterInfo(1) and not UnitName("party1") then
		return -- no data yet, possible briefly after group update events
	end

	local inRaid = UnitInRaid("player")

	local cat = tablet:AddCategory(
		'text',		'Player',
		'text2',	'General',
		'text3',	'Paladin',
		'text4',	'Other',
		'text5',	'Zone',
		'columns',	inRaid and self.db.profile.zone and 5 or 4
	)

	if inRaid then
		self:OnRaidTooltipUpdate(cat)
	else
		self:OnPartyTooltipUpdate(cat)
	end

	tablet:SetHint("Buff list updates every second.")
end

local party = { "player", "party1", "party2", "party3", "party4" }

function Canteen:OnPartyTooltipUpdate(cat)
	if self.db.profile.gap then
		cat:AddLine()
	end

	for _, unit in pairs(party) do
		if UnitName(unit) then
			local general, paladin, consumables, special = self:GetGroupedBuffs(unit)
			local r, g, b = self.GetPlayerColor(unit)

			cat:AddLine(
				'text',			format("|cff%.2x%.2x%.2x%s|r", r * 255, g * 255, b * 255, UnitName(unit)),
				'text2',		table_concat(general, ""),
				'text3',		table_concat(paladin, ""),
				'text4',		table_concat(consumables, ""),
				'hasCheck',		true,
				'checked',		special and true or nil,
				'checkIcon',	special or nil
			)
		end
	end
end

function Canteen:OnRaidTooltipUpdate(cat)
	for i = 1, GetNumRaidMembers() do
		tinsert(ids[ select(3, GetRaidRosterInfo(i)) or 0 ], i)
	end

	local myzone = GetRealZoneText()

	for grp = 1, self.db.profile.hide68 and 5 or 8 do
		for k, i in ipairs(ids[grp]) do
			local unit = "raid" .. i
			local name, _, _, _, _, class, zone = GetRaidRosterInfo(i)
			local general, paladin, consumables, special = self:GetGroupedBuffs(unit)
			local r, g, b = self.GetPlayerColor(unit)

			if k == 1 then -- first player in group
				if self.db.profile.gap then -- gaps between groups
					cat:AddLine()
				end
				if self.db.profile.header then -- party header
					cat:AddLine('text', format("|cffccccccGroup %d|r", grp))
				end
			end

			cat:AddLine(
				'text',			format("|cff%.2x%.2x%.2x%s|r", r * 255, g * 255, b * 255, name),
				'text2',		table_concat(general, ""),
				'text3',		table_concat(paladin, ""),
				'text4',		table_concat(consumables, ""),
				'text5',		connected and format("|cff%s%s|r", (myzone == zone) and "7f7f7f" or "ff8800", zone or UNKNOWN) or format("|cff7f7f7f%s|r", zone or UNKNOWN),
				'hasCheck',		true,
				'checked',		special and true or nil,
				'checkIcon',	special or nil
			)
		end
	end

	for grp = 1, 8 do
		wipe(ids[grp])
	end
end

Canteen.OnMenuRequest = {
	type = "group",
	args = {
		gap = {
			name = "Group gaps",
			desc = "Toggle gaps separating subsequent raid groups.",
			type = "toggle",
			get = function() return Canteen.db.profile.gap end,
			set = function(v) Canteen.db.profile.gap = v; Canteen:Update() end,
			order = 1,
		},
		headers = {
			name = "Group headers",
			desc = "Toggle headers above each raid subgroup.",
			type = "toggle",
			get = function() return Canteen.db.profile.header end,
			set = function(v) Canteen.db.profile.header = v; Canteen:Update() end,
			order = 2,
		},
		zone = {
			name = "Raid zone info",
			desc = "Display zone information while in raid.",
			type = "toggle",
			get = function() return Canteen.db.profile.zone end,
			set = function(v) Canteen.db.profile.zone = v; Canteen:Update() end,
			order = 3,
		},
		hide68 = {
			name = "Hide groups 6-8",
			desc = "Toggle hiding of groups 6-8.",
			type = "toggle",
			get = function() return Canteen.db.profile.hide68 end,
			set = function(v) Canteen.db.profile.hide68 = v; Canteen:Update() end,
			order = 4
		},
	}
}
