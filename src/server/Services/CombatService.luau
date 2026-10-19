--!strict
-- Player-chosen targets and automatic attacks from equipped characters.
-- Clicking an enemy selects it; equipped characters hit it on their cooldowns
-- while the player stays in range. Everyone who hit an enemy gets its yen.
-- The current target id is replicated as the player attribute "TargetEnemyId".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Formulas)

local Server = script.Parent.Parent
local AttackClock = require(Server.Combat.AttackClock)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

type State = {
	target: EnemyService.Enemy?,
	clock: AttackClock.Clock,
}

local states: { [Player]: State } = {}

local CombatService = {}

local function getState(player: Player): State
	local state = states[player]
	if state == nil then
		state = { target = nil, clock = AttackClock.new() }
		states[player] = state
	end
	return state
end

local function setTarget(player: Player, enemy: EnemyService.Enemy?)
	getState(player).target = enemy
	player:SetAttribute("TargetEnemyId", if enemy then enemy.id else nil)
end

local function isInRange(player: Player, enemy: EnemyService.Enemy): boolean
	local character = player.Character
	local root = character and character.PrimaryPart
	return root ~= nil and (root.Position - enemy.root.Position).Magnitude <= Balance.Combat.range
end

-- Equipped characters that can attack, capped at the player's equip slots.
local function getAttackers(data: DataService.Data): ({ AttackClock.Attacker }, { [string]: string })
	local attackers = {}
	local characterIds = {}
	local slots = Formulas.equipSlots(data.Raids.Completions)
	for _, uid in data.Equipped do
		if #attackers >= slots then
			break
		end
		local owned = data.Characters[uid]
		if owned then
			table.insert(attackers, { uid = uid, cooldown = Formulas.characterCooldown(owned.id) })
			characterIds[uid] = owned.id
		end
	end
	return attackers, characterIds
end

local function onEnemyClicked(player: Player, enemy: EnemyService.Enemy)
	local data = DataService.getData(player)
	if data == nil or not data.UnlockedIslands[enemy.island] then
		return
	end
	setTarget(player, enemy)
end

local function onEnemyDied(enemy: EnemyService.Enemy)
	for player in enemy.damagers do
		local data = DataService.getData(player)
		if data then
			local moneyBoostActive = data.Boosts.Remaining.Money > 0
			DataService.addCurrency(player, "Yen", Formulas.killReward(enemy.island, enemy.rank, moneyBoostActive))
		end
	end
	for player, state in states do
		if state.target == enemy then
			setTarget(player, nil)
		end
	end
end

local function step()
	local now = time()
	for player, state in states do
		local enemy = state.target
		if enemy == nil then
			continue
		end
		if not enemy.alive or not isInRange(player, enemy) then
			setTarget(player, nil)
			continue
		end
		local data = DataService.getData(player)
		if data == nil then
			continue
		end
		local attackers, characterIds = getAttackers(data)
		for _, uid in AttackClock.collectHits(state.clock, attackers, now) do
			if EnemyService.damage(enemy, player, Formulas.characterDamage(characterIds[uid])) then
				break
			end
		end
	end
end

function CombatService.start()
	EnemyService.Clicked:Connect(onEnemyClicked)
	EnemyService.Died:Connect(onEnemyDied)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return CombatService
