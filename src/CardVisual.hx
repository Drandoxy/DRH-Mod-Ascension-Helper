package mods.ascension_helper;

import account.ItemInfo;
import openfl.display.Sprite;
import openfl.display.MovieClip;
import openfl.geom.Rectangle;
import uI.inventory.UIInventory;
import uI.inventory.UIInventoryItem;

/** Shared card-space layout used by ordinary Storage and the Ascension planner. */
class CardVisual {
	public var host(default, null):Sprite;
	public var strip(default, null):TileModifiers;
	public var badge(default, null):Sprite;
	public var style(default, null):CardStyle;
	public var key(default, null):String;

	var owner:MovieClip;
	var nativeFrame:openfl.display.DisplayObject;
	var frameVisible = false;
	var graphic:openfl.display.DisplayObject;
	var oldMask:openfl.display.DisplayObject;
	var clip:Sprite;
	var baseFrame:Sprite;
	var frameBounds:Rectangle;
	var frameState:Int = -1;

	public static inline var FRAME_COLOR = 0xE0AB16;
	public static inline var SELECTED_COLOR = 0x4FE3FF;

	/**
	 * The weapon slot frame used by equipped cards and by the Ascension slots: an octagon with cut
	 * corners. State 0: gold and thin. 1 (hover): cyan and thin. 2 (selected): cyan and thicker.
	 */
	public static function drawSlotFrame(target:Sprite, b:Rectangle, state:Int):Void {
		var g = target.graphics;
		g.clear();
		var selected = state == 2;
		var color = state == 0 ? FRAME_COLOR : SELECTED_COLOR;
		var inset = selected ? 1. : 0.;
		var x = b.x + inset;
		var y = b.y + inset;
		var w = b.width - inset * 2;
		var h = b.height - inset * 2;
		var c = 6.;
		g.lineStyle(selected ? 3.5 : 1.5, color);
		g.moveTo(x + c, y);
		g.lineTo(x + w - c, y);
		g.lineTo(x + w, y + c);
		g.lineTo(x + w, y + h - c);
		g.lineTo(x + w - c, y + h);
		g.lineTo(x + c, y + h);
		g.lineTo(x, y + h - c);
		g.lineTo(x, y + c);
		g.lineTo(x + c, y);
		target.filters = [new openfl.filters.GlowFilter(color, selected ? 0.9 : 0.65, selected ? 5 : 3, selected ? 5 : 3, 2, 1)];
	}

	/** Octagon matching the frame, so the card art fills right up to its cut corners. */
	public static function fillOctagon(g:openfl.display.Graphics, b:Rectangle, inset:Float):Void {
		var x = b.x + inset;
		var y = b.y + inset;
		var w = b.width - inset * 2;
		var h = b.height - inset * 2;
		var c = 6.;
		g.moveTo(x + c, y);
		g.lineTo(x + w - c, y);
		g.lineTo(x + w, y + c);
		g.lineTo(x + w, y + h - c);
		g.lineTo(x + w - c, y + h);
		g.lineTo(x + c, y + h);
		g.lineTo(x, y + h - c);
		g.lineTo(x, y + c);
		g.lineTo(x + c, y);
	}

	/** Id of Weapon Modifiers in Inventory Preview, which draws its own levels and modifier icons on these cards. */
	public static inline var WEAPON_MODIFIERS_MOD = "weapon_modifiers_in_inventory_preview";

	/** Card key: the weapon, and whether this mod draws its levels and modifier icons. */
	public static function keyFor(item:account.InventoryBaseInfo, details:Bool):String {
		return signature(item) + (details ? "" : ":plain");
	}

	public static function signature(item:account.InventoryBaseInfo):String {
		if (item == null)
			return "";
		if (!Std.isOfType(item, ItemInfo))
			return "item:" + item.databaseId;
		var weapon:ItemInfo = cast item;
		return TileModifiers.signature(weapon) + ":" + weapon.requiredLevel;
	}

