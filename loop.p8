pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

-- Enable mouse
poke(0x5F2D, 1)

function approx_dist(dx, dy)
 local x,y=abs(dx),abs(dy)
 return max(x, y) * 0.9609 + min(x, y) * 0.3984
end


-- set some constants
z_start = 10

loop_max_r = 48
loop_min_r = 4
loop_nudge_amount = 0.5

loop_max_health = 3
loop_resize_rate = 2.5

paralax_amount = 0.1
zoom_amount = 0.3

clip_plane = 0.01

guides = {
	spans = {{-2, 2}},
	depths = {1, 1.05, 1.1},
	color = 1,
}

speed = 0.08




-- main behaviour
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
	loop.r = loop_max_r
	loop.health = loop_max_health
	cam = {
		x = 0,
		y = 0,
		zoom = 1,
	}
	-- update_cam()

	curios = {}

	timeline_idx = 1
	t_started_scene = 0

	-- TODO #finish: make this `title`
	current_screen = screens.gameplay
	t_started_screen = 0
end

function init_gameplay_screen()
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

	curios = {}

	timeline_idx = 1
	t_started_scene = t()
end

function scene_progress()
	-- 30 is because speed is applied to curios in _update at 30fps
	return (t() - t_started_scene) * speed * 30
end

function maybe_move_to_screen(new_screen)
	if (new_screen == nil) return
	if new_screen ~= current_screen then
		current_screen = new_screen
		t_started_scren = t()
		assert(current_screen.init ~= nil)
		current_screen.init()
	end
end

function any_input()
	return btn(4) or btn(5) or mouse.pressed
end

function lnpx(text) -- length of text in pixels
	return print(text, 0, 999999)
end

function print_centred(text, y, offset)
	print(text, (128 - lnpx(text)) / 2 + (offset or 0), y)
end

function strobe(period, offset)
	return (t() - (offset or 0) + period) % (period * 2) < period
end

function update_gameplay_screen()
	update_cam()

	if scene_should_end(timeline_idx, scene_progress()) then
		timeline_idx = go_to_next_scene(timeline_idx)
		t_started_scene = t()
	else
		local new_obstacles = update_scene(timeline_idx, scene_progress())
		for _, obstacle in ipairs(new_obstacles) do
			add(curios, obstacle, 1)
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

	-- update_cam()
end

function _update()
	update_mouse()

	assert(current_screen ~= nil)
	assert(current_screen.update ~= nil)
	maybe_move_to_screen(current_screen.update())
end

