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

function draw_dead_screen(t_started)
	cls(0)

	color(2)
	print_centred("ur dead!!!", 61)
	color(8)
	print_centred("ur dead!!!", 60)

	color(1)
	print_centred("PRESS ANY BUTTON TO RESTART...", 101)
	if strobe(0.66) then
		color(7)
	else
		color(6)
	end
	print_centred("PRESS ANY BUTTON TO RESTART...", 100)
end

function cleanup_dead_screen(t_started)
	music(-1)

	dead_screen.state.was_holding = {
		btn_4 = false,
		btn_5 = false,
		mouse = false,
	}
end
