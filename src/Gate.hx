package mods.ascension_helper;

/** Never issue overlapping requests or silently retry an uncertain timed-out write. */
class Gate {
	public var pending(default, null):String;
	public var until(default, null) = 0.0;

	var blocked:Array<String> = [];

	public function new() {}

	public function begin(key:String, now:Float):Bool {
		if (pending != null || blocked.indexOf(key) >= 0)
			return false;
		pending = key;
		until = now + 30;
		return true;
	}

	public function finish(key:String, success:Bool):Bool {
		if (pending != key)
			return false;
		if (!success && blocked.indexOf(key) < 0)
			blocked.push(key);
		pending = null;
		return true;
	}

	public function timeout(now:Float):Bool {
		if (pending == null || now < until)
			return false;
		// Keep the request lease until its callback. Its server outcome is unknown.
		if (blocked.indexOf(pending) < 0)
			blocked.push(pending);
		return true;
	}

	public function allowed(key:String):Bool
		return pending == null && blocked.indexOf(key) < 0;

	public function reset():Void {
		if (pending == null)
			blocked = [];
	}
}
