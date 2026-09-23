local Format = require("../src/shared/Format")

return {
	["small numbers stay as they are"] = function()
		assert(Format.abbreviate(0) == "0")
		assert(Format.abbreviate(999) == "999")
	end,

	["thousands and millions get suffixes"] = function()
		assert(Format.abbreviate(1500) == "1.5K", Format.abbreviate(1500))
		assert(Format.abbreviate(2000000) == "2M", Format.abbreviate(2000000))
		assert(Format.abbreviate(1999) == "1.9K", "rounds down, never up")
	end,

	["negative numbers keep their sign"] = function()
		assert(Format.abbreviate(-1500) == "-1.5K")
	end,
}
