package mods.ascension_helper;

import account.ItemInfo;
import facade.DBFacade;
import openfl.display.Sprite;
import openfl.display.MovieClip;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;

/** Retained tile strip. Modifier hover is native; clicks act on the owning weapon. */
class TileModifiers {
	public var key(default, null):String;
	public var root(default, null):Sprite;

	var icons:Array<ModifierIcon> = [];

	public static function signature(item:ItemInfo):String {
		if (item == null)
			return "";
		var value = Std.string(item.databaseId) + ":" + item.legendaryModifier;
		for (m in item.modifiers)
			if (m != null)
				value += ":" + m.Constant;
		return value;
	}

	public function new(facade:DBFacade, parent:Sprite, item:ItemInfo, bounds:Rectangle, select:String->Void, popups:Bool = true) {
		key = signature(item);
		root = new Sprite();
		parent.addChild(root);
		var entries:Array<{constant:String, legendary:UInt}> = [];
		for (m in item.modifiers)
			if (m != null)
				entries.push({constant: m.Constant, legendary: 0});
		if (item.legendaryModifier > 0)
			entries.push({constant: "", legendary: item.legendaryModifier});
		if (entries.length == 0)
			return;
		var gap = 2.;
		var size = Math.min(29, (bounds.width * 0.80 - gap * 2) / 3);
		var total = entries.length * size + gap * (entries.length - 1);
		root.x = bounds.x + bounds.width * 0.10;
		root.y = bounds.y + bounds.height - size - 6;
		var uid = Std.string(item.databaseId);
		for (i in 0...entries.length) {
			var holder = new MovieClip();
			root.addChild(holder);
			holder.x = i * (size + gap);
			holder.scaleX = holder.scaleY = size / 30;
			holder.buttonMode = true;
			holder.filters = [new openfl.filters.GlowFilter(0x1C1007, 1, 3, 3, 6, 1)];
			holder.graphics.beginFill(0, 0.01);
			holder.graphics.drawRect(0, 0, 30, 30);
			holder.graphics.endFill();
			holder.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) {
				e.stopImmediatePropagation();
			});
			holder.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
				e.stopImmediatePropagation();
				select(uid);
			});
			var entry = entries[i];
			icons.push(new ModifierIcon(facade, holder, entry.constant, entry.legendary, popups));
		}
	}

	public function dispose():Void {
		for (icon in icons)
			icon.destroy();
		icons = [];
		if (root.parent != null)
			root.parent.removeChild(root);
	}
}
