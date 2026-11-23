package mods.ascension_helper;

import openfl.geom.Rectangle;

/**
 * Controller navigation for the mod's own controls, through the game's native navigation links:
 * each visible control is linked to its nearest neighbor in each direction by screen position.
 * Focus then uses each control's own hover look, so nothing changes visually.
 */
class Navigator {
	public static function link(objects:Array<Dynamic>):Void {
		var items:Array<{o:Dynamic, x:Float, y:Float}> = [];
		for (o in objects) {
			if (o == null)
				continue;
			var root:openfl.display.DisplayObject = cast Reflect.getProperty(o, "root");
			if (root == null || root.stage == null || !shown(root))
				continue;
			var r:Rectangle = root.getBounds(root.stage);
			items.push({o: o, x: r.x + r.width / 2, y: r.y + r.height / 2});
		}
		for (a in items) {
			a.o.clearLeftNavigation();
			a.o.clearRightNavigation();
			a.o.clearUpNavigation();
			a.o.clearDownNavigation();
		}
		var names = ["leftNavigation", "rightNavigation", "upNavigation", "downNavigation"];
		for (a in items) {
			for (dir in 0...4) {
				var best:Dynamic = null;
				var bestScore = 1e9;
				for (b in items) {
					if (b == a)
						continue;
					var dx = b.x - a.x;
					var dy = b.y - a.y;
					var along = dir == 0 ? -dx : dir == 1 ? dx : dir == 2 ? -dy : dy;
					var across = Math.abs(dir < 2 ? dy : dx);
					// Only targets ahead in that direction, preferring ones in line with this control.
					if (along <= 4 || across > along * 3 + 40)
						continue;
					var score = along + across * 2;
					if (score < bestScore) {
						bestScore = score;
						best = b.o;
					}
				}
				if (best != null)
					Reflect.setProperty(a.o, names[dir], best);
			}
		}
	}

	static function shown(node:openfl.display.DisplayObject):Bool {
		var current = node;
		while (current != null) {
			if (!current.visible)
				return false;
			current = current.parent;
		}
		return true;
	}
}
