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

			if not this.state.completed_indices[this.state.plan_idx] and progress > candidate.progress then
				this.state.completed_indices[this.state.plan_idx] = true
				this.state.plan_idx += 1

				-- deepcopy the curio to make it easy to reset the scene and
				-- have it still work next time around
				local curios = deepcopy(candidate.curios)

				if curios[1] == nil then
					curios = {curios}
				end

				local result = {}
				for _, curio in ipairs(curios) do
					add(this.state.submitted, curio)
					add(result, curio)
				end

				return result
			end

			return {}
		end,
		draw_background=function(this, progress, next_bg_col)
			reset_pal()
			palt(9, false)
			cls(9)

			reset_pal()
			if (this.state.dust_spawner ~= nil) this.state.dust_spawner.draw(this.state.dust_spawner)
		end,
		end_scene=function(this)
			this.state.plan_idx = 1
			this.state.submitted = {}
			this.state.completed_indices = {}

			if (this.state.dust_spawner ~= nil) this.state.dust_spawner.reset(this.state.dust_spawner)
		end,
		state = {
			plan_idx = 1,
			submitted = {},
			completed_indices = {},

			dust_spawner = dust_spawner, -- NOTE: may be nil
		},
		plan = plan,
	}
end

function _make_wipe_scene(bg_col, duration)
	return {
		background_colour = bg_col,
		has_finished=function(this, progress)
			return progress >= duration
		end,
		draw_background=function(this, progress, next_bg_col)
			reset_pal()

			palt(9, false)
			cls(9)

			-- circfill(0, 0, 192 / ((191 * (duration - progress) / duration) + 1), this.background_colour)
			circfill(0, 0, 192 / ((191 * (duration - progress) / duration) + 1), 3)

			-- TODO: UGLY
			this.other = next_bg_col
		end,
		other = nil,
	}
end

-- size = the width of the sprite in the world (not on the sprite sheet)
--        for 'corner' sprites, this is the width of *one* of the corners.
function _make_sprite_zoom_scene(bg_col, sprite, spr_z_start, size, x, y, flip_x, flip_y)
	if (x == nil) x = 0
	if (y == nil) y = 0
	if (flip_x == nil) flip_x = false
	if (flip_y == nil) flip_y = false

	return {
		background_colour=bg_col,
		has_finished=function(this, progress)
			return progress >= spr_z_start
		end,
		draw_background=function(this, progress, next_bg_col)
			reset_pal()
			palt(9, false)
			cls(9)
			reset_pal()

			local z = spr_z_start - progress
			if z == 0 then
				z = 0.01
			end

			local sx, sy = world_to_screen(x, y, z)
			local ssize = cam.zoom * (size / z)

			if sprite.corner then
				-- NOTE: smush the quarters together by a pixel cause otherwise
				--       you get thin gaps when far away
				-- top-left
				sspr(sprite.x, sprite.y,
				     sprite.w, sprite.h,
				     (sx - ssize) + 1, (sy - ssize) + 1,
				     ssize, ssize,
				     true, false)
				-- top-right
				sspr(sprite.x, sprite.y,
				     sprite.w, sprite.h,
				     sx, (sy - ssize) + 1,
				     ssize, ssize,
				     false, false)
				-- bottom-left
				sspr(sprite.x, sprite.y,
				     sprite.w, sprite.h,
				     (sx - ssize) + 1, sy,
				     ssize, ssize,
				     true, true)
				-- bottom-right
				sspr(sprite.x, sprite.y,
				     sprite.w, sprite.h,
				     sx, sy,
				     ssize, ssize,
				     false, true)
			else
				local srad = ssize / 2
				sspr(sprite.x, sprite.y,    -- sprite_x, sprite_y
				     sprite.w, sprite.h,    -- sprite_w, sprite_h
				     sx - srad, sy - srad,  -- x, y
				     ssize, ssize,          -- w, h
				     false, false)          -- flip_x, flip_y
			 end
		end,
	}
end

