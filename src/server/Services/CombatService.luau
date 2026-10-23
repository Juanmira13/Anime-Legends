--!strict
-- Player-chosen targets and automatic attacks from equipped characters.
-- Clicking an enemy selects it; equipped characters hit it on their cooldowns
-- while the player stays in range. Everyone who hit an island enemy gets its
-- yen as a drop of coins to collect (CoinService; raid rewards are handled by
-- RaidService).
-- The current target id is replicated as the player attribute "TargetEnemyId".
-- Each frame with hits fires Remotes.CharacterHit (owner, enemyId, hits) to all
-- clients, only so they can animate the hits.
-- The HUD's Attack button fires Remotes.AttackClick; each accepted click (a
-- target in range, at most Balance.Combat.maxClicksPerSecond per second) deals
-- Formulas.clickDamage of the team's DPS and answers Remotes.ClickHit
-- (enemyId, damage) to that player so they can draw the number.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Formulas)

local Server = script.Parent.Parent
local AttackClock = require(Server.Combat.AttackClock)
local ClickLimiter = require(Server.Combat.ClickLimiter)
local InventoryOps = require(Server.Inventory.InventoryOps)
local Remotes = require(Server.Remotes)
local CoinService = require(script.Parent.CoinService)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

export type Hit = {
	slot: number, -- index in the owner's EquippedCharacters
	damage: number,
}

type State = {
	target: EnemyService.Enemy?,
	clock: AttackClock.Clock,
	clicks: ClickLimiter.Limiter,
}

local states: { [Player]: State } = {}
local hitRemote = Remotes.event("CharacterHit")
local clickRemote = Remotes.event("AttackClick")
local clickHitRemote = Remotes.event("ClickHit")

local CombatService = {}

local function getState(player: Player): State
	local state = states[player]
	if state == nil then
		state = { target = nil, clock = AttackClock.new(), clicks = ClickLimiter.new() }
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

-- Equipped characters that can attack, and the slot of each one.
local function getAttackers(
	data: DataService.Data
): ({ AttackClock.Attacker }, { [string]: string }, { [string]: number })
	local attackers = {}
	local characterIds = {}
	local slotsByUid = {}
	for slot, member in InventoryOps.activeTeam(data) do
		table.insert(attackers, { uid = member.uid, cooldown = Formulas.characterCooldown(member.id) })
		characterIds[member.uid] = member.id
		slotsByUid[member.uid] = slot
	end
	return attackers, characterIds, slotsByUid
end

-- Island enemies need the island unlocked; raid enemies need the player in that raid.
local function canAttack(player: Player, data: DataService.Data, enemy: EnemyService.Enemy): boolean
	if enemy.island then
		return data.UnlockedIslands[enemy.island] == true
	end
	if enemy.raidSessionId then
		return player:GetAttribute("RaidSessionId") == enemy.raidSessionId
	end
	return false
end

local function onEnemyClicked(player: Player, enemy: EnemyService.Enemy)
	local data = DataService.getData(player)
	if data == nil or not canAttack(player, data, enemy) then
		return
	end
	setTarget(player, enemy)
end

-- An Attack button click: a share of the team's DPS on the current target.
local function onAttackClick(player: Player)
	local state = states[player]
	local enemy = state and state.target
	if state == nil or enemy == nil or not enemy.alive or not isInRange(player, enemy) then
		return
	end
	local data = DataService.getData(player)
	if data == nil or not canAttack(player, data, enemy) then
		return
	end
	if not ClickLimiter.allow(state.clicks, time(), Balance.Combat.maxClicksPerSecond) then
		return
	end
	local team = {}
	for _, member in InventoryOps.activeTeam(data) do
		table.insert(team, member.id)
	end
	local damage = Formulas.clickDamage(Formulas.teamDps(team))
	EnemyService.damage(enemy, player, damage)
	clickHitRemote:FireClient(player, enemy.id, damage)
end

local function onEnemyDied(enemy: EnemyService.Enemy)
	for player, state in states do
		if state.target == enemy then
			setTarget(player, nil)
		end
	end

	-- Raid enemies are rewarded by RaidService.
	local island, rank = enemy.island, enemy.rank
	if island == nil or rank == nil then
		return
	end
	for player in enemy.damagers do
		local data = DataService.getData(player)
		if data then
			local moneyBoostActive = data.Boosts.Remaining.Money > 0
			CoinService.drop(player, enemy.ground, Formulas.killReward(island, rank, moneyBoostActive))
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
		local attackers, characterIds, slotsByUid = getAttackers(data)
		local hits: { Hit } = {}
		for _, uid in AttackClock.collectHits(state.clock, attackers, now) do
			local damage = Formulas.characterDamage(characterIds[uid])
			table.insert(hits, { slot = slotsByUid[uid], damage = damage })
			if EnemyService.damage(enemy, player, damage) then
				break
			end
		end
		if #hits > 0 then
			-- Every client animates this player's characters; damage stays on the server.
			hitRemote:FireAllClients(player, enemy.id, hits)
		end
	end
end

function CombatService.start()
	EnemyService.Clicked:Connect(onEnemyClicked)
	EnemyService.Died:Connect(onEnemyDied)
	clickRemote.OnServerEvent:Connect(onAttackClick)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return CombatService
