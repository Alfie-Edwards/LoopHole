dead_screen = {
	input_cooldown = 0.25, -- seconds before accepting new input to restart the game
	state = {
		was_holding = {
			btn_4 = false,
			btn_5 = false,
			mouse = false,
		}
	}
}

function init_dead_screen(t_started)
	camera()
	music(3)

	dead_screen.state.was_holding = {
		btn_4 = btn(4),
		btn_5 = btn(5),
		mouse = mouse.pressed,
	}
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

	if (not dead_screen.state.was_holding.mouse) and mouse.pressed then
		return past_cooldown
	else
		dead_screen.state.was_holding.btn_mouse = mouse.pressed
	end

	return false
end

function update_dead_screen(t_started)
	if started_new_input(t_started) then
		return screens.gameplay
	end

	return screens.dead
end

function print_centred_chunks(chunks, y)
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

function print_score()
	assert(seen_obstacle_scenes ~= nil)
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
	pal()
	pal(3, -13, 1)
	pal(9, -7, 1)
	cls(0)

	color(2)
	print_centred("ur dead!!!", 41)
	color(8)
	print_centred("ur dead!!!", 40)

	print_score()

	color(1)
	print_centred("🅾️/❎ TO RESTART...", 101)
	if strobe(0.66) then
		color(7)
	else
		color(6)
	end
	print_centred("🅾️/❎ TO RESTART...", 100)
end

function cleanup_dead_screen(t_started)
	music(-1)

	dead_screen.state.was_holding = {
		btn_4 = false,
		btn_5 = false,
		mouse = false,
	}
end
