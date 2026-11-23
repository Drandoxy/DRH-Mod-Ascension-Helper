package mods.ascension_helper;

import openfl.display.MovieClip;
import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;
import openfl.filters.BitmapFilter;
import openfl.filters.GlowFilter;

/** One outlined hover/selection treatment for every inventory card and equipped slot. */
class CardStyle {
	var cell:uI.inventory.UIInventoryItem;
	var gear:uI.equipPicker.AvatarEquipElement;
	var inventory:uI.inventory.UIInventory;
	var selected:Void->Bool;
	var original:GlowFilter;
	var originalFilters:Array<BitmapFilter>;
	var root:MovieClip;

	public var outline(default, null):Sprite;
	public var active(default, null) = false;
	public var hovered(default, null) = false;

	/** Called on every click so the owner can refresh all cards together: one selection at a time. */
	public var onClick:Void->Void;

	/** Called when hover changes, so an equipped card can redraw its own frame at once. */
	public var onHover:Void->Void;

	var bounds:Rectangle;

	public function new(cell:uI.inventory.UIInventoryItem, gear:uI.equipPicker.AvatarEquipElement, inventory:uI.inventory.UIInventory, bounds:Rectangle,
			?selected:Void->Bool) {
		this.cell = cell;
		this.gear = gear;
		this.inventory = inventory;
		this.selected = selected;
		this.bounds = bounds;
		root = cell != null ? cell.root : gear.root;
		original = cell != null ? cell.rolloverFilter : gear.rolloverFilter;
		originalFilters = root.filters.copy();
		root.filters = [for (f in originalFilters) if (!Std.isOfType(f, GlowFilter)) f];
		if (cell != null)
			cell.rolloverFilter = null;
		else
			gear.rolloverFilter = null;
		outline = new Sprite();
		outline.name = "ascensionCardOutline";
		outline.mouseEnabled = false;
		outline.mouseChildren = false;
		root.addChild(outline);
		drawOutline(false);
		root.addEventListener(MouseEvent.CLICK, clicked, false, 1000);
		root.addEventListener("rollOver", over, false, -1000);
		root.addEventListener("rollOut", out, false, -1000);
		refresh();
	}

	function drawOutline(selectedLook:Bool):Void {
		outline.graphics.clear();
		outline.graphics.lineStyle(gear == null ? 3.5 : 2, 0xE0AB16);
		outline.graphics.drawRoundRect(bounds.x + 1, bounds.y + 1, gear == null ? bounds.width : bounds.width - 2, bounds.height - 2, gear == null ? 20 : 12,
			gear == null ? 20 : 12);
		outline.filters = [gear == null ? NativeUI.slotGlow() : new GlowFilter(0xE0AB16, 0.85, 5, 5, 2, 1)];
	}

	function clicked(_:MouseEvent):Void {
		refresh();
		if (onClick != null)
			onClick();
	}

	/** Controller focus: the same hover look as the mouse. */
	public function setHover(value:Bool):Void {
		hovered = value;
		refresh();
		if (onHover != null)
			onHover();
	}

	function over(_:MouseEvent):Void {
		hovered = true;
		refresh();
		if (onHover != null)
			onHover();
	}

	function out(_:MouseEvent):Void {
		hovered = false;
		refresh();
		if (onHover != null)
			onHover();
	}

	public function refresh():Void {
		if (selected != null)
			active = selected();
		else {
			var chosen:account.InventoryBaseInfo = cast Reflect.field(inventory, "mSelectedItemInfo");
			var info = cell != null ? cell.info : gear.itemInfo;
			active = chosen != null && chosen == info;
		}
		var effect:DisplayObject = cell != null ? cast Reflect.field(cell, "mSelectedEffect") : NativeUI.child(root, "selected");
		if (effect != null)
			effect.visible = false;
		// Equipped slots show hover and selection on their own frame (CardVisual), never this outline.
		outline.visible = gear == null && (active || hovered);
	}

	public function dispose():Void {
		root.removeEventListener(MouseEvent.CLICK, clicked);
		root.removeEventListener("rollOver", over);
		root.removeEventListener("rollOut", out);
		if (cell != null)
			cell.rolloverFilter = original;
		else
			gear.rolloverFilter = original;
		root.filters = originalFilters;
		var effect:DisplayObject = cell != null ? cast Reflect.field(cell, "mSelectedEffect") : NativeUI.child(root, "selected");
		if (effect != null)
			effect.visible = active;
		if (outline.parent != null)
			outline.parent.removeChild(outline);
	}
}
