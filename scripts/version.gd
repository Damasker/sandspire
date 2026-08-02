extends RefCounted
## Project version shown in UI (S16 / M4 MVP).

const VERSION := "0.4.0"
const CODENAME := "MVP"
const MILESTONE := "M4"


static func display_string() -> String:
	return "Sandspire %s (%s · %s)" % [VERSION, CODENAME, MILESTONE]


static func short_string() -> String:
	return "v%s" % VERSION