	public function new(ui:NativeUI, native:Native, cell:UIInventoryItem, gear:uI.equipPicker.AvatarEquipElement, inventory:UIInventory, select:String->Void,
			?selected:Void->Bool, details:Bool = true) {
		owner = cell != null ? cell.root : gear.root;
		var raw = cell != null ? cell.info : gear.itemInfo;
		key = keyFor(raw, details);
		var icon:MovieClip = cell != null ? cast Reflect.field(cell, "mIcon") : cast Reflect.field(gear, "mIcon");
		var bounds = StorageOverlays.iconBounds(icon, owner);
		if (gear != null) {
			var frame = NativeUI.child(owner, "frame");
			if (frame != null)
				bounds = frame.getBounds(owner);
		}
		if (gear != null) {
			nativeFrame = NativeUI.child(owner, "frame");
			if (nativeFrame != null) {
				frameVisible = nativeFrame.visible;
				nativeFrame.visible = false;
			}
			graphic = NativeUI.child(owner, "graphic");
			if (graphic != null) {
				oldMask = graphic.mask;
				clip = new Sprite();
				clip.mouseEnabled = false;
				clip.mouseChildren = false;
				owner.addChild(clip);
				clip.graphics.beginFill(0xFFFFFF);
				fillOctagon(clip.graphics, bounds, 1);
				clip.graphics.endFill();
				graphic.mask = clip;
			}
		}
		if (gear != null) {
			baseFrame = new Sprite();
			baseFrame.name = "ascensionEquippedFrame";
			baseFrame.mouseEnabled = false;
			owner.addChild(baseFrame);
			frameBounds = bounds;
		}
		style = new CardStyle(cell, gear, inventory, bounds, selected);
		style.onHover = redrawFrame;
		host = new Sprite();
		host.name = "ascensionWeaponDetails";
		owner.addChild(host);
		// While Weapon Modifiers in Inventory Preview runs, levels and modifier icons are left to it.
		if (details && Std.isOfType(raw, ItemInfo)) {
			var weapon:ItemInfo = cast raw;
			if (weapon.gmWeaponItem != null) {
				// Equipped slots show only the weapon tooltip; their modifier icons have no pop-up of their own.
				strip = new TileModifiers(native.facade(), host, weapon, bounds, select, gear == null);
				if (cell != null) {
					badge = ui.star(host);
					NativeUI.setLevel(badge, Std.string(weapon.requiredLevel));
					NativeUI.fit(badge,
						new Rectangle(bounds.x + bounds.width * 0.76, bounds.y + 0.5 - bounds.height * 0.44 * 0.45, bounds.width * 0.44, bounds.height * 0.44));
				}
			}
		}
		refresh();
	}

	public function refresh():Void {
		style.refresh();
		redrawFrame();
		if (baseFrame != null && baseFrame.parent == owner)
			owner.setChildIndex(baseFrame, owner.numChildren - 1);
		if (style.outline.parent == owner)
			owner.setChildIndex(style.outline, owner.numChildren - 1);
		for (name in ["number_label", "new_label"]) {
			var label = NativeUI.child(owner, name);
			if (label != null)
				owner.setChildIndex(label, owner.numChildren - 1);
		}
		if (host.parent == owner)
			owner.setChildIndex(host, owner.numChildren - 1);
		if (baseFrame != null) {
			var prompts:Array<openfl.display.DisplayObject> = [];
			for (i in 0...owner.numChildren) {
				var node = owner.getChildAt(i);
				if (node != baseFrame
					&& node != style.outline
					&& node != host
					&& node != clip
					&& ["frame", "graphic", "selected", "icon"].indexOf(node.name) < 0)
					prompts.push(node);
			}
			for (node in prompts)
				owner.setChildIndex(node, owner.numChildren - 1);
		}
	}

	/** The equipped card's own frame shows hover (cyan, thin) and selection (cyan, thicker). */
	function redrawFrame():Void {
		if (baseFrame == null)
			return;
		var state = style.active ? 2 : style.hovered ? 1 : 0;
		if (state == frameState)
			return;
		frameState = state;
		drawSlotFrame(baseFrame, frameBounds, state);
	}

	public function dispose():Void {
		safely(function() {
			if (baseFrame != null && baseFrame.parent != null)
				baseFrame.parent.removeChild(baseFrame);
		});
		safely(function() {
			if (nativeFrame != null)
				nativeFrame.visible = frameVisible;
		});
		safely(function() {
			if (graphic != null)
				graphic.mask = oldMask;
		});
		safely(function() {
			if (clip != null && clip.parent != null)
				clip.parent.removeChild(clip);
		});
		safely(function() {
			if (strip != null)
				strip.dispose();
		});
		safely(function() style.dispose());
		safely(function() {
			if (host.parent != null)
				host.parent.removeChild(host);
		});
	}

	static function safely(step:Void->Void):Void {
		try
			step()
		catch (error:Dynamic)
			ErrorLog.report("Could not restore part of an old card", error);
	}
}
