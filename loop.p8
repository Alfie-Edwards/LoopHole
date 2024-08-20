pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

-- Enable mouse
poke(0x5F2D, 1)

function approx_dist(dx, dy)
 local x,y=abs(dx),abs(dy)
 return max(x, y) * 0.9609 + min(x, y) * 0.3984
end

function reset_pal()
	local bg_col = nil
	if current_screen == screens.gameplay then
		bg_col = get_current_scene().background_colour
		assert(bg_col ~= nil)
	end

	pal()

	pal(9, bg_col, 1)

	pal(0, 0, 0)
	pal(2, -13, 1)
	pal(3, -5, 1)
	pal(4, -7, 1)
	pal(8, -2, 1)
	pal(11, -6, 1)
	pal(10, -9, 1)
	pal(13, -10, 1)
	pal(14, -1, 1)
	palt(0, false)
	palt(9, true)

	-- TODO: UGLY
	if current_screen == screens.gameplay then
		o_col = get_current_scene().other
		if o_col ~= nil then
			-- pal(bg_col, o_col, 1)
			pal(3, o_col, 1)
		end
	end
end


-- set some constants
z_start = 10
ruler_z_start = 5

loop_max_r = 48
loop_min_r = 6
loop_nudge_amount = 0.5

loop_max_health = 10
loop_resize_rate = 2.5

paralax_amount = 0.1
zoom_amount = 0.3

clip_plane = 0.01

guides = {
	spans = {{-2, 2}},
	depths = {1, 1.05, 1.1},
	color = 1,
}

start_speed = 0.08
per_cycle_speed_multiplier = 1.1

damage_cooldown = 0.5
t_last_damage = 0


-- main behaviour
function _init()
	mouse = {}
	update_mouse()
	reset_pal()

	loop = {
		x = 0,
		y = 0,
		z = 1,
		r = 0,
		w = 10,
		health = 0,
	}
	loop.r = loop_max_r
	loop.health = loop_max_health
	cam = {
		x = 0,
		y = 0,
		zoom = 1,
	}

	speed = start_speed

	curios = {}

	seen_obstacle_scenes = 0

	t_started_scene = 0

	current_screen = screens.title
	t_started_screen = 0
	assert(current_screen.init ~= nil)
	current_screen.init(t_started_screen)
end

function init_gameplay_screen(t_started)
	music(2)

	update_cam()

	loop = {
		x = 0,
		y = 0,
		z = 1,
		r = 0,
		w = 10,
		health = 0,
	}
	loop.r = loop_max_r
	loop.health = loop_max_health

	speed = start_speed

	curios = {}

	timeline_idx = 1
	t_started_scene = t()

	t_last_damage = 0

	seen_obstacle_scenes = 0
	seen_obstacle_this_scene = false
end

function get_current_scene()
	assert(timeline_idx ~= nil)
	local res = scene(timeline_idx)
	assert(res ~= nil)
	return res
end

function cleanup_gameplay_screen(t_started)
	local current_scene = get_current_scene()

	if current_scene.end_scene ~= nil then
		current_scene.end_scene(current_scene)
	end
end

function scene_progress()
	-- 30 is because speed is applied to curios in _update at 30fps
	return (t() - t_started_scene) * speed * 30
end

function maybe_move_to_screen(new_screen)
	if (new_screen == nil) return
	if new_screen ~= current_screen then
		if (current_screen.cleanup ~= nil) current_screen.cleanup(t_started_screen)
		current_screen = new_screen
		t_started_screen = t()
		assert(current_screen.init ~= nil)
		current_screen.init(t_started_screen)
	end
end

function any_input()
	return btn(4) or btn(5) or mouse.pressed
end

function lnpx(text) -- length of text in pixels
	return print(text, 0, 999999)
end

function print_centred(text, y, offset)
	local cam_x = peek2(0x5f28)
	local cam_y = peek2(0x5f2a)
	print(text,
	      ((128 - lnpx(text)) / 2 + (offset or 0)) + cam_x,
	      y + cam_y)
end

