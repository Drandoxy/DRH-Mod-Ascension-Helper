package mods.ascension_helper;

/**
 * A hero's training plan: an ordered list of up to 300 points, each one of the four stats (0-3).
 * Adding appends to the end; removing takes that stat's last points, so the rest keeps its order.
 */
class StatPlan {
	public static inline var MAX_TOTAL = 300;
	public static inline var MAX_STAT = 75;

	public static function counts(list:Array<Int>):Array<Int> {
		var result = [0, 0, 0, 0];
		for (s in list)
			if (s >= 0 && s < 4)
				result[s]++;
		return result;
	}

	public static function add(list:Array<Int>, stat:Int, amount:Int):Void {
		var have = counts(list)[stat];
		for (_ in 0...amount) {
			if (list.length >= MAX_TOTAL || have >= MAX_STAT)
				return;
			list.push(stat);
			have++;
		}
	}

	public static function remove(list:Array<Int>, stat:Int, amount:Int):Void {
		var left = amount;
		var i = list.length - 1;
		while (i >= 0 && left > 0) {
			if (list[i] == stat) {
				list.splice(i, 1);
				left--;
			}
			i--;
		}
	}

	/**
	 * Stat totals to send. Points already spent (by hand or earlier) cover the plan's first entries
	 * of each stat; available points then fill the next uncovered entries in plan order. Never lowers
	 * a stat (that needs a paid Retrain).
	 */
	public static function target(list:Array<Int>, current:Array<Int>, earned:Int):Array<Int> {
		var result = current.copy();
		var covered = current.copy();
		var spent = current[0] + current[1] + current[2] + current[3];
		var available = earned - spent;
		for (s in list) {
			if (available <= 0)
				break;
			if (covered[s] > 0) {
				covered[s]--;
				continue;
			}
			if (result[s] >= MAX_STAT)
				continue;
			result[s]++;
			available--;
		}
		return result;
	}

	public static function encode(list:Array<Int>):String
		return list.join("");

	public static function decode(text:String):Array<Int> {
		var result:Array<Int> = [];
		if (text == null)
			return result;
		for (i in 0...text.length) {
			var s = text.charCodeAt(i) - 48;
			if (s < 0 || s > 3)
				throw "Invalid stat plan";
			result.push(s);
		}
		if (result.length > MAX_TOTAL)
			throw "Stat plan too long";
		for (c in counts(result))
			if (c > MAX_STAT)
				throw "Stat plan over the stat limit";
		return result;
	}
}
