package mods.ascension_helper;

import brain.assetRepository.SwfAsset;
import brain.uI.UIButton;
import dBGlobals.DBGlobal;
import facade.DBFacade;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;

/** Native fonts and artwork with lightweight, consistently sized controls. */
class NativeUI {
	public var asset:SwfAsset;

	var facade:DBFacade;
	var fontName:String;
	var embedded = false;
	var swordAsset:SwfAsset;
	var swordLoader:brain.assetRepository.AssetLoadingComponent;
	var pendingSwords:Array<{host:Sprite, rect:Rectangle}> = [];
	var disposed = false;

	public function new(asset:SwfAsset, facade:DBFacade) {
		this.asset = asset;
		this.facade = facade;
		var original:TextField = null;
		try {
			var template = clip("avatar_tooltip");
			original = cast child(template, "level_star_label");
		} catch (_:Dynamic) {}
		fontName = original == null ? "_sans" : original.defaultTextFormat.font;
		embedded = original != null && original.embedFonts;
	}

	public static function child(parent:DisplayObjectContainer, name:String):DisplayObject {
		if (parent == null)
			return null;
		var value = parent.getChildByName(name);
		return value;
	}

	public static function clipChild(parent:DisplayObjectContainer, name:String):MovieClip
		return cast child(parent, name);

	public function clip(name:String):MovieClip {
		var value:MovieClip = cast asset.instantiateRuntimeSymbol(name, []);
		if (value == null)
			throw "Missing native UI asset: " + name;
		return value;
	}

	public static function fit(node:DisplayObject, rect:Rectangle):Void {
		node.scaleX = node.scaleY = 1;
		var b = node.getBounds(node);
		if (b.width <= 0 || b.height <= 0)
			return;
		var scale = Math.min(rect.width / b.width, rect.height / b.height);
		node.scaleX = node.scaleY = scale;
		node.x = rect.x + (rect.width - b.width * scale) / 2 - b.x * scale;
		node.y = rect.y + (rect.height - b.height * scale) / 2 - b.y * scale;
	}

	public static inline var BUTTON_CORNER = 22;

	/** The native Retrain button's yellow-orange colors (normal, then hover). */
	public static final RETRAIN_COLORS:Array<Array<Int>> = [[0xFFC21A, 0xFF8A00, 0xF26A00], [0xFFD24D, 0xFF9E2A, 0xF77E1A]];

	public function button(parent:DisplayObjectContainer, label:String, rect:Rectangle, callback:Void->Void, grey:Bool = false,
			?colors:Array<Array<Int>>):UIButton {
		var root = new MovieClip();
		root.x = rect.x;
		root.y = rect.y;
		parent.addChild(root);
		function paint(over:Bool):Void {
			var g = root.graphics;
			g.clear();
			var matrix = new openfl.geom.Matrix();
			matrix.createGradientBox(rect.width, rect.height, Math.PI / 2);
			g.lineStyle(3, 0x050800);
			var fill = colors != null ? colors[over ? 1 : 0] : grey ? [0x9A9A9A, 0x626262, 0x494949] : (over ? [0x29F511, 0x08B300, 0x177500] : [0x00DF00, 0x00A000,
				0x136600]);
			g.beginGradientFill(openfl.display.GradientType.LINEAR, fill, [1, 1, 1], [0, 105, 255], matrix);
			// One corner radius for every mod button, close to the game's own buttons (Retrain, Add Storage).
			g.drawRoundRect(0, 0, rect.width, rect.height, BUTTON_CORNER, BUTTON_CORNER);
			g.endFill();
		}
		paint(false);
		var field = new TextField();
		field.name = "caption";
		field.defaultTextFormat = new TextFormat(fontName, Math.min(18, rect.height * 0.54), 0xFFFFFF, true);
		field.embedFonts = embedded;
		field.mouseEnabled = false;
		field.selectable = false;
		field.filters = [new openfl.filters.GlowFilter(0x000000, 1, 2, 2, 8, 1)];
		root.addChild(field);
		var button = new UIButton(facade, root);
		button.label = field;
		button.releaseCallback = callback;
		// Geometry is independent from text and never inherits native timeline offsets.
		var marker = new MovieClip();
		marker.name = "buttonBounds";
		marker.mouseEnabled = false;
		marker.graphics.beginFill(0, 0);
		marker.graphics.drawRect(0, 0, rect.width, rect.height);
		marker.graphics.endFill();
		marker.width = rect.width;
		marker.height = rect.height;
		root.addChild(marker);
		root.addEventListener(openfl.events.MouseEvent.MOUSE_OVER, function(_) {
			paint(true);
			facade.menuNavigationController.setFocusedUiObject(button);
		});
		root.addEventListener(openfl.events.MouseEvent.MOUSE_OUT, function(_) {
			paint(false);
		});
		// Controller focus shows the same hover look as the mouse.
		button.navigationSelectedInteraction = function() paint(true);
		button.navigationSetToUnselectedInteraction = function() paint(false);
		caption(button, label);
		return button;
	}

