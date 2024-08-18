function deepcopy(orig)
	-- from lua users wiki
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function _make_dust_spawner(colour, spawn_period, z_start_max, xy_range)
	if (colour == nil) colour = 5
	if (spawn_period == nil) spawn_period = 0.05
	if (z_start_max == nil) z_start_max = 20
	if (xy_range == nil) xy_range = 64

	return {
		colour = colour,
		spawn_period = spawn_period,
		z_start_max = z_start_max,
		xy_range = xy_range,
		reset = function(this)
			this.state.particles = {}
			this.state.t_last = 0
		end,
		update = function(this)
			-- move & cull
			local i = 1
			while i <= #this.state.particles do
				if this.state.particles[i].z < clip_plane then
					deli(this.state.particles, i)
				else
					this.state.particles[i].z = this.state.particles[i].z - speed
					i = i + 1
				end
			end
		end,
		maybe_spawn = function(this)
			-- add new particles
			if t() - this.state.t_last > this.spawn_period then
				add(this.state.particles, {
					x = rnd_range(-this.xy_range, this.xy_range) * this.z_start_max + cam.x,
					y = rnd_range(-this.xy_range, this.xy_range) * this.z_start_max + cam.y,
					z = rnd_range(this.z_start_max * 0.5, this.z_start_max),
				}, 1)
				this.state.t_last = t()
			end
		end,
		draw = function(this)
			for _, p in ipairs(this.state.particles) do
				if p.z <= clip_plane then
					return
				end

				local sx, sy = world_to_screen(p.x, p.y, p.z)
				pset(sx, sy, this.colour)
			end
		end,
		state = {
			particles = {},
			t_last = 0,
		},
	}
end

function _make_curio_spawner_scene(bg_col, plan, dust_spawner)
	return {
		background_colour=bg_col,
		has_finished=function(this, progress)
			if #this.state.submitted < #this.plan then
				return false
			end

			for i, c in ipairs(this.state.submitted) do
				if c.z >= speed then
					return false
				end
			end

			return true
		end,
		update=function(this, progress)
			if (this.state.dust_spawner ~= nil) this.state.dust_spawner.update(this.state.dust_spawner)

			-- check whether we're done spawning new curios
			if this.state.plan_idx > #this.plan then
				return {}
			end

			-- add new dust (don't spawn any more dust after the last curio's spawned)
			if (this.state.dust_spawner ~= nil) this.state.dust_spawner.maybe_spawn(this.state.dust_spawner)

			-- potentially spawn new curios
			local candidate = this.plan[this.state.plan_idx]

			if #this.state.submitted < this.state.plan_idx and progress > candidate.progress then
				this.state.plan_idx += 1

				-- deepcopy the curio to make it easy to reset the scene and
				-- have it still work next time around
				local instance = deepcopy(candidate.curio)

				add(this.state.submitted, instance)
				return {instance}
			end

			return {}
		end,
		draw_background=function(this, progress, next_bg_col)
			cls(this.background_colour)

			if (this.state.dust_spawner ~= nil) this.state.dust_spawner.draw(this.state.dust_spawner)
		end,
		end_scene=function(this)
			this.state.plan_idx = 1
			this.state.submitted = {}

			if (this.state.dust_spawner ~= nil) this.state.dust_spawner.reset(this.state.dust_spawner)
		end,
		state = {
			plan_idx = 1,
			submitted = {},

			dust_spawner = dust_spawner, -- NOTE: may be nil
		},
		plan = plan,
	}
end

function sprite_curio(curio)
	curio.type = "sprite"
	curio.has_hit_player = false
	if curio.flip_x == nil then
		curio.flip_x = rnd(1) < 0.5
	end
	if curio.flip_y == nil then
		curio.flip_y = rnd(1) < 0.5
	end
	if curio.z == nil then
		curio.z = z_start
	end
	return curio
end

function line_curio(curio)
	curio.type = "line"
	curio.has_hit_player = false
	if curio.z == nil then
		curio.z = z_start
	end
	return curio
end

