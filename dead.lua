function init_dead_screen()
	camera()
end

function update_dead_screen()
	if any_input() then
		return screens.gameplay
	end

	return screens.dead
end

function draw_dead_screen()
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