	public static function caption(button:UIButton, value:String, ?size:Float):Void {
		var field = button.label;
		var geometry = button.root.getChildByName("buttonBounds");
		var width = geometry == null ? button.root.width : geometry.width;
		var height = geometry == null ? button.root.height : geometry.height;
		field.autoSize = "none";
		field.wordWrap = false;
		field.multiline = false;
		field.width = width - 12;
		field.height = height;
		var format = field.defaultTextFormat;
		format.align = "left";
		format.size = size != null ? size : Math.min(18, height * 0.54);
		field.defaultTextFormat = format;
		field.text = value.toUpperCase();
		field.setTextFormat(format);
		while (field.textWidth > width - 12 && cast(format.size, Float) > 8) {
			format.size = cast(format.size, Float) - 1;
			field.defaultTextFormat = format;
			field.setTextFormat(format);
		}
		field.autoSize = "none";
		field.width = field.textWidth + 6;
		field.height = field.textHeight + 4;
		field.x = (width - field.width) / 2;
		field.y = (height - field.height) / 2;
	}

	public function text(parent:DisplayObjectContainer, value:String, rect:Rectangle, color:Int = 0xFFFFFF):TextField {
		var label = new TextField();
		var format = new TextFormat(fontName, Math.max(10, Math.min(26, rect.height * 0.6)), color, true);
		format.align = "left";
		label.defaultTextFormat = format;
		label.embedFonts = embedded;
		label.mouseEnabled = false;
		label.selectable = false;
		label.text = value;
		label.width = rect.width;
		label.height = rect.height;
		while (label.textWidth > rect.width - 4 && cast(format.size, Float) > 8) {
			format.size = cast(format.size, Float) - 1;
			label.defaultTextFormat = format;
			label.setTextFormat(format);
		}
		label.autoSize = "none";
		label.width = label.textWidth + 6;
		label.height = label.textHeight + 4;
		label.x = rect.x + (rect.width - label.width) / 2;
		label.y = rect.y + (rect.height - label.height) / 2;
		parent.addChild(label);
		return label;
	}

	public function deleteButton(parent:DisplayObjectContainer, rect:Rectangle, callback:Void->Void):UIButton {
		var root = new MovieClip();
		root.x = rect.x;
		root.y = rect.y;
		parent.addChild(root);
		function paint(over:Bool):Void {
			var g = root.graphics;
			g.clear();
			g.lineStyle(2, 0x450303);
			g.beginFill(over ? 0xFF3636 : 0xD81717);
			g.drawRoundRect(0, 0, rect.width, rect.height, 6, 6);
			g.endFill();
			// Lucide X geometry: two clean diagonal strokes with generous padding.
			g.lineStyle(2.5, 0xFFFFFF);
			g.moveTo(rect.width * 0.3, rect.height * 0.3);
			g.lineTo(rect.width * 0.7, rect.height * 0.7);
			g.moveTo(rect.width * 0.7, rect.height * 0.3);
			g.lineTo(rect.width * 0.3, rect.height * 0.7);
		}
		paint(false);
		root.addEventListener(openfl.events.MouseEvent.MOUSE_OVER, function(_) {
			paint(true);
		});
		root.addEventListener(openfl.events.MouseEvent.MOUSE_OUT, function(_) {
			paint(false);
		});
		var button = new UIButton(facade, root);
		button.releaseCallback = callback;
		button.navigationSelectedInteraction = function() paint(true);
		button.navigationSetToUnselectedInteraction = function() paint(false);
		return button;
	}

	/** Uses the font of an existing native text field (for screens without the inventory art). */
	public function useFont(field:TextField):Void {
		if (field == null || field.defaultTextFormat.font == null)
			return;
		fontName = field.defaultTextFormat.font;
		embedded = field.embedFonts;
	}

	/** Gives controller focus to one of the mod's controls. */
	public function focus(target:Dynamic):Void {
		try {
			if (target != null)
				facade.menuNavigationController.setFocusedUiObject(target);
		} catch (_:Dynamic) {}
	}

	public static function setLevel(group:Sprite, value:String):Void {
		var label:TextField = cast group.getChildByName("level");
		var format = label.defaultTextFormat;
		format.align = "left";
		label.defaultTextFormat = format;
		label.text = value;
		label.setTextFormat(format);
		label.width = label.textWidth + 4;
		label.height = label.textHeight + 4;
		label.x = (48 - label.width) / 2;
		label.y = (48 - label.height) / 2;
	}

