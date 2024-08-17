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
		r = 7,
		w = 3,
	}
	curios = {}
	speed = 0.2
	z_start = 30

	dust_particles = {}
	dust_spawn_period = 0.1
	t_last_dust = 0
	dust_z_start_max = 7

	camera(-64, -64)
end

function _update()
	update_mouse()

	-- update loop position & size
	local mdx = mouse.x - loop.x
	local mdy = mouse.y - loop.y
	local md = sqrt(mdx * mdx + mdy * mdy)
	local loop_speed = md * sqrt(loop.r) / 64
	if md < loop_speed then
		loop.x = mouse.x
		loop.y = mouse.y
	else
		loop.x = loop.x + mdx * (loop_speed / md)
		loop.y = loop.y + mdy * (loop_speed / md)
	end
	if (btn(4)) then loop.r = loop.r - 1 end
	if (btn(5)) then loop.r = loop.r + 1 end

	loop.r = clamp(loop.r, loop.w, 32)
	loop.x = clamp(loop.x, loop.r - 64, 64 - loop.r - 1)
	loop.y = clamp(loop.y, loop.r - 64, 64 - loop.r - 1)

	-- cull old curios (TODO: check collision)
	local i = 1
	while i <= #curios do
		curios[i].z = curios[i].z - speed
		if curios[i].z < 1 then
			deli(curios, i)
		else
			i = i + 1
		end
	end

	-- cull old dust
	i = 1
	while i <= #dust_particles do
		dust_particles[i].z = dust_particles[i].z - speed
		if dust_particles[i].z <= 0 then
			deli(dust_particles, i)
		else
			i = i + 1
		end
	end

	-- add new curios
	if (t() % 2) == 0 then
		local r = rnd(64)
		add_curio(rnd(128 - 2 * r) - 64 + r, rnd(128 - 2 * r) - 64 + r, r, 0)
	end

	-- add new dust
	if t() - t_last_dust > dust_spawn_period then
		local range = 128 * 1.5
		local cam_x, cam_y = get_cam()
		add_dust(rnd(range) + cam_x - 64, rnd(range) + cam_y - 64)
		t_last_dust = t()
	end
end

function get_cam()
	return peek2(0x5f28), peek2(0x5f2a)
end

function lerp_from_list(t_start, t_end, t, list)
	-- lerp `t` between `t_start` and `t_end`, and use that to index `list`
	return list[flr(((t - t_start) / (t_end - t_start)) * #list) + 1]
end

function set_curio_fill_pattern(z)
	pal()
	if z >= 1 then
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
		fillp(lerp_from_list(z_start, 0.2 * z_start, z, {
				0b0000000000000000.010,
				0b1000001010000010.010,
				0b0101101001011010.010,
				0b0111110101111101.010,
			}))
	end
end

function draw_curio(c)
	if c.z >= 1 then
		set_curio_fill_pattern(c.z)
		sspr(0, 0, 16, 16, (c.x - 8) / c.z, (c.y - 8) / c.z, 2 * c.r / c.z, 2 * c.r / c.z, c.flip_x, c.flip_y)
		fillp()
		pal()
	end
end

function draw_dust(d)
	if d.z >= 0 then
		pset((d.x) / d.z, (d.y) / d.z, 5)
	end
end

function _draw()
	cls(0)
	for _, curio in ipairs(curios) do
		draw_curio(curio)
	end
	for _, dust in ipairs(dust_particles) do
		draw_dust(dust)
	end
	for w=0,loop.w-1 do
		circ(loop.x, loop.y, loop.r - w, 10)
	end

	pset(mouse.x - 1, mouse.y, 7)
	pset(mouse.x + 1, mouse.y, 7)
	pset(mouse.x, mouse.y - 1, 7)
	pset(mouse.x, mouse.y + 1, 7)
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

function update_mouse()
	mouse.x = stat(32) - 64
	mouse.y = stat(33) - 64
	mouse.x = clamp(mouse.x, -64, 63)
	mouse.y = clamp(mouse.y, -64, 63)
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