function print_centred_chunks(chunks, y)
	-- print separately-formatted chunks in a single, horizontally-centred line
	-- chunks is a list of 1-to-3-tuples:
	-- { { fst_text },                         <-- draw in white
	--   { snd_text, col }, ... }              <-- draw in col
	--   { snd_text, col, shadow_col }, ... }  <-- draw in col, with a shadow_col shadow

	local cam_x = peek2(0x5f28)
	local cam_y = peek2(0x5f2a)

	local full_length = 0
	for _, chunk in ipairs(chunks) do full_length += lnpx(chunk[1]) end
	local length_acc = 0

	for _, chunk in ipairs(chunks) do
		local col = 7
		if (#chunk > 1) col = chunk[2]

		if #chunk > 2 then
			color(chunk[3])
			print(chunk[1], (128 - full_length) / 2 + cam_x + length_acc, y + cam_y + 1)
		end

		color(col)
		print(chunk[1], (128 - full_length) / 2 + cam_x + length_acc, y + cam_y)
		length_acc += lnpx(chunk[1])
	end
end

function strobe(period, offset)
	return (t() - (offset or 0) + period) % (period * 2) < period
end

function update_gameplay_screen(t_started)
	update_cam()

	if scene_should_end(timeline_idx, scene_progress()) then
		seen_obstacle_this_scene = false
		timeline_idx = go_to_next_scene(timeline_idx)
		t_started_scene = t()
		if timeline_idx > 1 and (timeline_idx - 1) % #timeline == 0 then
			speed *= per_cycle_speed_multiplier
		end
	else
		local new_obstacles = update_scene(timeline_idx, scene_progress())
		for _, obstacle in ipairs(new_obstacles) do
			add(curios, obstacle, 1)
		end

		-- for calculating score
		if #new_obstacles > 0 and not seen_obstacle_this_scene then
			seen_obstacle_scenes += 1
			seen_obstacle_this_scene = true
		end
	end

	-- update loop position & size
	if (btn(5)) then loop.r = loop.r - loop_resize_rate end
	if (btn(4)) then loop.r = loop.r + loop_resize_rate end
	loop.r = clamp(loop.r, loop_min_r, loop_max_r)

	local loop_nudge_extent = loop_nudge_amount * loop.r
	local mdx = (mouse.x * (loop_nudge_extent / 64)) - loop.x
	local mdy = (mouse.y * (loop_nudge_extent / 64)) - loop.y
	local md = sqrt(mdx * mdx + mdy * mdy)
	local loop_speed = md / 4
	if md == 0 or md < loop_speed then
		loop.x = loop.x + mdx
		loop.y = loop.y + mdy
	else
		loop.x = loop.x + mdx * (loop_speed / md)
		loop.y = loop.y + mdy * (loop_speed / md)
	end
	loop.x = clamp(loop.x, -loop_nudge_extent, loop_nudge_extent)
	loop.y = clamp(loop.y, -loop_nudge_extent, loop_nudge_extent)

	-- move & cull old curios
	local i = 1
	while i <= #curios do
		if curios[i].z < clip_plane then
			deli(curios, i)
		else
			curios[i].z = curios[i].z - speed
			i = i + 1
		end
	end

	-- play wooshes
	for _, curio in ipairs(curios) do
		if curio.type == "sprite" then
		end
		local woosh = nil
		if curio.type == "sprite" and
		   (curio.id == "plastic" or
		    curio.id == "plastic2" or
		    curio.id == "plastic3" or
		    curio.id == "plasticbag" or
		    curio.id == "can" or
		    curio.id == "cd") then
			woosh = wooshes.glug
		elseif curio.r > 20 then
			woosh = wooshes.big
		else
			woosh = wooshes.small
		end

		assert(woosh ~= nil)

		local time_left = (curio.z - loop.z) / (speed * 30)
		if time_left + (1 / 30) > woosh.crossover_point and
		   time_left <= woosh.crossover_point then
			sfx(woosh.idx)
		end
	end

	-- check for collision
	local player_hit = false
	for _, curio in ipairs(curios) do
		-- check every curio, so that if multiple curios hit the player at the
		-- same time they're both marked as such
		if (not curio.has_hit_player) and curio_collides(curio) then
			curio.has_hit_player = true
			player_hit = true
		end
	end

	if player_hit and (t() - t_last_damage) > damage_cooldown then
		-- apply damage just once
		loop.health = loop.health - 1
		t_last_damage = t()
		if loop.health == 0 then
			return screens.dead
		else
			sfx(flr(rnd_range(3, 5)))
		end
	end

	return screens.gameplay
end

function _update()
	update_mouse()

	assert(current_screen ~= nil)
	assert(current_screen.update ~= nil)
	maybe_move_to_screen(current_screen.update(t_started_screen))
end

function proportion(t_start, t_end, t)
	return (t - t_start) / (t_end - t_start)
end

function lerp(t_start, t_end, t)
	return (1 - t) * t_start + t * t_end
end

function lerp_from_list(t_start, t_end, t, list)
	-- lerp `t` between `t_start` and `t_end`, and use that to index `list`
	-- NOTE: returns `nil` if `t` out of range
	return list[flr(proportion(t_start, t_end, t) * #list) + 1]
end

function set_curio_fill_pattern(z)
	reset_pal()
	if z >= loop.z then
		-- map the secondary palette so that everything will go to lilac (13).
		-- giving `.010` to `fillp` means that for sprites, the colours for the fill pattern
		-- "are taken from the secondary palette". what this actually means is that:
		--
		-- * `1`s in the fill pattern will mean taking a colour from the *low bits* of the
		--   colour in the secondary palette that's mapped to from the sprite's colour.
		-- * `0`s are the same, but for the *high bits* of the colour in the secondary
		--   palette.
		--
		-- so if we were being explicit in setting the secondary palette, then instead of it
		-- being (intuitively) this:
		--
		-- pal({[0]=13, [1]=13, [2]=13, ...}, 2)
		--
		-- we actually want this:
		--
		-- pal({[0]=0xd0, [1]=0xd1, [2]=0xd2, ...}, 2)
		for i=0,15 do pal(i, i+(9*16), 2) end
		local fp = lerp_from_list(z_start, z_start*0.8, z, {
				0b0111110101111101.010,
				0b1010010110100101.010,
				0b1000001010000010.010,
				0b0000000000000000.010,
			})
		if (fp ~= nil) fillp(fp)
	else
		local fp = lerp_from_list(loop.z, clip_plane, z, {
				0b0101101001011010.110,
				0b0111110101111101.110,
				0b1111011111011111.110,
				0b1111111111111111.110,
				0b1111111111111111.110,
				0b1111111111111111.110,
			})
		if (fp ~= nil) fillp(fp)
	end
end

function draw_curio(c)
	if c.z <= clip_plane then
		return
	end

	set_curio_fill_pattern(c.z)
	if c.type == "sprite" then
		local sx, sy = world_to_screen(c.x, c.y, c.z)
		local sr = cam.zoom * (c.r / c.z)

		assert(c.id ~= nil)
		local spr = sprite_index[c.id]
		assert(spr ~= nil)

		local sx, sy = world_to_screen(c.x, c.y, c.z)
		local sr = cam.zoom * (c.r / c.z)
		local scale = (2 * sr) / sqrt((spr.w * spr.w) + (spr.h * spr.h))
		local sw, sh = spr.w * scale, spr.h * scale
		sspr(spr.x, spr.y,
		     spr.w, spr.h,
		     sx - sw/2, sy - sh/2,
		     sw, sh,
		     c.flip_x, c.flip_y)
	elseif c.type == "line" then
		local sx1, sy1 = world_to_screen(c.x1, c.y1, c.z)
		local sx2, sy2 = world_to_screen(c.x2, c.y2, c.z)

		linefill(sx1, sy1, sx2, sy2, cam.zoom * (c.r / c.z), c.color, 9)
	end
	fillp()
	reset_pal()
end

function draw_with_outline(outline_col, fn)
	-- fn is expected to take (x_offset, y_offset) and not reset the palette
	-- before drawing...
	for y = -1, 1 do
		for x = -1, 1 do
			if x ~= 0 or y ~= 0 then
				for i=0,15 do pal(i, outline_col) end
				fn(x, y)
			end
		end
	end

	reset_pal()
	fn(0, 0)
end

function draw_ruler(x_offset, y_offset)
	local x_pad = 3
	local y_pad = 5

	local x = (64 - x_pad) + cam.x + x_offset
	local y_start = (y_pad - 64) + cam.y + y_offset
	local y_end   = (64 - y_pad) + cam.y + y_offset

	-- Highlight on beat.
	local beat_state = get_beat_state()
	if beat_state == "good" then
		for i=0,15 do pal(i, 11) end
	elseif beat_state == "bad" then
		for i=0,15 do pal(i, 8) end
	end

	line(x, y_start,
		 x, y_end,
		 12)

	for _, curio in ipairs(curios) do
		if curio.z >= loop.z and curio.z < ruler_z_start then
			local y = lerp(y_start, y_end - 1, proportion(ruler_z_start, loop.z, curio.z))
			print("◆", x - 3, y - 1, 8)
		end
	end

	reset_pal()
end

function get_beat_state()
	local state = "none"
	for _, curio in ipairs(curios) do
		if curio.z <= loop.z and (loop.z - curio.z) < 0.5 then
				if curio.has_hit_player then
					return "bad"
				else
					state = "good"
				end
		end
	end
	return state
end

function draw_health(x_offset, y_offset)
	local health_str = ""
	for i = 0, loop.health - 1 do
		health_str = health_str.."♥\n"
	end
	print(health_str, (4 - 64) + cam.x + x_offset, (4 - 64) + cam.y + y_offset, 8)

	local missing_health_y = (#health_str / 2) * 6
	local missing_health_str = ""
	for i = loop.health, loop_max_health - 1 do
		missing_health_str = missing_health_str.."♥\n"
	end
	print(missing_health_str, (4 - 64) + cam.x + x_offset, (4 - 64) + missing_health_y + cam.y + y_offset, 2)
end

function draw_gameplay_screen(t_started)
	draw_background(timeline_idx, scene_progress())

	-- Curios ahead of the loop
	for _, curio in ipairs(curios) do
		if curio.z > loop.z then
			draw_curio(curio)
		end
	end

	-- Guides
	for _, depth in ipairs(guides.depths) do
		for _, span in ipairs(guides.spans) do
			local x, x1, x2, y, y1, y2

			-- top
			x1, y = world_to_screen(span[1], -64, depth)
			x2, y = world_to_screen(span[2], -64, depth)
			line(x1, y, x2, y, guides.color)

			-- bottom
			x1, y = world_to_screen(span[1], 63, depth)
			x2, y = world_to_screen(span[2], 63, depth)
			line(x1, y, x2, y, guides.color)

			-- left
			x, y1 = world_to_screen(-64, span[1], depth)
			x, y2 = world_to_screen(-64, span[2], depth)
			line(x, y1, x, y2, guides.color)

			-- right
			x, y1 = world_to_screen(63, span[1], depth)
			x, y2 = world_to_screen(63, span[2], depth)
			line(x, y1, x, y2, guides.color)
		end
	end

	-- Loop
	local bg_col = get_current_scene().background_colour
	assert(bg_col ~= nil)

	local loop_col = 7

	if bg_col == loop_col then
		loop_col = 1
	end

	local beat_state = get_beat_state()
	if beat_state == "good" then
		loop_col = 11
	elseif beat_state == "bad" then
		loop_col = 8
	end
	for w=0,true_loop_width() do
		circ(cam.zoom * loop.x, cam.zoom * loop.y, (cam.zoom * loop.r) - w, loop_col)
	end

	-- Curios at/behind the loop
	for _, curio in ipairs(curios) do
		if curio.z <= loop.z then
			draw_curio(curio)
		end
	end

	-- Ruler
	draw_with_outline(1, draw_ruler)

	-- Health
	draw_with_outline(2, draw_health)

	-- Cursor
	pset(mouse.x + cam.x - 1, mouse.y + cam.y, loop_col)
	pset(mouse.x + cam.x + 1, mouse.y + cam.y, loop_col)
	pset(mouse.x + cam.x, mouse.y + cam.y - 1, loop_col)
	pset(mouse.x + cam.x, mouse.y + cam.y + 1, loop_col)
end

function _draw()
	assert(current_screen ~= nil)
	assert(current_screen.draw ~= nil)
	current_screen.draw(t_started_screen)
end

function true_loop_width()
	return (cam.zoom * loop.w-1) * loop.r/64
end

function clamp(x, min_x, max_x)
	x = max(x, min_x)
	x = min(x, max_x)
	return x
end

function rnd_range(min, max)
	return rnd(max - min) + min
end

function world_to_screen(x, y, z)
	return cam.zoom * ((x / z) - cam.x + (cam.x / z)), cam.zoom * ((y / z) - cam.y + (cam.y / z))
end

function update_mouse()
	mouse.x = stat(32) - 64
	mouse.y = stat(33) - 64
	mouse.x = clamp(mouse.x, -64, 63)
	mouse.y = clamp(mouse.y, -64, 63)
end

function update_cam()
	cam.x = loop.x * paralax_amount
	cam.y = loop.y * paralax_amount
	cam.zoom = 8 / sqrt(loop.r)
	cam.zoom = 1 + (zoom_amount * (cam.zoom - 1))
	camera(cam.x - 64, cam.y - 64)
end

function curio_collides(curio)
	if curio.z > (loop.z + speed) or curio.z < loop.z then
		return false
	end

	if curio.type == "sprite" then
		assert(curio.id ~= nil)
		local spr = sprite_index[curio.id]
		assert(spr ~= nil)
		if not point_circle_intersection(curio.x, curio.y, curio.r + loop.r, loop.x, loop.y) then
			return false
		end
		local scale = (2 * curio.r) / sqrt((spr.w * spr.w) + (spr.h * spr.h))
		local w, h = spr.w * scale, spr.h * scale
		for y = 0, spr.h-1 do
			for x = 0, spr.w-1 do
				if sget(spr.x + x, spr.y + y) ~= 9 then
					local px = curio.x + ((x / (spr.w-1)) - 0.5) * w
					local py = curio.y + ((y / (spr.h-1)) - 0.5) * h
					if point_circle_intersection(px, py, loop.r, loop.x, loop.y) and not
							point_circle_intersection(px, py, loop.r - true_loop_width(), loop.x, loop.y) then
						return true
					end
				end
			end
		end
	elseif curio.type == "line" then
		return line_segment_circle_intersection(curio.x1, curio.y1, curio.x2, curio.y2, curio.r, loop.r, loop.x, loop.y, true_loop_width())
	end
	return false
end

function linefill(ax,ay,bx,by,r,c, fog_col)
	ax += 64
	ay += 64
	bx += 64
	by += 64
	local dx,dy=bx-ax,by-ay
	-- avoid overflow
	-- credits: https://www.lexaloffle.com/bbs/?tid=28999
	local d=max(abs(dx),abs(dy))
	local n=min(abs(dx),abs(dy))/d
	d*=sqrt(n*n+1)
	if(d<0.001) return
	local ca,sa=dx/d,-dy/d

	-- polygon points
	local s={
		{0,-r},{d,-r},{d,r},{0,r}
	}
	local u,v,spans=s[4][1],s[4][2],{}
	local x0,y0=ax+u*ca+v*sa,ay-u*sa+v*ca
	for i=1,4 do
		local u,v=s[i][1],s[i][2]
		local x1,y1=ax+u*ca+v*sa,ay-u*sa+v*ca
		local _x1,_y1=x1,y1
		if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
		local dx=(x1-x0)/(y1-y0)
		if(y0<0) x0-=y0*dx y0=-1
		local cy0=y0\1+1
		-- sub-pix shift
		x0+=(cy0-y0)*dx
		for y=y0\1+1,min(y1\1,127) do
			-- open span?
			local span=spans[y]
			if span then
			rectfill(x0 - 64,y - 64,span - 64,y - 64, c + fog_col * 16)
			else
			spans[y]=x0
			end
			x0+=dx
		end
		x0,y0=_x1,_y1
	end
end

function line_segment_circle_intersection(x1, y1, x2, y2, lw, r, cx, cy, cw)
	if point_circle_intersection(x1, y1, r - lw - cw, cx, cy) and point_circle_intersection(x2, y2, r - lw - cw, cx, cy) then
		return false
	end
	local dx, dy = x2 - x1, y2 - y1
	local scale = 1 / max(abs(dx), abs(dy)) -- avoid overflows.
	local sdx, sdy = dx * scale, dy * scale
	local t = ((cx - x1) * scale * sdx + (cy - y1) * scale * sdy) / (sdx * sdx + sdy * sdy)
	t = clamp(t, 0, 1)
	local tx, ty = x1 + t * dx, y1 + t * dy
	return point_circle_intersection(tx, ty, r + lw, cx, cy)
end

function point_circle_intersection(x, y, r, cx, cy)
	return approx_dist(cx - x, cy - y) < r
end

wooshes = {
	big = {
		idx = 0,
		crossover_point = 1.34,
	},
	small = {
		idx = 1,
		crossover_point = 0.29,
	},
	glug = {
		idx = 18,
		crossover_point = 0.033,
	},
}

sprite_groups = {
	atom = {"atom", "atom2", "atom3", "atom4"},
	bloodcell = {"bloodcell", "bloodcell2", "bloodcell3"},
	bacteria = {"bacteria", "bacteria2", "bacteria3"},
	cell = {"cell", "cell2", "cell3"},
	virus = {"virus", "virus2", "virus3", "virus4", "virus5", "virus6", "virus7"},
	star = {"star", "star2", "star3"},
	cloud = {"cloud", "cloud2"},
	meteor = {"meteor", "meteor2"},
	nebula = {"nebula", "nebula2"},
	galaxy = {"galaxy", "galaxy2"},
	planet = {"planet", "planet2", "planet3"},
	ringplanet = {"ringplanet", "ringplanet2"},
	plastic = {"plastic", "plastic2", "plastic3"},
}

sprite_index = {
	eye = {
		x = 0 * 16,
		y = 0 * 16,
		w = 16,
		h = 16,
	},
	eye2 = {
		x = 1 * 16,
		y = 0 * 16,
		w = 16,
		h = 16,
		corner = true,
	},
	bloodcell = {
		x = 2 * 16,
		y = 0 * 16,
		w = 16,
		h = 16,
	},
	bloodcell2 = {
		x = 3 * 16,
		y = 0 * 16,
		w = 16,
		h = 7,
	},
	bloodcell3 = {
		x = 3 * 16,
		y = 0 * 16 + 7,
		w = 16,
		h = 9,
	},
	bacteria = {
		x = 4 * 16,
		y = 0 * 16,
		w = 16,
		h = 16,
	},
	bacteria2 = {
		x = 5 * 16,
		y = 0 * 16,
		w = 16,
		h = 7,
	},
	bacteria3 = {
		x = 5 * 16,
		y = 0 * 16 + 7,
		w = 16,
		h = 9,
	},
	cell = {
		x = 6 * 16,
		y = 0 * 16,
		w = 16,
		h = 16,
	},
	cell2 = {
		x = 7 * 16,
		y = 0 * 16,
		w = 16,
		h = 7,
	},
	cell3 = {
		x = 7 * 16,
		y = 0 * 16 + 7,
		w = 16,
		h = 9,
	},
	virus = {
		x = 0 * 16,
		y = 1 * 16,
		w = 16,
		h = 16,
	},
	virus2 = {
		x = 1 * 16,
		y = 1 * 16,
		w = 16,
		h = 16,
	},
	virus3 = {
		x = 2 * 16,
		y = 1 * 16,
		w = 16,
		h = 16,
	},
	virus4 = {
		x = 3 * 16,
		y = 1 * 16,
		w = 16,
		h = 16,
	},
	virus5 = {
		x = 4 * 16,
		y = 1 * 16,
		w = 16,
		h = 5,
	},
	virus6 = {
		x = 4 * 16,
		y = 1 * 16 + 5,
		w = 16,
		h = 7,
	},
	virus7 = {
		x = 4 * 16,
		y = 1 * 16 + 13,
		w = 16,
		h = 3,
	},
	atom = {
		x = 5 * 16,
		y = 1 * 16,
		w = 16,
		h = 16,
	},
	atom2 = {
		x = 0 * 16,
		y = 2 * 16,
		w = 16,
		h = 16,
	},
	atom3 = {
		x = 1 * 16,
		y = 2 * 16,
		w = 16,
		h = 16,
	},
	atom4 = {
		x = 2 * 16,
		y = 2 * 16,
		w = 16,
		h = 16,
	},
	meteor = {
		x = 3 * 16,
		y = 2 * 16,
		w = 32,
		h = 32,
	},
	nebula = {
		x = 5 * 16,
		y = 2 * 16,
		w = 16,
		h = 16,
	},
	star = {
		x = 6 * 16,
		y = 2 * 16,
		w = 16,
		h = 16,
	},
	star2 = {
		x = 6 * 16,
		y = 2 * 16,
		w = 16,
		h = 16,
	},
	cloud = {
		x = 0 * 16,
		y = 3 * 16,
		w = 16,
		h = 16,
	},
	cloud2 = {
		x = 1 * 16,
		y = 3 * 16,
		w = 16,
		h = 16,
	},
	meteor2 = {
		x = 2 * 16,
		y = 3 * 16,
		w = 16,
		h = 16,
	},
	nebula2 = {
		x = 5 * 16,
		y = 3 * 16,
		w = 16,
		h = 16,
	},
	galaxy = {
		x = 6 * 16,
		y = 3 * 16,
		w = 16,
		h = 16,
	},
	galaxy2 = {
		x = 7 * 16,
		y = 3 * 16,
		w = 16,
		h = 16,
	},
	planet = {
		x = 0 * 16,
		y = 4 * 16,
		w = 16,
		h = 16,
	},
	planet2 = {
		x = 1 * 16,
		y = 4 * 16,
		w = 16,
		h = 16,
	},
	planet3 = {
		x = 2 * 16,
		y = 4 * 16,
		w = 16,
		h = 16,
	},
	earth = {
		x = 3 * 16,
		y = 4 * 16,
		w = 16,
		h = 16,
	},
	star3 = {
		x = 4 * 16,
		y = 4 * 16,
		w = 16,
		h = 16,
	},
	ringplanet = {
		x = 5 * 16,
		y = 4 * 16,
		w = 16,
		h = 16,
	},
	ringplanet2 = {
		x = 6 * 16,
		y = 4 * 16,
		w = 32,
		h = 32,
	},
	plastic = {
		x = 0 * 16,
		y = 5 * 16,
		w = 16,
		h = 16,
	},
	plastic2 = {
		x = 1 * 16,
		y = 5 * 16,
		w = 16,
		h = 16,
	},
	plastic3 = {
		x = 2 * 16,
		y = 5 * 16,
		w = 16,
		h = 16,
	},
	plasticbag = {
		x = 3 * 16,
		y = 5 * 16,
		w = 16,
		h = 16,
	},
	can = {
		x = 4 * 16,
		y = 5 * 16,
		w = 16,
		h = 16,
	},
	cd = {
		x = 5 * 16,
		y = 5 * 16,
		w = 16,
		h = 16,
	},
	fish = {
		x = 0 * 16,
		y = 6 * 16,
		w = 16 * 4,
		h = 16,
	},
	logo = {
		x = 4 * 16,
		y = 6 * 16,
		w = 16 * 4,
		h = 16 * 2,
	},
}

-- include stuff
#include timeline.lua
#include title.lua
#include dead.lua


-- more constants (that depend on includes)...
-- all fields except `cleanup` are mandatory
screens = {
	title = {
		name = "title",
		init = init_title_screen,
		update = update_title_screen,
		draw = draw_title_screen,
		cleanup = cleanup_title_scren,
	},
	gameplay = {
		name = "gameplay",
		init = init_gameplay_screen,
		update = update_gameplay_screen,
		draw = draw_gameplay_screen,
		cleanup = cleanup_gameplay_screen,
	},
	dead = {
		name = "dead",
		init = init_dead_screen,
		update = update_dead_screen,
		draw = draw_dead_screen,
		cleanup = cleanup_dead_scren,
	},
}

__gfx__
99999ffffff99999fffff9999999999999999ffffff99999999fffffffee9999999999b39999993b99933993393393b999999777777999999970660000007999
999ff777777ff99978777fff99999999999ffeeeeeeff999988eeeeeeeee8ff999999933999999339993aaaaaaaa933999977000000779997700066007000079
99f7777777777f9978877877f999999999feeeeeeeeeef99ff8888888888fee899b3999939999399b33abbbbbbbba99999700000000007997000000000070007
9f7777cccc7777f9787778777ff999999feeeeffffeeeee9eeffffffffffee889933999993aa3999339aaaaaaaaaa33b97000000000000799770000000000077
9f77cc1111cc77f977778777877f99999feeeffffffeeee98eeeeeeeeeeee88899993999aabbba999993bbb3bb3bb93397007000000000799997777777777799
f777c100001c777f777777777777f999feeefffeeee8eee89888888888888889b39993aabbbaab99933999339993399970000066000000079999999999999999
f77c10000701c77f7777777778877f99feefffeeeee88e88999988888888999933999abbbaabbb999b3999b39993b99970000666600000079999999977777999
f77c10000001c77f66677777777777f9feeffeeeeee88e8899999fffffff8999993aabbbaabb3a9999999b3993b993b970000666600000079999977700000779
f77c10000001c77fccc66777777777f9feefeeeeeee88e889999feeeeeeee8f999abbbaabbbba39999b393399339933970000066000000079977770000000007
f77c10000001c77fccccc677788887f9feefeeeeee888e8899feeeeeeeee8eef99abbaabbbaa993399339993aaaa399970000000007000079777000066600007
f777c100001c777f111ccc677778777ffeeefeeee888ee889fee8eeeee88eeee993babbbaa39993b999939aabbbbb93b70000007000000077700070066007007
9f77cc1111cc77f90001ccc67787777f9eeee888888ee8898eeee88888eeeee8339bbbba99939999b399aabbbaaaa33397000000000000797000000000000007
9f7777cccc7777f900001cc67777787f9feeee8888ee88898eeeeeeeeeeeee89b39993a3999933993333bbbaabbb399997000000000000797000000000000079
99f7777777777f99000001cc6777778f99feeeeeeee88899888eeeeeeee888999999399939993b9999993aa3ba3a939999700000000007997000700000777799
999ff777777ff999000001cc6777888f999ee8888888899998888888888899999933999993399999993399339933993399977000000779997000000777999999
99999ffffff99999000001cc6777777f9999988888899999998888888889999999b3999993b9999999b399b3993b993b99999777777999999777777999999999
9977997799999999997799977999999991111999999999999977997799999999797979797979997799999cccccc9999997733bbbaaab3329ccccc99999999999
9997177997999999799779779999999911cc119999999999999719799799999991c7c7c7c1999997999cc7777ccc1999776733bababbb332cccccccc99999999
7911c1197799999977911119997999991c7cc119999999997911c119779999991cccccccc177997799cc777777ccc199756633bbaaaab3321111ccccc9999999
771ccc11799999999711cc11977999991ccccc1199999999771ccc117999999971717171799777799cc7777777cccc19766633bbbbbbb3321111111cccc99999
91cc7cc119977999991c7cc11799799911cc7cc11999999991cc7cc11977999999797979979999999cc7777777cccc19756633bababab332111111111ccc9999
771ccccc11779999971ccccc11977999911ccccc11999999991ccccc1179979979979797997979971cc77777ccccccc1756633baaaaab3321111111111ccc999
7911cc7cc11999997711cc7cc11799999911cc7cc11999997711cc7cc119779997111111111111791cc77777ccccccc1666633bbbbbbb32211111111111ccc99
99711ccccc11779979911ccccc11977999911ccccc11999979911ccccc11799991c7cc7cc7cc7c111ccc77ccccccccc1566533babaab3222111111111111ccc9
977911cc7cc19779997711cc7cc17799999911cc7cc19999997711cc7cc119771cccccccccccccc11cccccccccccccc19552222332322229111111111111ccc9
9799711ccc1999999779911ccc1999999999911ccc1999999779911ccccc11791c7c7c7cc7c7cc7111cccccccccccc119999999cccc999991111111111111cc9
99977911c177799997997711c177799999999911c177999999997711cc7cc119971171711711717711ccccccccccc11199999ccc77ccc9991111111111111ccc
997799711999799999977991179979999999999119979999999979911ccccc199799797797997997911ccccccccc11199999c7777777ccc91111111111111ccc
9999977979997799999999979779779999999999999779999999997711cc7177999999999999999991111ccccc111119999777c7777777cc11111111111111cc
99999799779997779999997799799777999999999999797799999779911c11979c7c7c7c1999997799111111111111999777777cccc77cc911111111111111cc
99999999979999979999997999999997999999999999799799999999771179991cccccc1799779979991111111111999c77ccccc9777c99911111111111111cc
99999999999999779999999999999977999999999999777799999999799977991111111197779777999991111119999977cc999997c9999911111111111111cc
99999000000999999999966666699999999991111119999999999996699966666669999999999999999999199999999999999994499999999999999199999999
9990077770006999999667777666599999911777711109999999996556666665556dd699999999999991c199cc11999999999994499999999999991419999999
990077777700069999667777776665999911777777111099999999ddd56d6d5d5566ddd666999999991c11ca1111199999999944449999999999991419999999
900777777700006996677777776666599117777777111109999999ddd56dddddd5566dd66d69999919111aa1999911999999994aa49999999999914441999999
90077777770000699667777777666659911777777711110999999995dd5ddddddd566dd566669999911a171177a999199999944aa44999999999114441199999
6007777700000006566777776666666501177777111111109999666dddddddd6ddd555dd566d999991119a71117ac199444444aaaa4444449911144a44111999
60077777000000065667777766666665011777771111111099966556ddddddddddddd5ddd56d99991c1f11a77111ac19944aaaa77aaaa4494444444a44444449
60007700000000065666776666666665011177111111111099665dddddddd6ddddddddddd566d999119fa1f77771111199444aa77aa444991444aaa7aaa44419
6000000000000006566666666666666501111111111111109965dddddddddddddd666dd6dd65d9991f19aa1a77a711a9999944a77a4499999914444a44441999
660000000000006655666666666666550011111111111100965dd6dd56ddddddd66666dddd5ddd991cf11aa1aff1a9a999944aaaaaa44999999144a4a4419999
660000000000066655666666666665550011111111111000955dddddd5666dddd6555666ddd5d6d991a191c91171a11c99944aa44aa4499999914a444a419999
9660000000006669955666666666555990011111111100099955dddddd5556ddd66555566dddd6d991ca911a777111119994aa4444aa49999994444144449999
966660000066666995555666665555599000011111000009995666ddddd5556dd555ddd556ddd6699911c111111ac19199444449944444999914441914441999
9966666666666699995555555555559999000000000000999666565dddddd5dd5ddddddd56dd565d999111911aaf199199444999999444999144419991444199
999666666666699999955555555559999990000000000999965555ddddddddd5dddddddd56dd565d999999999111991999449999999944999144199999144199
999996666669999999999555555999999999900000099999955dddd5d6ddd5ddddddddddd5dd56dd999991911199999999999999999999999111999999911199
9999999777779999999999666666666999999ddfffd99999966666dd55d6ddddddddd5ddddd566d99999999a71aa211914191999491ff91899999918e91e99e1
999999ddd6d77999999966f777777f6699ffddd555ff99996655556dddd5ddddd6ddddddddd55659999972a11ac17aa991414991a4f848419949199988a8e419
99999dd667677d9999996f77766677f69ff5dddddd5ff999655ddd56ddd5dd6dd5dddddddddd55999999ca11111a1a71414a144aa777f4849449c199144747e1
999ddd6777777d699997ff776ff6777f9f5d5ffffdd5ffd965dddddd5ddd5d5ddd56dddddddd5599999a7119999912a194f4faa47cccaaa19a799144847aa881
99dd6777777776d999967777f7ff777fff5fff5555dd555d6dddddd5ddddddddddd55dd666555999991111999999917a1a8aaf44c111aa411994ec41c994484e
9dd6777777777dd999667777777f77f9f5df55dddddffff55dddddddddd6665dddddddd6566669999717199aa1999a1a884444f77c111c1191ea7ec1a7922198
9d66777ddd67dd69966f777777666699f5df5dddddff55f555dddd5dddd655d5ddddddd65555699991a199777a9991a1f41111c77c188f719c477c8c77ac4299
9d6777dd6677766696f77777766ff66955df5dffdd555d5556665dddddd65ddd5666ddd5dddd66997a1199a77a9991178119117ccc1188f194cc4c8777a84c19
9d677dd677677d6666f7777777f77f6955d5ddffffdddd555655dddd6666dddd5556dddddddd5669a219991aa1991179194917c111111c8f8987cc777a8118e1
dd777677777dddd66f77777777777ff995dddd555ffddfd5655ddddd6555ddddd566ddddddddd5697a1999ca299971a919947c1491c181c89a987aaaa8111219
d6777777777766dd6f777777766677f9955dffdd55fdd55595dddddd555ddd5ddd556ddddddddd69aa19999999991a1991917f499471c11849a7772e81117c29
d77777ddd777776dff66677766f66ff9995ffffdd55d55599555dd5555dddddddddd56dd5ddddd59a11999999911a7999997f4998f711c18299aa2111171c219
d777dd6dd6777666f77f66776fff66999995555ddf5555599955559995dd55dd5ddd55dddddd5d5921a999999c1a11999918c99917111c119a7a21e8cc11c1c1
6776777666666666f777ff67777f9999999955ddd555599999999999955ddd555dd55595ddddd5991a279191711a199998441994f81921119e811e4c2c1c991c
6677676666666669ff777ff777ff999999999555555999999999999999555555555599995555559917aca1a71a19999991f89f4848899111e81998128c29989c
9666666996666699ffff99fffff9999999999999999999999999999999555555555999999995599991a17a11999999991c99981119491199899e89c89c999999
99999ccccc29999999999eeeeff9999999999aaaaa39999999999cccccc999999941119119199119999999984448889999999999999999999999999ff4449999
9992cc22cc211999999eeef8effe4999999bbaabba33b999999cccccc33339991994411a14911499999988844eeeee4899999999999999999999884eeeeee999
992cc2ccc211129999e88feeefee4f9999ba33bbbab3ba999933ccc3333333991111444a44141991999884ee844488e899999999999999999ffffff444444e99
92cc12221111c21994888effffe44e899ba33bbbbab3bab99333ccc3333333399441144a414419199884ee84999948e8999999999999999fff4888448ee84489
9cc1111111cc2219944488eeee44ee899a33aabbab3bba3993333ccc333333399144444444411411984e88999999948899999999999994ff48884f4444ee8849
ccc11111ccc2211c88444888444ef884a33babbab33baa3a3c33cccc33333333111144aaa444441184e88999999994e49999999999994ff8884f44499944ee49
2cc11ccccc22111cf88844444eef8448a3bbaaab33aaab3a3ccccccccc3333331aaa4aa7aa44aaa18e88999ab99994e499999999999448444f88999999994e4e
22cccccc222111ccef8888eeeff44488a3b33333baabb33acccccccccc33c33391444a777a4411194e8499abb39948e4999999999448844f88889999999984ef
1222222221111c224eefeefff84448eea3bbbbaaabbb33a3333ccccccc3ccc3311444aa7aa444419484999bbb3994ee4999999994488ff8488999999999984ef
11112211111cc22c4444ff4444488ef4a3bbaaabbbb33ab3333ccccc33333ccc141444aaa44411198e49999339948e499999999448ff8888999999999999f4ef
1111111ccccc22ccff4444488888ef88a3aaab333333aa33333ccccc33333c3c1114444444444111e84999999998ee49999999448ff8e889999999999999f88f
9ccccccccc222cc99ff8888888eef8899333333bbbaab339933cccccc3333c399144144444144419e8499999994ee49999999448ff8e889999999999999848ff
9c222222222ccc1998fffffeeee888499bbbbbbbaaabb3399c3ccccccc333cc99111144a44114419e449999998ee48999999448ff8e8499999999999999448f4
99111111ccccc199994444448888849999babaaaabbb33999933ccccc333cc999499141a14191199ee444488e4448999999448ff8e8899999999999999f488f4
999111ccccccc9999994448888888999999aaabbb3333999999ccccc333cc9991991411a144999194e888e8e84489999994448fef889999bb99999999f88fff4
99999ccc111999999999988844499999999993333339999999999ccc3cc99999991199111991999994eee4484499999999448ff8889999bab3999999f4848f49
777779999999999999999999777779999977799977799999999999776666669999999666666999999999966666699999994eff88f99993bbb32999994844f449
766677777777777797777797799977999766679766679999999777776cccccc9999667777776699999966777777669999448feff9999933333299998844ff489
66666666666666667799977799999799769996769996799996777776cccccccc9967776666777699996777666677769994e8ff99999999233299998844ff4499
6677777667777766799997779997779979999679999679996777cc7ccccccccc9677767777677769967766777766776944efff9999999992299998844ff44999
677999766799976677997797777779997999997999997999677ccc7ccccccccc9677677557767769967677666677676948efe99999999999999988448f449999
679999d66d999d6697777777799977997999997999997999677ccc7ccccccccc67775757757577766776765555676776488fe9999999999999f88448f4499999
6dddddd66ddddd6697779977999997999799976799976999677ccccccccccccc6776575555756776676765599556767648ef9999999999999f84488f44999999
666666666666666697999977799977999977769977769999677ccccccccccccc677577577577577667676599995676764f8f999999999999e844888449999999
666777766666776677999979777777799766679766679799677ccc7ccccccccc567576566567576567676599995676764f8e9999999999ef4448f44999999999
6677997767777776779997799979999776999676999677996777c7777777cccc566566555566566567676559955676764f8eee9999999e8444ff449999999999
6779999d6799997697777777777999977999997999997699677777cccccc7ccc566565000056566567767655556767764f48feee9948444eeff4499999999999
6799999d6d9999d69977999977799997799999799999799967776cc9999777cc956565000056565996767766665595694f48888ee4448ee8f444999999999999
6dd999dd6d9999d6997999997977777979999979999979999779cc99999677cc9565675555765659967766777765995994f8e84844eefe844499999999999999
66ddddd66ddddd66997999977999999967999767999769999779c799999967cc9956567777656599996777666677599994ff4444effe84449999999999999999
999966666666666d9977777799999999967776967776999997767999999967c9999665555556699999966777777655999948888ff88844999999999999999999
99999999999999999999999999999999996669996669999999777999999967c9999996666669999999999666666999999944eef4488999999999999999999999
99999999999999999999999999999990000000000009999999999999999999990000000000000000000000000000000000000000000000000000000000000000
19999999999999999999999999999990001111100000000999999999999999990000000000000000000000000000000000000000000000000000000000000000
11199999999999999999999990000000000000000000000009999999999999990000000000000000000000f000000000000000000000000000000000000f0000
0101199999999999999990000006770607107707106071060000999999999999000000000f000000000000f000000000000000000f0000000000000000000000
9011111099999999990006107601771616707617717117066061111999999999000000000f000000000000f000000000000000000f0000000000000000000000
99001111099999900171076176616716176117117167161161661611199999990000f0000f000000000000f000000000000000000f00000000000000000f0000
99011010000101076176176177000000000000000000066166066661111199990000f0000f0000000000009999999999999999999f00000000000000000f0000
9990011101011711000000000006666666666001111111166106700617771999000000000f0000009999999999999999993399339f99999003300000000f0f00
9999000111100000666666666667677776677010100011671007007617071109000003300f0099999999999444444444443344339999999993300000000f0f00
999900110166666667777777777777777777600001111116106707701777111100000330099999999944444000000000003300334444499993399900000f0f00
999001101011666666676777677777777777777666000076106707706111166600f00339999944444400000000000000003300330000044443399999990f0f00
990010110099911111166666667667777777777777777666600600770066699900f00339944403330000033300033333003300330003330003344433339f0f00
900101009999999999911100000007677666667767676616110176067000001100f9933940003333300033333003333330330033003333300330033333399f0f
001100999999999999999990011110000000000006666666610116000111111900f993340003330333033303330330033033333303330333033003344339990f
0000999999999999999999999999999999999999900001111111111000009999099993340003300033033000330330033033333303300033033003344339999f
0999999999999999999999999999999999999999990000000000000099999999099993300003300033033000330330033033003303300033033003300339999f
9999999999999999999999999999999999999999999999999999999999999999099993300003300033033000330330033033003303300033033003333339999f
99999999999999999999999999999999999999999999999999999999999999999999933000033000330330003303300330330033033000330330033333299999
999999999999999999999999999999999999999999999999999999999999999949f9923000033000330330003303300330330033033000330330033000099994
999999999999999999999999999999999999999999999999999999999999999949f9992000023303320233033203300330330033023303320330033000999994
999999999999999999999999999999999999999999999999999999999999999904f999922200233320002333200333333033003300233320023302222f999940
999999999999999999999999999999999999999999999999999999999999999904f999999200022200000222000332220022002200022200002209999f999440
999999999999999999999999999999999999999999999999999999999999999900f449999999000000000000000330000000000000000000000999999f944400
9999999999999999999999999999999999999999999999999999999999999999000444999999990000000000000220000000000000000000999999999f444000
9999999999999999999999999999999999999999999999999999999999999999000004444999f99999999990000000000000000099999999999999444f400000
9999999999999999999999999999999999999999999999999999999999999999000000444444f9999999999999999999999999999999999f999444444f000000
9999999999999999999999999999999999999999999999999999999999999999000000000444f4449999999999999999999999999999999f4444440000000000
9999999999999999999999999999999999999999999999999999999999999999000000000000f4444444449999999999999999999444444f4440000000000000
99999999999999999999999999999999999999999999999999999999999999990000000000000000444444444444444444444444444444400000000000000000
99999999999999999999999999999999999999999999999999999999999999990000000000000000000000444444444444444444400000000000000000000000
99999999999999999999999999999999999999999999999999999999999999990000000000000000000000000000000000000000000000000000000000000000
99999999999999999999999999999999999999999999999999999999999999990000000000000000000000000000000000000000000000000000000000000000
__sfx__
00060000000000e6100e6100e6200e6200e6200e6200e6200f6200f63010630116301264013640146501565017650196601a6601b6601b6601b6601b6601c6601e66020660216602366024630246102561026600
000200000361004620056200c62011630166301a6301d6301f640226402465026650296602b6602d6602e6602f660306703167031760317602e7502d7402b7402a7402873025730217201c72018710137100f710
1f02000005550055500655008550095500c5500f55015550195501b5501e550205502155022550235502355024750237502275022750207501f7501c7501a75018750167501475012750107500d7500c7500b750
330300000267002670036700667004660046600566002650026500465003650026500265000650026500365003640016400264005630046200462005610056100660006600056000560004600046000360002600
000200001a2501025019250102500f250142500e2500d250102500b250092500b2500425000250072500525003250012500025000000000000000000000000000000000000000000000000000000000000000000
012100080e220112100e210102200e210112100e21010220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011e00081803518035180351801318055180551805518013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011e00081061500000136150000010613136150000012613000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
491e000824123000000c1230000024123000000c12300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
191e00101e3501e3501e3551800020350203502035500000063001e3501e3501e3550930021350213502135500000000000000000000000000000000000000000000000000000000000000000000000000000000
3128001424742247322472224712247122b7422b7322b7222b7122b7122a7422a7322a7222a7122a7122374223732237222371223712007000070000700007000070000700007000070000700007000070000700
000a00130075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750
87100020006200462007620096200a6200a6200a6200a6200962008620066200562003620016200062000620006200062003620056200862009620096200a6200a6200a620096200762005620036200262000620
431000002805228052280522705227052270522605226052260522505225052250522505225052250522505502500005000050000000000000000000000000000000000000000000000000000000000000000000
091000001005110051100510f0510f0510f0510d0510d0510d0510c0510c0510c0510d0510c0510d0550000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1f1000000417000100001000317000100001000117000100001000017600100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
011c002024742247422473224732247222472224712247122b7422b7422b7322b7322b7222b7222b7122b7122a7422a7422a7322a7322a7222a7222a7122a7122374223742237322373223722237222371223712
89070000216702167025670296702d6702f6702f6702f6602d6602a650246501d65017640116300d6300962005610026100061000610000000000000000000000000000000000000000000000000000000000000
cb010000025500e5501255015550125500c5500355000550005500055000550005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
__music__
00 02424344
03 06070849
03 100b0c4a
00 0d0e0f44
00 41424344
00 05424344
00 41424344
00 41424344
00 01024344

