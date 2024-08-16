pico-8 cartridge // http://www.pico-8.com
version 41

__lua__
function _init()
	loop = {
		x = 64,
		y = 64,
		r = 7,
		w = 5,
	}
end

function _update()
	if (btn(0)) then loop.x = loop.x - 1 end
	if (btn(1)) then loop.x = loop.x + 1 end
	if (btn(2)) then loop.y = loop.y - 1 end
	if (btn(3)) then loop.y = loop.y + 1 end
	if (btn(4)) then loop.r = loop.r - 1 end
	if (btn(5)) then loop.r = loop.r + 1 end
end

function _draw()
	cls(5)
	for w=0,loop.w-1 do
		circ(loop.x, loop.y, loop.r - w, 14)
	end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