function die()
	printh("dead!!!!")
	-- TODO #finish: move to `dead` screen
	-- maybe_move_to_screen(screens.dead)
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
		for i=0,15 do pal(i, i+(13*16), 2) end
		fillp(lerp_from_list(z_start, 1, z, {
				0b1111111111111111.010,
				0b1111111111111111.010,
				0b1111111111111111.010,
				0b1111111111111111.010,
				0b1111111111111111.010,
				0b0111110101111101.010,
				0b1010010110100101.010,
				0b1000001010000010.010,
				0b0000000000000000.010,
			}))
	else
		fillp(lerp_from_list(loop.z, clip_plane, z, {
				0b0101101001011010.110,
				0b0111110101111101.110,
				0b1111011111011111.110,
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
	if c.type == "sprite" then
		-- local sx, sy = world_to_screen(c.x, c.y, c.z)
		-- local sr = cam.zoom * (c.r / c.z)
		-- sspr(0, 0, 16, 16, sx - sr, sy - sr, 2 * sr, 2 * sr, c.flip_x, c.flip_y)

		local sx, sy = world_to_screen(c.x, c.y, c.z)
		local sr = cam.zoom * (c.r / c.z)

		assert(c.id ~= nil)
		-- TODO #temp: use real sprite index once data's in
		local spr = temp_sprite_index[c.id]
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

		linefill(sx1, sy1, sx2, sy2, cam.zoom * (c.r / c.z), c.color)
	end
	fillp()
	pal()
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

	local ruler_z_start = z_start / 6

	for _, curio in ipairs(curios) do
		if curio.z >= loop.z and curio.z < ruler_z_start then
			local y = lerp(y_start, y_end - 1, proportion(ruler_z_start, loop.z, curio.z))
			print("◆", x - 3, y - 1, 8)
		end
	end

	pal()
end

function get_beat_state()
	for _, curio in ipairs(curios) do
		if curio.z <= loop.z and (loop.z - curio.z) < 0.5 then
				if curio.has_hit_player then
					return "bad"
				else
					return "good"
				end
		end
	end
	return "none"
end

function draw_health(x_offset, y_offset)
	local health_str = ""
	for i = 0, loop.health - 1 do
		health_str = health_str.."♥\n"
	end
	print(health_str, (10 - 64) + cam.x + x_offset, (10 - 64) + cam.y + y_offset, 8)
end

function draw_gameplay_screen()
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
	local loop_col = 10
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
	pset(mouse.x + cam.x - 1, mouse.y + cam.y, 7)
	pset(mouse.x + cam.x + 1, mouse.y + cam.y, 7)
	pset(mouse.x + cam.x, mouse.y + cam.y - 1, 7)
	pset(mouse.x + cam.x, mouse.y + cam.y + 1, 7)
end

function _draw()
	assert(current_screen ~= nil)
	assert(current_screen.draw ~= nil)
	current_screen.draw()
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
	if curio.z > loop.z then
		return false
	end

	if curio.type == "sprite" then
		assert(curio.id ~= nil)
		-- TODO #temp: use real sprite index once data's in
		local spr = temp_sprite_index[curio.id]
		assert(spr ~= nil)
		local scale = (2 * curio.r) / sqrt((spr.w * spr.w) + (spr.h * spr.h))
		local w, h = spr.w * scale, spr.h * scale
		for y = 0, spr.h-1 do
			for x = 0, spr.w-1 do
				if sget(spr.x + x, spr.y + y) ~= 0 then
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

function linefill(ax,ay,bx,by,r,c)
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
			rectfill(x0 - 64,y - 64,span - 64,y - 64, c + 13 * 16)
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

temp_sprite_index = {
	asteroid = {
		x = 0,
		y = 0,
		w = 16,
		h = 16,
	},
	blood_cell = {
		x = 3 * 8,
		y = 0,
		w = 8,
		h = 8,
	},
	atom = {
		x = 3 * 8,
		y = 0,
		w = 8,
		h = 8,
	},
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
	bateria = {
		x = 4 * 16,
		y = 0 * 16,
		w = 16,
		h = 16,
	},
	bateria2 = {
		x = 5 * 16,
		y = 0 * 16,
		w = 16,
		h = 7,
	},
	bateria3 = {
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
	dna = {
		x = 0 * 16,
		y = 2 * 16,
		w = 32,
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
	galaxy3 = {
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
}

-- include stuff
#include timeline.lua
#include title.lua
#include dead.lua


-- more constants (that depend on includes)...
screens = {
	title = {
		name = "title",
		init = init_title_screen,
		update = update_title_screen,
		draw = draw_title_screen,
	},
	gameplay = {
		name = "gameplay",
		init = init_gameplay_screen,
		update = update_gameplay_screen,
		draw = draw_gameplay_screen,
	},
	dead = {
		name = "dead",
		init = init_dead_screen,
		update = update_dead_screen,
		draw = draw_dead_screen,
	},
}

__gfx__
0000000065000000ff7777ff00888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000065555000f777777f08822880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006655560007770077788288288000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066666655560007700007782888828000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666666555555007700007782888828000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666566555555667770077788288288000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0656555665555556f777777f08822880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0655556665565555ff7777ff00888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
65555666555665500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55556666555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
65556555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66555555555556000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06555555665556000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555555565566000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555666556660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00656600066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00060000000000e6100e6100e6200e6200e6200e6200e6200f6200f63010630116301264013640146501565017650196601a6601b6601b6601b6601b6601c6601e66020660216602366024660246602566026670
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
010a00130075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750007500075000750
87100020006200462007620096200a6200a6200a6200a6200962008620066200562003620016200062000620006200062003620056200862009620096200a6200a6200a620096200762005620036200262000620
431000002805228052280522705227052270522605226052260522505225052250522505225052250522505502500005000050000000000000000000000000000000000000000000000000000000000000000000
091000001005110051100510f0510f0510f0510d0510d0510d0510c0510c0510c0510d0510c0510d0550000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1f1000000417000100001000317000100001000117000100001000017600100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
__music__
00 02424344
00 06070849
01 0a0b0c4e
00 0d0e0f44
00 41424344
00 05424344
00 41424344
00 41424344
00 01024344
