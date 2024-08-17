pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

poke(0x5F2D, 1) -- Mouse

function _init()
	mouse = {}
	update_mouse()

	loop = {
		x = 0,
		y = 0,
		z = 1,
		r = 0,
		w = 10,
		health = 0,
	}
	loop_max_r = 48
	loop_min_r = 4
	loop_nudge_amount = 0.5
	loop.r = loop_max_r
	loop_max_health = 3
	loop.health = loop_max_health
	loop_resize_rate = 2.5

	curios = {}
	speed = 0.2
	z_start = 30
	paralax_amount = 0.1
	zoom_amount = 0.1

	dust_particles = {}
	dust_spawn_period = 0.05
	t_last_dust = 0
	dust_z_start_max = 20

	clip_plane = 0.001

	cam = {}
	update_cam()

	guides = {
		spans = {{-2, 2}},
		depths = {1, 1.05, 1.1},
		color = 1,
	}

	curios = {}
	speed = 0.08
end

function _update()
	update_mouse()

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

	-- move & cull old dust
	i = 1
	while i <= #dust_particles do
		if dust_particles[i].z < clip_plane then
			deli(dust_particles, i)
		else
			dust_particles[i].z = dust_particles[i].z - speed
			i = i + 1
		end
	end

	-- add new curios
	if (t() % 2) == 0 then
		local r = rnd(0.7 * (loop_max_r - loop.w) - 16) + 16
		add_curio(rnd(16) - 8, rnd(16) - 8, r, 0)
	end

	-- add new dust
	if t() - t_last_dust > dust_spawn_period then
		local range = 64
		add_dust(rnd_range(-range, range) * dust_z_start_max + cam.x,
		         rnd_range(-range, range) * dust_z_start_max + cam.y)
		t_last_dust = t()
	end

	for _, curio in ipairs(curios) do
		if (not curio.has_hit_player) and curio_collides(curio) then
			curio.has_hit_player = true
			loop.health = loop.health - 1
			printh("hit (health is now "..loop.health..")")
			if loop.health == 0 then
				die()
			end
		end
	end

	update_cam()
end

function die()
	-- TODO #finish
	printh("dead!!!!")
end

function proportion(t_start, t_end, t)
	return (t - t_start) / (t_end - t_start)
end

function lerp(t_start, t_end, t)
	return (1 - t) * t_start + t * t_end
end

function lerp_from_list(t_start, t_end, t, list)
	-- lerp `t` between `t_start` and `t_end`, and use that to index `list`
	return list[flr(proportion(t_start, t_end, t) * #list) + 1]
end

function set_curio_fill_pattern(z)
	pal()
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
		for i=0,15 do pal(i, 13+i*16, 2) end
		fillp(lerp_from_list(z_start, 1, z, {
				0b0000000000000000.010,
				0b0000000000000000.010,
				0b0000000000000000.010,
				0b0000000000000000.010,
				0b0000000000000000.010,
				0b1000001010000010.010,
				0b0101101001011010.010,
				0b0111110101111101.010,
				0b1111111111111111.010,
			}))
	else
		fillp(lerp_from_list(loop.z, clip_plane, z, {
				0b0101101001011010.110,
				0b0111110101111101.110,
				0b1111011111011111.110,
				0b1111111111111111.110,
			}))
	end
end

function draw_curio(c)
	if c.z <= clip_plane then
		return
	end

	set_curio_fill_pattern(c.z)
	local sx, sy = world_to_screen(c.x, c.y, c.z)
	local sr = cam.zoom * (c.r / c.z)
	sspr(0, 0, 16, 16, sx - sr, sy - sr, 2 * sr, 2 * sr, c.flip_x, c.flip_y)
	fillp()
	pal()
end

function draw_dust(d)
	if d.z <= clip_plane then
		return
	end

	local sx, sy = world_to_screen(d.x, d.y, d.z)
	pset(sx / d.z, sy / d.z, 5)
end

function draw_with_outline(outline_col, fn)
	-- fn is expected to take (x_offset, y_offset) and not reset the palette
	-- before drawing...
	for y = -1, 1 do
		for x = -1, 1 do
			for i=0,15 do pal(i, outline_col) end
			fn(x, y)
		end
	end

	pal()
	fn(0, 0)
end

function draw_ruler(x_offset, y_offset)
	local x_pad = 3
	local y_pad = 5

	local x = (64 - x_pad) + cam.x + x_offset
	local y_start = (y_pad - 64) + cam.y + y_offset
	local y_end   = (64 - y_pad) + cam.y + y_offset

	line(x, y_start,
		 x, y_end,
		 12)

	for _, curio in ipairs(curios) do
		if curio.z >= loop.z then
			local y = lerp(y_start, y_end - 1, proportion(z_start, loop.z, curio.z))
			rectfill(x - 1, y - 1, x + 1, y + 1, 8)
		end
	end
end

function draw_health(x_offset, y_offset)
	local health_str = ""
	for i = 0, loop.health - 1 do
		health_str = health_str.."♥\n"
	end
	print(health_str, (10 - 64) + cam.x + x_offset, (10 - 64) + cam.y + y_offset, 8)
end

function _draw()
	cls(0)

	-- Curios ahead of the loop
	for _, curio in ipairs(curios) do
		if curio.z > loop.z then
			draw_curio(curio)
		end
	end

	-- Dust
	for _, dust in ipairs(dust_particles) do
		draw_dust(dust)
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
	for w=0,(cam.zoom * loop.w-1) * loop.r/64  do
		circ(cam.zoom * loop.x, cam.zoom * loop.y, (cam.zoom * loop.r) - w, 10)
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
	pset(mouse.x + cam.x - 1, mouse.y + cam.y, 7)
	pset(mouse.x + cam.x + 1, mouse.y + cam.y, 7)
	pset(mouse.x + cam.x, mouse.y + cam.y - 1, 7)
	pset(mouse.x + cam.x, mouse.y + cam.y + 1, 7)
end

function clamp(x, min_x, max_x)
	x = max(x, min_x)
	x = min(x, max_x)
	return x
end

function add_curio(x, y, r, id)
	add(curios, {
		x = x,
		y = y,
		z = z_start,
		r = r,
		id = id,
		flip_x = rnd(1) < 0.5,
		flip_y = rnd(1) < 0.5,
		has_hit_player = false,
	}, 1)
end

function rnd_range(min, max)
	return rnd(max - min) + min
end

function add_dust(x, y)
	add(dust_particles, {
		x = x,
		y = y,
		z = rnd_range(dust_z_start_max * 0.5, dust_z_start_max),
	}, 1)
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
	cam.zoom = 64 / loop.r
	cam.zoom = 1 + (zoom_amount * (cam.zoom - 1))
	camera(cam.x - 64, cam.y - 64)
end

function curio_collides(curio)
	if curio.z > loop.z then
		return false
	end

	local sx = (curio.id % 8) * 16 + 8
	local sy = (curio.id \ 8) * 16 + 8
	for y = -8, 7 do
		for x = -8, 7 do
			if sget(sx + x, sy + y) ~= 0 then
				local dx = (loop.x - curio.x - x)
				local dy = (loop.y - curio.y - y)
				local sqd = dx * dx + dy * dy
				if sqd < loop.r * loop.r and (sqd > (loop.r - loop.w) * (loop.r - loop.w)) then
					return true
				end
			end
		end
	end
	return false
end

__gfx__
00000000650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000655550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006655560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066666655560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666666555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666566555555660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06565556655555560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06555566655655550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
65555666555665500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55556666555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
65556555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66555555555556000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06555555665556000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555555565566000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555666556660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00656600066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
