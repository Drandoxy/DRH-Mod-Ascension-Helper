package mods.ascension_helper;

/**
 * Reports errors the mod recovers from to the game's log. Each place reports at most three times per
 * session, so a failure that repeats every frame cannot flood the log.
 */
class ErrorLog {
	public static var write:String->Void = null;

	static var counts:Map<String, Int> = new Map();

	public static function report(where:String, error:Dynamic):Void {
		var count = counts.exists(where) ? counts.get(where) : 0;
		if (count >= 3)
			return;
		counts.set(where, count + 1);
		if (write == null)
			return;
		var stack = "";
		try
			stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack())
		catch (_:Dynamic)
			stack = "";
		stack = StringTools.trim(stack);
		if (stack.length > 600)
			stack = stack.substr(0, 600) + "...";
		write(where + ": " + Std.string(error) + (stack == "" ? "" : " | stack: " + StringTools.replace(stack, "\n", " < "))
			+ (count == 2 ? " (further reports of this are hidden)" : ""));
	}

	public static function reset(?log:String->Void):Void {
		write = log;
		counts = new Map();
	}
}