function inf_line_curio(curio)
	local sa, ca = sin(curio.a), cos(curio.a)
	curio.x1 = -100 * ca + curio.dist * sa
	curio.y1 = -100 * sa + curio.dist * ca
	curio.x2 = 100 * ca + curio.dist * sa
	curio.y2 = 100 * sa + curio.dist * ca
	curio.dist = nil
	curio.a = nil
	return line_curio(curio)
end

timeline = {
	-- mandatory fields:
	--
	-- * background_colour (int)
	-- * has_finished=function(this, progress)
	--
	-- optional (but called with fallbacks externally):
	--
	-- * draw_background=function(this, progress, next_bg_col)
	-- * update=function(this, progress)  (should return any new curios to handle)
	-- * end_scene=function(this)

	{  -- eye
		background_colour=15,
		has_finished=function(this, progress)
			return progress >= z_start
		end,
		draw_background=function(this, progress, next_bg_col)
			cls(this.background_colour)

			palt(0, false)
			palt(15, true)

			local z = z_start - progress
			if z == 0 then
				z = 0.01
			end

			local r = 16 -- half the width of the sprite in the world (not on the sprite sheet)

			local sx, sy = world_to_screen(0, 0, z)
			local sr = cam.zoom * (r / z)
			sspr(2 * 8, 0,          -- sprite_x, sprite_y
			     8, 8,              -- sprite_w, sprite_h
			     sx - sr, sy - sr,  -- x, y
			     2 * sr, 2 * sr,    -- w, h
			     false, false)      -- flip_x, flip_y
		end,
	},
	_make_curio_spawner_scene(0,
		{
			{
				progress = 0,
				curio = sprite_curio({
					x = 0, y = 0,
					r = 16, id = "asteroid",
				}),
			},
			{
				progress = 20,
				curio = sprite_curio({
					x = 12, y = 12,
					r = 12, id = "asteroid",
				}),
			}
		}, _make_dust_spawner()),
	{  -- red wipe
		background_colour= 0,
		end_col = 8,
		duration = 10,
		has_finished=function(this, progress)
			return progress >= 10
		end,
		draw_background=function(this, progress, next_bg_col)
			cls(this.background_colour)
			circfill(0, 0, 192 / ((191 * (this.duration - this.progress) / this.duration) + 1), this.end_col)
		end,
	},
	_make_curio_spawner_scene(2,
		{
			{
				progress = 0,
				curio = sprite_curio({
					x = -16, y = -16,
					r = 8, id = "blood_cell",
				}),
			},
			{
				progress = 2.5,
				curio = sprite_curio({
					x = -8, y = -8,
					r = 8, id = "blood_cell",
				}),
			},
			{
				progress = 5,
				curio = sprite_curio({
					x = 0, y = 0,
					r = 8, id = "blood_cell",
				}),
			},
			{
				progress = 7.5,
				curio = sprite_curio({
					x = 8, y = 8,
					r = 8, id = "blood_cell",
				}),
			},
			{
				progress = 10,
				curio = sprite_curio({
					x = 16, y = 16,
					r = 8, id = "blood_cell",
				}),
			},
		}, _make_dust_spawner(14)),
}

function scene(idx)
    return timeline[((idx - 1) % #timeline) + 1]
end

function go_to_next_scene(idx)
	local current = scene(idx)

	if current.end_scene ~= nil then
		current.end_scene(current)
	end

	return idx + 1
end

function draw_background(idx, progress)
	local current = scene(idx)

	if current.draw_background == nil then
		-- no background drawer, just draw a colour
		assert(current.background_colour ~= nil)
		cls(current.background_colour)
	else
		-- have a background drawer, call it
		local next_bg_col = scene(idx + 1).background_colour
		assert(next_bg_col ~= nil)
		current.draw_background(current, progress, next_bg_col)
	end
end

function update_scene(idx, progress)  -- returns any new curios to handle
	local current = scene(idx)

	if current.update == nil then
		return {}
	end

	return current.update(current, progress)
end

function scene_should_end(idx, progress)
	local current = scene(idx)
	assert(current.has_finished ~= nil)

	return current.has_finished(current, progress)
end
