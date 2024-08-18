function init_title_screen(t_started)
	camera()
	music(1)
end

function update_title_screen(t_started)
	if any_input() then
		return screens.gameplay
	end

	return screens.title
end

function draw_title_screen(t_started)
	cls(0)

	color(9)
	print_centred("loophole", 61)
	color(10)
	print_centred("loophole", 60)

	color(1)
	print_centred("PRESS ANY BUTTON...", 101)
	if strobe(0.66) then
		color(7)
	else
		color(6)
	end
	print_centred("PRESS ANY BUTTON...", 100)
end

function cleanup_title_screen(t_started)
	music(-1)
end