-- a: angle (0 == horizontal, 1 == 360 degrees)
-- dist: offset from the centre of the field
-- scale: scaling factor applied to the whole vein (inc. cell size, between-wall distance)
-- r: scaling factor on cells
-- line_r: scaling factor on walls (which also affects size of cells)
function vein_curio(config)
	local curios = {}

	-- spacing between cell & wall
	local spacing = (config.line_r * config.scale) * 3
	-- offset of {first wall, cells, second wall} from centre of the field
	local dists = {
		config.dist - config.r * config.scale - spacing,
		config.dist,
		config.dist + config.r * config.scale + spacing,
	}

	add(curios, inf_line_curio({a = config.a, dist = dists[1], r = config.line_r * config.scale, color = 8}))
	add(curios, inf_line_curio({a = config.a, dist = dists[3], r = config.line_r * config.scale, color = 8}))

	local sprite_r = (dists[3] - dists[1] - 4 * spacing) / 2
	local sa, ca = sin(config.a), cos(config.a)

	for i=-3,3 do
		local dist = i * (spacing + sprite_r * 2)
		add(curios, sprite_curio({
			x = dist * ca + dists[2] * sa,
			y = dist * sa + dists[2] * ca,
			r = sprite_r,
			id = "bloodcell",
		}))
	end
	return curios
end

function stick_and_ball_curio(config)
	local curios = {}
	local max_d = 0
	for i, ball in ipairs(config.balls) do
		for j=i+1,#config.balls do
			local d = approx_dist(ball, config.balls[j])
			if d > max_d then
				max_d = d
			end
		end
	end
	max_d += (2 * config.ball_r)
	local scale = config.scale * (config.r * 2) / max_d

	for _, ball in ipairs(config.balls) do
		add(curios,
			sprite_curio({
				x = ball.x * scale + config.x,
				y = ball.y * scale + config.y,
				r = config.ball_r * scale,
				id = "atom",
			}))
	end

	for _, stick in ipairs(config.sticks) do
		add(curios,
			line_curio({
				x1 = config.balls[stick[1]].x * scale + config.x,
				y1 = config.balls[stick[1]].y * scale + config.y,
				x2 = config.balls[stick[2]].x * scale + config.x,
				y2 = config.balls[stick[2]].y * scale + config.y,
				r = config.stick_r * scale / 2,
				color = config.stick_color,
			}))
	end
	return curios
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

function ball_ring(n, r)
	local balls = {}
	for a = 1/n,1,1/n do
		add(balls, {x = cos(a) * r, y = sin(a) * r})
	end
	return balls
end

function sticks_open_loop(n)
	local sticks = {}
	for i = 1, n - 1 do
		add(sticks, {i, i + 1})
	end
	return sticks
end

function sticks_closed_loop(n)
	local sticks = {{n, 1}}
	for i = 1, n - 1 do
		add(sticks, {i, i + 1})
	end
	return sticks
end

function inf_line_curio(curio)
	if curio.dist < 0 then
		curio.a = (curio.a + 0.5) % 1
		curio.dist *= -1
	end
	local sa, ca = sin(curio.a), cos(curio.a)
	local very_far = 2000
	curio.x1 = -very_far * ca - curio.dist * sa
	curio.y1 = -very_far * sa + curio.dist * ca
	curio.x2 = very_far * ca - curio.dist * sa
	curio.y2 = very_far * sa + curio.dist * ca
	curio.dist = nil
	curio.a = nil
	return line_curio(curio)
end


