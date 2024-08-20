title_screen = {
	state_dust_spawner = nil,
}

function init_title_screen(t_started)
	camera(-64, -64) -- offset needed for dust spawner
	music(1)
	title_screen.state_dust_spawner = _make_dust_spawner(7)
end

function update_title_screen(t_started)
	if btn(4) or btn(5) then
		return screens.gameplay
	end

	-- assert(title_screen.state_dust_spawner ~= nil)
	title_screen.state_dust_spawner.update(title_screen.state_dust_spawner)
	title_screen.state_dust_spawner.maybe_spawn(title_screen.state_dust_spawner)

	return screens.title
end

function draw_title_screen(t_started)
	-- use the game's normal palette...
	reset_pal()
	-- ...but colour the orange of the loop as orange
	pal(9, 9, 1)
	palt(9, false)

	-- background colour
	cls(0)

	-- dust
	-- assert(title_screen.state_dust_spawner ~= nil)
	title_screen.state_dust_spawner.draw(title_screen.state_dust_spawner)

	-- logo
	local logo_idx = 200
	local logo_sw = 8
	local logo_sh = 4

	local logo_y = 36 + sin((t() - t_started) * 0.25) * 5

	local logo_x = 64 - (logo_sw * 4)

	local cam_x, cam_y = get_true_cam()

	logo_x += cam_x
	logo_y += cam_y

	spr(logo_idx, logo_x, logo_y, logo_sw, logo_sh)

	-- controls
	function column(text1, text2, separation, y)
		local x1 = 64 - (separation/2 + lnpx(text1))
		print(text1, x1 + cam_x, y + cam_y)
		local x2 = 64 + separation/2
		print(text2, x2 + cam_x, y + cam_y)
	end
	color(6)
	local column_separation = 8
	column("🅾️", "GROW", column_separation, 80)
	column("❎", "SHRINK", column_separation, 88)
	column("mouse", "MOVE", column_separation, 96)

	-- prompt
	local prompt = "🅾️/❎ TO START..."
	color(1)
	print_centred(prompt, 111)
	if strobe(0.66) then
		color(7)
	else
		color(6)
	end
	print_centred(prompt, 110)
end

function cleanup_title_screen(t_started)
	music(-1)

	title_screen.state_dust_spawner = nil
end
