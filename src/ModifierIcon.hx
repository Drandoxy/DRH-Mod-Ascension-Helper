package mods.ascension_helper;

import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import facade.DBFacade;
import facade.GameMasterLocale;
import gameMasterDictionary.GMModifier;
import gameMasterDictionary.GMLegendaryModifier;
import openfl.display.BitmapData;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import uI.modifiers.UIModifierTooltip;

/**
 * Loads only the modifier symbol. No rating template or star strip is created; the star count is
 * shown as a small black badge with a gold rim and number in the bottom-right corner.
 */
class ModifierIcon {
	var loader:AssetLoadingComponent;
	var holder:MovieClip;
	var tooltip:UIModifierTooltip;
	var disposed = false;
	var level:Int = 0;

	/** `popup` false: no modifier tooltip (equipped slots show only the weapon tooltip). */
	public function new(facade:DBFacade, holder:MovieClip, constant:String, legendary:UInt = 0, popup:Bool = true) {
		this.holder = holder;
		var name:String;
		var key:String;
		var prefix:String;
		if (legendary > 0) {
			var gmRaw:Dynamic = facade.gameMaster.legendaryModifiersById.itemFor(legendary);
			var gm:GMLegendaryModifier = Std.isOfType(gmRaw, GMLegendaryModifier) ? gmRaw : null;
			if (gm == null)
				return;
			name = gm.IconName;
			key = gm.Constant;
			prefix = "LEGENDARY_MODIFIER";
		} else {
			var gmRaw:Dynamic = facade.gameMaster.modifiersByConstant.itemFor(constant);
			var gm:GMModifier = Std.isOfType(gmRaw, GMModifier) ? gmRaw : null;
			if (gm == null)
				return;
			name = gm.IconName;
			key = gm.Constant;
			prefix = "MODIFIER";
			level = Std.int(gm.Level);
		}
		loader = new AssetLoadingComponent(facade);
		loader.getSwfAsset(DBFacade.buildFullDownloadPath("Resources/Art2D/Icons/Modifier/db_icons_modifier.swf"), function(asset:SwfAsset) {
			if (disposed)
				return;
			var art:MovieClip = cast asset.instantiateRuntimeSymbol(name, []);
			if (art == null)
				return;
			art.stop();
			holder.addChild(art);
			NativeUI.fit(art, new Rectangle(0.5, 0.5, 29, 29));
			if (level > 0)
				holder.addChild(levelBadge(level));
			if (!popup)
				return;
			tooltip = new UIModifierTooltip(facade, holder, asset, GameMasterLocale.getGameMasterSubString(prefix + "_NAME", key),
				GameMasterLocale.getGameMasterSubString(prefix + "_DESCRIPTION", key));
			tooltip.hide();
			holder.addEventListener(MouseEvent.MOUSE_OVER, over);
			holder.addEventListener(MouseEvent.MOUSE_OUT, out);
		});
	}

	/** Badge in the icon's 30x30 space: small rounded black box, thin gold rim, centered gold number. */
	public static function levelBadge(level:Int):Sprite {
		var size = 11.;
		var badge = new Sprite();
		badge.name = "modifier_level";
		badge.mouseEnabled = false;
		badge.mouseChildren = false;
		badge.x = 30 - size + 1;
		badge.y = 30 - size + 1;
		badge.graphics.lineStyle(0.6, 0xFFD23F);
		badge.graphics.beginFill(0x000000, 1);
		badge.graphics.drawRoundRect(0, 0, size, size, 7, 7);
		badge.graphics.endFill();
		var label = new TextField();
		label.selectable = false;
		label.mouseEnabled = false;
		var fontSize = 10;
		var format = new TextFormat("_sans", fontSize, 0xFFD23F, true);
		label.defaultTextFormat = format;
		label.text = Std.string(level);
		label.width = label.textWidth + 4;
		label.height = label.textHeight + 4;
		// Center the digit's drawn pixels, not the text field: the field has a 2px gutter and its
		// height includes space below the baseline. Font metrics are the fallback if drawing fails.
		var ink = inkBounds(label);
		if (ink != null) {
			label.x = (size - ink.width) / 2 - ink.x;
			label.y = (size - ink.height) / 2 - ink.y;
		} else {
			var metrics:Dynamic = label.getLineMetrics(0);
			var ascent:Float = metrics == null ? label.textHeight * 0.8 : metrics.ascent;
			label.x = (size - label.textWidth) / 2 - 2;
			label.y = (size + fontSize * 0.72) / 2 - ascent - 2;
		}
		badge.addChild(label);
		return badge;
	}

	/** Box of the label's visible pixels in its own coordinates, measured at 4x for sub-pixel precision. */
	static function inkBounds(label:TextField):Rectangle {
		try {
			var scale = 4;
			var data = new BitmapData(Math.ceil(label.width) * scale, Math.ceil(label.height) * scale, true, 0);
			var matrix = new Matrix();
			matrix.scale(scale, scale);
			data.draw(label, matrix);
			var drawn = data.getColorBoundsRect(0xFF000000, 0x00000000, false);
			data.dispose();
			if (drawn == null || drawn.width <= 0 || drawn.height <= 0)
				return null;
			return new Rectangle(drawn.x / scale, drawn.y / scale, drawn.width / scale, drawn.height / scale);
		} catch (error:Dynamic) {
			ErrorLog.report("Could not measure a modifier icon", error);
			return null;
		}
	}

	function over(_:MouseEvent):Void {
		if (tooltip != null)
			tooltip.show();
	}

	function out(_:MouseEvent):Void {
		if (tooltip != null)
			tooltip.hide();
	}

	public function destroy():Void {
		disposed = true;
		holder.removeEventListener(MouseEvent.MOUSE_OVER, over);
		holder.removeEventListener(MouseEvent.MOUSE_OUT, out);
		if (loader != null)
			loader.destroy();
		if (tooltip != null)
			tooltip.destroy();
		loader = null;
		tooltip = null;
		if (holder.parent != null)
			holder.parent.removeChild(holder);
	}
}
