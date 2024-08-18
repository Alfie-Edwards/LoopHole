function init_dead_screen()
	camera()
end

function update_dead_screen()
	-- TODO #finish: restarting???
	return screens.dead
end

function draw_dead_screen()
	cls(0)

	color(2)
	print_centred("ur dead!!!", 61)
	color(8)
	print_centred("ur dead!!!", 60)
end
