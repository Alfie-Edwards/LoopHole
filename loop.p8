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
		r = 7,
		w = 3,
	}
	curios = {}
	speed = 0.2
	z_start = 30

	dust_particles = {}
	dust_spawn_period = 0.05
	t_last_dust = 0
	dust_z_start_max = 20

	clip_plane = 0.1

	cam = {
		x = 0,
		y = 0,
		pan = 0.5,
	}
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
	local mdx = mouse.x - loop.x
	local mdy = mouse.y - loop.y
	local md = sqrt(mdx * mdx + mdy * mdy)
	local loop_speed = md / 4
	if md == 0 or md < loop_speed then
		loop.x = mouse.x
		loop.y = mouse.y
	else
		loop.x = loop.x + mdx * (loop_speed / md)
		loop.y = loop.y + mdy * (loop_speed / md)
	end
	if (btn(4)) then loop.r = loop.r - 1 end
	if (btn(5)) then loop.r = loop.r + 1 end

	loop.r = clamp(loop.r, loop.w, 32)
	loop.x = clamp(loop.x, -64, 63)
	loop.y = clamp(loop.y, -64, 63)

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
		local r = rnd(22 - loop.w)
		add_curio(rnd(128) - 64, rnd(128) - 64, r, 0)
	end

	-- add new dust
	if t() - t_last_dust > dust_spawn_period then
		local range = 64
		add_dust(rnd_range(-range, range) * dust_z_start_max + cam.x,
		         rnd_range(-range, range) * dust_z_start_max + cam.y)
		t_last_dust = t()
	end

	for _, curio in ipairs(curios) do
		curio_collides(curio)
	end

	update_cam()
end

function lerp_from_list(t_start, t_end, t, list)
	-- lerp `t` between `t_start` and `t_end`, and use that to index `list`
	return list[flr(((t - t_start) / (t_end - t_start)) * #list) + 1]
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
				0b1111111111111111.110,
				0b1111111111111111.110,
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
	local sr = c.r / c.z
	sspr(0, 0, 16, 16, sx - sr, sy - sr, 2 * sr, 2 * sr, c.flip_x, c.flip_y)
	fillp()
	pal()
end

function draw_dust(d)
	if d.z <= clip_plane then
		return
	end

	local sx, sy = world_to_screen(d.x, d.y, d.z)
	pset(sx, sy, 5)
end

function _draw()
	cls(0)

	-- Curios
	for _, curio in ipairs(curios) do
		draw_curio(curio)
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
	for w=0,loop.w-1 do
		circ(loop.x, loop.y, loop.r - w, 10)
	end

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
	return (x / z) + cam.x - (cam.x / z), (y / z) + cam.y - (cam.y / z)
end

function update_mouse()
	mouse.x = stat(32) - 64
	mouse.y = stat(33) - 64
	mouse.x = clamp(mouse.x, -64, 63)
	mouse.y = clamp(mouse.y, -64, 63)
end

function update_cam()
	cam.x = loop.x * cam.pan
	cam.y = loop.y * cam.pan
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
					printh("hit")
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
