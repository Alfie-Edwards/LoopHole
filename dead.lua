dead_screen = {
	input_cooldown = 0.25, -- seconds before accepting new input to restart the game
	state = {
		was_holding = {
			btn_4 = false,
			btn_5 = false,
		},
		dust_spawner = nil,
	}
}

function init_dead_screen(t_started)
	camera(-64, -64) -- offset needed for dust spawner
	music(3)

	dead_screen.state.was_holding = {
		btn_4 = btn(4),
		btn_5 = btn(5),
	}
	dead_screen.state.dust_spawner = _make_dust_spawner(1)
end

function started_new_input(t_started)
	local past_cooldown = (t() - t_started) > dead_screen.input_cooldown

	if (not dead_screen.state.was_holding.btn_4) and btn(4) then
		return past_cooldown
	else
		dead_screen.state.was_holding.btn_4 = btn(4)
	end

	if (not dead_screen.state.was_holding.btn_5) and btn(5) then
		return past_cooldown
	else
		dead_screen.state.was_holding.btn_5 = btn(5)
	end

	return false
end

function update_dead_screen(t_started)
	if started_new_input(t_started) then
		return screens.gameplay
	end

	-- assert(dead_screen.state.dust_spawner ~= nil)
	dead_screen.state.dust_spawner.update(dead_screen.state.dust_spawner)
	dead_screen.state.dust_spawner.maybe_spawn(dead_screen.state.dust_spawner)

	return screens.dead
end

function print_score()
	-- assert(seen_obstacle_scenes ~= nil)
	local score = max(seen_obstacle_scenes - 1, 0)

	local scale_word = "scale"
	if (score ~= 1) scale_word = "scales"
	print_centred_chunks({{"you travelled through "},
	                      {score, 11, 3},
	                      {" "..scale_word}},
	                     60)

	local cycles = flr(timeline_idx / #timeline)

	if cycles > 0 then
		local time_word = "time"
		if (cycles ~= 1) time_word = "times"
		print_centred_chunks({{"...and cycled ", 7, 1},
		                      {cycles, 10, 9},
		                      {" "..time_word.."!", 7, 1}},
		                     70)
	end
end

function draw_dead_screen(t_started)
	-- palette
	pal()
	pal(3, -13, 1)
	pal(9, -7, 1)
	cls(0)

	-- dust
	-- assert(dead_screen.state.dust_spawner ~= nil)
	dead_screen.state.dust_spawner.draw(dead_screen.state.dust_spawner)

	-- message
	color(2)
	print_centred("ur dead!!!", 41)
	color(8)
	print_centred("ur dead!!!", 40)

	-- score
	print_score()

	-- restart prompt
	color(1)
	print_centred("🅾️/❎ TO TRY AGAIN...", 101)
	if strobe(0.66) then
		color(7)
	else
		color(6)
	end
	print_centred("🅾️/❎ TO TRY AGAIN...", 100)
end

function cleanup_dead_screen(t_started)
	music(-1)

	dead_screen.state.was_holding = {
		btn_4 = false,
		btn_5 = false,
	}
	dead_screen.state.dust_spawner = nil
end