timeline = {
	-- mandatory fields:
	--
	-- * background_colour = int
	-- * has_finished = function(this, progress)
	--
	-- optional (but called with fallbacks externally):
	--
	-- * draw_background = function(this, progress, next_bg_col)
	-- * update = function(this, progress)  (should return any new curios to handle)
	-- * end_scene = function(this)
	_make_sprite_zoom_scene(15, sprite_index.eye2, z_start, 32),
	_make_curio_spawner_scene(0,
		{
			{
				progress = 0,
				curios = sprite_curio({
					x = 2, y = 2,
					r = 6, id = "cell2",
				}),
			},
			{
				progress = 10,
				curios = sprite_curio({
					x = -3, y = 4,
					r = 11, id = "cell",
				}),
			},
			{
				progress = 14,
				curios = sprite_curio({
					x = -4, y = -3,
					r = 13, id = "cell3",
				}),
			},
			{
				progress = 20,
				curios = sprite_curio({
					x = 6, y = -4,
					r = 16, id = "cell3",
				}),
			},
			{
				progress = 36,
				curios = sprite_curio({
					x = 0, y = 1,
					r = 24, id = "cell",
				}),
			},
			{
				progress = 48,
				curios = sprite_curio({
					x = -45, y = -30,
					r = 30, id = "cell2",
				}),
			},
			{
				progress = 54,
				curios = sprite_curio({
					x = 40, y = -17,
					r = 33, id = "cell3",
				}),
			},
			{
				progress = 58,
				curios = sprite_curio({
					x = 4, y = -2,
					r = 35, id = "cell",
				}),
			},
			{
				progress = 64,
				curios = sprite_curio({
					x = 2, y = -48,
					r = 38, id = "cell",
				}),
			},
		}, _make_dust_spawner(6)),
	_make_wipe_scene(0, 10),
	_make_curio_spawner_scene(8,
		{
			{
				progress = 0,
				curios = sprite_curio({
					x = -16, y = -16,
					r = 8, id = "bloodcell",
				}),
			},
			{
				progress = 4,
				curios = sprite_curio({
					x = -8, y = -8,
					r = 10, id = "bloodcell2",
				}),
			},
			{
				progress = 6,
				curios = sprite_curio({
					x = 0, y = 0,
					r = 11, id = "bloodcell",
				}),
			},
			{
				progress = 8,
				curios = vein_curio({
					a = rnd(1),
					dist = 64,
					r = 10,
					line_r = 1,
					scale = 1,
				})
			},
			{
				progress = 10,
				curios = sprite_curio({
					x = 8, y = 8,
					r = 13, id = "bloodcell3",
				}),
			},
			{
				progress = 14,
				curios = vein_curio({
					a = rnd(1),
					dist = 64,
					r = 10,
					line_r = 1,
					scale = 1.5,
				})
			},
			{
				progress = 18,
				curios = sprite_curio({
					x = 16, y = 16,
					r = 17, id = "bloodcell2",
				}),
			},
			{
				progress = 22,
				curios = sprite_curio({
					x = -53, y = 16,
					r = 19, id = "bloodcell2",
				}),
			},
			{
				progress = 28,
				curios = sprite_curio({
					x = -53, y = -4,
					r = 20, id = "bloodcell",
				}),
			},
			{
				progress = 32,
				curios = sprite_curio({
					x = -4, y = 3,
					r = 22, id = "bloodcell3",
				}),
			},
			{
				progress = 36,
				curios = vein_curio({
					a = rnd(1),
					dist = 0,
					r = 10,
					line_r = 1,
					scale = 4,
				})
			},
		}, _make_dust_spawner(8)),
	_make_wipe_scene(8, 10),
	_make_curio_spawner_scene(2,
		{
			{
				progress = 0,
				curios = sprite_curio({
					x = 2, y = 2,
					r = 6, id = "bacteria2",
				}),
			},
			{
				progress = 10,
				curios = sprite_curio({
					x = -3, y = 4,
					r = 11, id = "bacteria",
				}),
			},
			{
				progress = 14,
				curios = sprite_curio({
					x = -4, y = -3,
					r = 13, id = "bacteria3",
				}),
			},
			{
				progress = 20,
				curios = sprite_curio({
					x = 6, y = -4,
					r = 16, id = "bacteria3",
				}),
			},
			{
				progress = 36,
				curios = sprite_curio({
					x = 0, y = 1,
					r = 24, id = "bacteria",
				}),
			},
			{
				progress = 48,
				curios = sprite_curio({
					x = -45, y = -30,
					r = 30, id = "bacteria2",
				}),
			},
			{
				progress = 54,
				curios = sprite_curio({
					x = 40, y = -17,
					r = 33, id = "bacteria3",
				}),
			},
			{
				progress = 58,
				curios = sprite_curio({
					x = 4, y = -2,
					r = 35, id = "bacteria",
				}),
			},
			{
				progress = 64,
				curios = sprite_curio({
					x = 2, y = -48,
					r = 38, id = "bacteria",
				}),
			},
		}, _make_dust_spawner(4)),
	_make_curio_spawner_scene(2,
		{
			{
				progress = 0,
				curios = sprite_curio({
					x = 2, y = 2,
					r = 6, id = "virus2",
				}),
			},
			{
				progress = 10,
				curios = sprite_curio({
					x = -3, y = 4,
					r = 11, id = "virus",
				}),
			},
			{
				progress = 14,
				curios = sprite_curio({
					x = -4, y = -3,
					r = 13, id = "virus3",
				}),
			},
			{
				progress = 20,
				curios = sprite_curio({
					x = 6, y = -4,
					r = 16, id = "virus4",
				}),
			},
			{
				progress = 36,
				curios = sprite_curio({
					x = 0, y = 1,
					r = 24, id = "virus",
				}),
			},
			{
				progress = 48,
				curios = sprite_curio({
					x = -45, y = -30,
					r = 30, id = "virus5",
				}),
			},
			{
				progress = 54,
				curios = sprite_curio({
					x = 40, y = -17,
					r = 33, id = "virus3",
				}),
			},
			{
				progress = 58,
				curios = sprite_curio({
					x = 4, y = -2,
					r = 35, id = "virus6",
				}),
			},
			{
				progress = 64,
				curios = sprite_curio({
					x = 2, y = -48,
					r = 38, id = "virus7",
				}),
			},
		}, _make_dust_spawner(4)),
	_make_sprite_zoom_scene(2, sprite_index.virus4, 15, 32, -0.5, -0.5),
	_make_curio_spawner_scene(7,
	{
		{
			progress = 0,
			curios = stick_and_ball_curio({
				x = 0, y = 0, r = 12, scale = 0.16,
				ball_r = 8, stick_r = 2,
				stick_color = 6,
				balls = ball_ring(4, 12),
				sticks = {{1, 2}, {2, 4}, {3, 4}},
			})
		},
		{
			progress = 5,
			curios = stick_and_ball_curio({
				x = 0, y = 0, r = 12, scale = 0.2,
				ball_r = 4, stick_r = 2,
				stick_color = 6,
				balls = ball_ring(3, 12),
				sticks = sticks_open_loop(3),
			})
		},
		{
			progress = 10,
			curios = stick_and_ball_curio({
				x = -16, y = 0, r = 12, scale = 0.24,
				ball_r = 4, stick_r = 2,
				stick_color = 6,
				balls = ball_ring(2, 12),
				sticks = sticks_open_loop(2),
			})
		},
		{
			progress = 15,
			curios = stick_and_ball_curio({
				x = 12, y = -12, r = 12, scale = 0.28,
				ball_r = 4, stick_r = 2,
				stick_color = 6,
				balls = ball_ring(3, 12),
				sticks = sticks_open_loop(3),
			})
		},
		{
			progress = 20,
			curios = stick_and_ball_curio({
				x = 0, y = 0, r = 12, scale = 0.32,
				ball_r = 4, stick_r = 2,
				stick_color = 6,
				balls = ball_ring(3, 12),
				sticks = sticks_closed_loop(3),
			})
		},
		{
			progress = 25,
			curios = stick_and_ball_curio({
				x = -12, y = 12, r = 12, scale = 0.36,
				ball_r = 4, stick_r = 2,
				stick_color = 6,
				balls = ball_ring(4, 12),
				sticks = {{1, 2}, {2, 4}, {3, 4}, {1, 3}},
			})
		},
		{
			progress = 30,
			curios = stick_and_ball_curio({
				x = 0, y = 0, r = 12, scale = 0.5,
				ball_r = 4, stick_r = 2,
				stick_color = 6,
				balls = ball_ring(5, 12),
				sticks = sticks_open_loop(5),
			})
		},
	}, _make_dust_spawner(6)),
	_make_sprite_zoom_scene(7, sprite_index.atom, 10, 32, -0.5, -0.5),
	_make_curio_spawner_scene(0,
	{
		{
			progress = 0,
			curios = sprite_curio({
				x = 2, y = 2,
				r = 6, id = "nebula2",
			}),
		},
		{
			progress = 10,
			curios = sprite_curio({
				x = -3, y = 4,
				r = 11, id = "nebula",
			}),
		},
		{
			progress = 14,
			curios = sprite_curio({
				x = -4, y = -3,
				r = 13, id = "nebula2",
			}),
		},
		{
			progress = 20,
			curios = sprite_curio({
				x = 6, y = -4,
				r = 16, id = "nebula2",
			}),
		},
		{
			progress = 36,
			curios = sprite_curio({
				x = 0, y = 1,
				r = 24, id = "nebula",
			}),
		},
		{
			progress = 48,
			curios = sprite_curio({
				x = -45, y = -30,
				r = 30, id = "nebula",
			}),
		},
		{
			progress = 54,
			curios = sprite_curio({
				x = 40, y = -17,
				r = 33, id = "nebula2",
			}),
		},
		{
			progress = 58,
			curios = sprite_curio({
				x = 4, y = -2,
				r = 35, id = "nebula",
			}),
		},
		{
			progress = 64,
			curios = sprite_curio({
				x = 2, y = -48,
				r = 38, id = "nebula",
			}),
		},
	}, _make_dust_spawner(6)),
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