	public static function slotGlow():openfl.filters.GlowFilter
		return new openfl.filters.GlowFilter(0xE0AB16, 1, 11, 11, 4, 2);

	public function star(parent:DisplayObjectContainer):Sprite {
		var template = clip("avatar_tooltip");
		var star = child(template, "star");
		var level:TextField = cast child(template, "level_star_label");
		if (star == null || level == null)
			throw "Native level star is unavailable";
		var group = new Sprite();
		parent.addChild(group);
		group.addChild(star);
		if (Std.isOfType(star, MovieClip))
			cast(star, MovieClip).stop();
		fit(star, new Rectangle(0, 0, 48, 48));
		var number = new TextField();
		number.defaultTextFormat = new TextFormat(fontName, 16, 0xFFFFFF, true);
		var format = number.defaultTextFormat;
		format.align = "center";
		number.defaultTextFormat = format;
		number.embedFonts = embedded;
		number.autoSize = "none";
		number.width = 48;
		number.height = 24;
		number.y = 12;
		number.name = "level";
		number.text = "1";
		number.mouseEnabled = false;
		number.filters = [new openfl.filters.GlowFilter(0x000000, 1, 2, 2, 6, 1)];
		group.addChild(number);
		setLevel(group, "1");
		group.name = "ascensionLevel";
		group.mouseChildren = false;
		group.mouseEnabled = false;
		return group;
	}

	public function wood(parent:DisplayObjectContainer, rect:Rectangle):DisplayObject {
		var template = clip("DR_UI_town_inventory");
		var card = clipChild(template, "item_card");
		var art = child(card, "bg");
		if (art == null)
			throw "Native wooden background unavailable";
		parent.addChild(art);
		var b = art.getBounds(art);
		art.scaleX = rect.width / b.width;
		art.scaleY = rect.height / b.height;
		art.x = rect.x - b.x * art.scaleX;
		art.y = rect.y - b.y * art.scaleY;
		art.mouseEnabled = false;
		return art;
	}

	public function powerIcon(parent:DisplayObjectContainer, rect:Rectangle, value:String = ""):Void {
		var box = new Sprite();
		parent.addChild(box);
		box.x = rect.x;
		box.y = rect.y;
		box.graphics.lineStyle(2, 0x150400);
		box.graphics.beginFill(0x980800);
		box.graphics.drawRoundRect(0, 0, rect.width, rect.height, 7, 7);
		box.graphics.endFill();
		var number = text(box, value, new Rectangle(rect.width * 0.36, 0, rect.width * 0.61, rect.height), 0xFFFFFF);
		number.filters = [new openfl.filters.GlowFilter(0x000000, 1, 2, 2, 8, 1)];
		var target = new Rectangle(3, 2, rect.height - 4, rect.height - 4);
		if (swordAsset != null)
			drawSword(box, target);
		else {
			pendingSwords.push({host: box, rect: target});
			if (swordLoader == null) {
				swordLoader = new brain.assetRepository.AssetLoadingComponent(facade);
				swordLoader.getSwfAsset(DBFacade.buildFullDownloadPath("Resources/Art2D/UI/db_UI_cursors.swf"), function(asset:SwfAsset) {
					if (disposed)
						return;
					swordAsset = asset;
					for (pending in pendingSwords)
						if (pending.host.parent != null && pending.host.parent.parent != null)
							drawSword(pending.host, pending.rect);
					pendingSwords = [];
				});
			}
		}
	}

	function drawSword(host:Sprite, rect:Rectangle):Void {
		var art:MovieClip = cast swordAsset.instantiateRuntimeSymbol("cursor_sword", []);
		if (art == null)
			return;
		art.stop();
		host.addChild(art);
		fit(art, rect);
	}

	public function dispose():Void {
		disposed = true;
		pendingSwords = [];
		if (swordLoader != null)
			swordLoader.destroy();
		swordLoader = null;
		swordAsset = null;
	}

	public function ribbon(parent:DisplayObjectContainer, rect:Rectangle, title:String):Sprite {
		var popup = clip("chest_shop_popup");
		var art = child(popup, "ribbon");
		if (art == null)
			throw "Native ribbon unavailable";
		var group = new Sprite();
		parent.addChild(group);
		group.addChild(art);
		var b = art.getBounds(art);
		art.scaleX = rect.width / b.width;
		art.scaleY = rect.height / b.height;
		art.x = rect.x - b.x * art.scaleX;
		art.y = rect.y - b.y * art.scaleY;
		text(group, title, new Rectangle(rect.x + rect.width * 0.04, rect.y + rect.height * 0.14, rect.width * 0.92, rect.height * 0.8), 0xFFE330);
		group.mouseChildren = false;
		group.mouseEnabled = false;
		return group;
	}
}
