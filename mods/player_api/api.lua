-- Minetest 0.4 mod: player
-- See README.txt for licensing and other information.

player_api = {}

-- Player animation blending
-- Note: This is currently broken due to a bug in Irrlicht, leave at 0
local animation_blend = 0

player_api.registered_models = { }

-- Local for speed.
local models = player_api.registered_models

function player_api.register_model(name, def)
	models[name] = def
end

-- Player stats and animations
local player_model = {}
local player_textures = {}
local player_anim = {}
local player_sneak = {}
player_api.player_attached = {}

function player_api.get_animation(player)
	local name = player:get_player_name()
	return {
		model = player_model[name],
		textures = player_textures[name],
		animation = player_anim[name],
	}
end

-- Called when a player's appearance needs to be updated
function player_api.set_model(player, model_name)
	local name = player:get_player_name()
	local model = models[model_name]
	if model then
		if player_model[name] == model_name then
			return
		end
		player:set_properties({
			mesh = model_name,
			textures = player_textures[name] or model.textures,
			visual = "mesh",
			visual_size = model.visual_size or {x = 1, y = 1},
			collisionbox = model.collisionbox or {-0.3, -1.0, -0.3, 0.3, 0.77, 0.3},
			stepheight = model.stepheight or 0.6,
		})
		player_api.set_animation(player, "stand")
	else
		player:set_properties({
			textures = {"player.png", "player_back.png"},
			visual = "upright_sprite",
			collisionbox = {-0.3, -0.0, -0.3, 0.3, 0.75, 0.3},
			stepheight = 0.6,
		})
	end
	player_model[name] = model_name
end

function player_api.set_textures(player, textures)
	local name = player:get_player_name()
	local model = models[player_model[name]]
	local model_textures = model and model.textures or nil
	player_textures[name] = textures or model_textures
	player:set_properties({textures = textures or model_textures,})
end

function player_api.set_animation(player, anim_name, speed)
	local name = player:get_player_name()
	if player_anim[name] == anim_name then
		return
	end
	local model = player_model[name] and models[player_model[name]]
	if not (model and model.animations[anim_name]) then
		return
	end
	local anim = model.animations[anim_name]
	player_anim[name] = anim_name
	player:set_animation(anim, speed or model.animation_speed, animation_blend)
end

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	player_model[name] = nil
	player_anim[name] = nil
	player_textures[name] = nil
end)

-- Localize for better performance.
local player_set_animation = player_api.set_animation
local player_attached = player_api.player_attached

-- Check each player and apply animations
minetest.register_globalstep(function(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local model_name = player_model[name]
		local model = model_name and models[model_name]
		if model and not player_attached[name] then
			local controls = player:get_player_control()
			local walking = false
			local animation_speed_mod = model.animation_speed or 30

			-- Determine if the player is walking
			if controls.up or controls.down or controls.left or controls.right then
				walking = true
			end

			-- Determine if the player is sneaking, and reduce animation speed if so
			if controls.sneak then
				animation_speed_mod = animation_speed_mod / 2
			end

			-- Apply animations based on what the player is doing
			if player:get_hp() == 0 then
				player_set_animation(player, "lay")
				player:set_eye_offset({x=0,y=-14,z=0},{x=0,y=0,z=0})
			elseif walking then
				if player_sneak[name] ~= controls.sneak then
					player_anim[name] = nil
					player_sneak[name] = controls.sneak
				end
				if controls.LMB then
					player_set_animation(player, "walk_mine", animation_speed_mod)
					player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
				else
					player_set_animation(player, "walk", animation_speed_mod)
					player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
				end
			elseif controls.LMB then
				player_set_animation(player, "mine")
			elseif player_anim[name] ~= "lay" and player_anim[name] ~= "sit" then
				player_set_animation(player, "stand", animation_speed_mod)
				player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
			end
		end
	end
end)

-- chat commands for changing animation to sitting and laying
minetest.register_chatcommand("sit",{
	func = function( name, param )
		local player = minetest.get_player_by_name(name)
		default.player_set_animation(player, "sit")
		player:set_eye_offset({x=0,y=-6,z=0},{x=0,y=-6,z=0})
	end,
})

minetest.register_chatcommand("sleep",{
	func = function( name, param )
		local player = minetest.get_player_by_name(name)
		default.player_set_animation(player, "lay")
		-- we can't have pos1p match pos3p because pos3p y offset is limited to -10
		player:set_eye_offset({x=0,y=-14,z=0},{x=0,y=-10,z=0})
	end,
})

minetest.register_chatcommand("stand",{
	func = function( name, param )
		local player = minetest.get_player_by_name(name)
		default.player_set_animation(player, "stand")
		player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
	end,
})
