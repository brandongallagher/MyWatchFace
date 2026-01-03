import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

module ClockHandRendererDynamicShading {

    const HAND_HOUR   = 0;
    const HAND_MINUTE = 1;
    const HAND_SECOND = 2;

    // Public: set this to change light position (clock hours, fractional allowed)
    var LIGHT_CLOCK_POS = 9;

    function setLightClockPosition(pos as Number) as Void {
        LIGHT_CLOCK_POS = pos;
    }

    // Dispatcher: choose per-hand geometry, colors and call shared drawHand
    function drawClockHandByType(
        dc as Dc,
        centerX as Number,
        centerY as Number,
        handType as Number,
        valuePrimary as Number,
        valueSecondary as Number,
        radius as Number
    ) as Void {

        var angle;
        var handLength = 0;
        var halfWidthBase = 0;
        var halfWidthTip = 0;
        var tailLength = 0;
        var shadowOffset = 3;

        var baseHighlightColor;
        var baseDarkColor;
        var shadowColor = 0x222222;
        var centerOuter = 0;
        var centerInner = 0;

        if (handType == HAND_HOUR) {
            var totalMinutes = (valuePrimary % 12) * 60 + valueSecondary;
            angle = (totalMinutes * 0.5 - 90) * Math.PI / 180.0;

            handLength = (radius * 0.7).toNumber();
            halfWidthBase = 7;
            halfWidthTip  = 3;
            tailLength = (handLength * 0.2).toNumber();

            baseHighlightColor = CustomColors.FLUORESCENT_GREEN;
            baseDarkColor      = CustomColors.FLUORESCENT_GREEN_SHADOW;

            centerOuter = 6;

        } else if (handType == HAND_MINUTE) {
            angle = (valuePrimary * 6 - 90) * Math.PI / 180.0;

            handLength = (radius * 0.9).toNumber();
            halfWidthBase = 7;
            halfWidthTip  = 3;
            tailLength = handLength * 0.2;

            baseHighlightColor = CustomColors.FLUORESCENT_GREEN;
            baseDarkColor      = CustomColors.FLUORESCENT_GREEN_SHADOW;

            centerOuter = 6;
            centerInner = 2;

        } else { // HAND_SECOND
            angle = (valuePrimary * 6 - 90) * Math.PI / 180.0;

            handLength = (radius * 0.95).toNumber();
            halfWidthBase = 5;
            halfWidthTip  = 2.5;
            tailLength = handLength * 0.2;

            var unread = System.getDeviceSettings().notificationCount;
            if (unread > 0) {
                baseHighlightColor = CustomColors.PURPLE;
                baseDarkColor      = CustomColors.DARK_PURPLE;
            } else {
                baseHighlightColor = Graphics.COLOR_RED;
                baseDarkColor      = CustomColors.DARK_RED;
            }

            shadowColor = CustomColors.DROP_SHADOW;
            centerOuter = 4;
        }

        drawHand(
            dc,
            centerX, centerY,
            angle,
            handLength,
            halfWidthBase,
            halfWidthTip,
            tailLength,
            shadowOffset,
            baseHighlightColor,
            baseDarkColor,
            shadowColor,
            centerOuter,
            centerInner
        );
    }


    // Generic hand renderer — uses computed shading colors (no setAlpha)
    function drawHand(
        dc as Dc,
        centerX as Number,
        centerY as Number,
        angle as Float,
        handLength as Number,
        halfWidthBase as Number,
        halfWidthTip as Number,
        tailLength as Number,
        baseShadowOffset as Number,
        baseHighlightColor as Number, // input base color (per-hand)
        baseDarkColor as Number,      // fallback base dark (can be ignored; we compute dark side)
        shadowColor as Number,
        centerOuterRadius as Number,
        centerInnerRadius as Number
    ) as Void {

        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);
        var px = -sinA;
        var py =  cosA;

        // Decide which side faces the light and shadow offset
        var ld = computeLightDecision(px, py, baseShadowOffset);
        var leftIsLit = ld[0];
        var shadowX = ld[1];
        var shadowY = ld[2];
        var lightDotAbs = ld[3];

        // Compute shading colors from the input base color and the lightDotAbs.
        // Returns [litColor, darkSideColor].
        var shading = computeShadingColors(baseHighlightColor, lightDotAbs);
        var litColor = shading[0];
        var darkSideColor = shading[1];

        // Optionally let caller-specified baseDarkColor influence the dark side slightly:
        // blend a small amount toward the provided dark variant if it's defined.
        if (baseDarkColor != null) {
            // blend 15% toward caller dark color
            darkSideColor = blendColors(darkSideColor, baseDarkColor, 0.15);
        }

        // Compute drop shadow color (ensure it's a subdued opaque color)
        var dropShadowColor = adjustColor(shadowColor, 1.0);
        // If shadowColor looks like full black, scale down a bit for subtlety
        if (shadowColor == 0x000000) {
            dropShadowColor = adjustColor(0x000000, 0.18);
        }

        // ---- Shadow silhouette (both halves), positioned away from light
        dc.setColor(dropShadowColor, Graphics.COLOR_TRANSPARENT);
        drawHalfHand(dc, centerX + shadowX, centerY + shadowY, cosA, sinA, px, py,
                    handLength, tailLength, halfWidthBase, halfWidthTip, true);
        drawHalfHand(dc, centerX + shadowX, centerY + shadowY, cosA, sinA, px, py,
                    handLength, tailLength, halfWidthBase, halfWidthTip, false);

        // ---- Lit side (computed highlight)
        dc.setColor(litColor, Graphics.COLOR_TRANSPARENT);
        drawHalfHand(dc, centerX, centerY, cosA, sinA, px, py,
                    handLength, tailLength, halfWidthBase, halfWidthTip, leftIsLit);

        // ---- Dark side
        dc.setColor(darkSideColor, Graphics.COLOR_TRANSPARENT);
        drawHalfHand(dc, centerX, centerY, cosA, sinA, px, py,
                    handLength, tailLength, halfWidthBase, halfWidthTip, !leftIsLit);

        // ---- Center pins (outer then inner)
        if (centerOuterRadius > 0) {
            dc.setColor(litColor, Graphics.COLOR_BLACK);
            dc.fillCircle(centerX, centerY, centerOuterRadius);
        }
        if (centerInnerRadius > 0) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, centerY, centerInnerRadius);
        }
    }


    // ---------- Light helpers ----------

    // Map clock position to unit vector pointing FROM CENTER TOWARD LIGHT
    function computeLightVectorFromClock(pos as Number) as Array {
        var hour = pos % 12;
        var angle = (hour / 12.0) * 2.0 * Math.PI - Math.PI / 2.0;
        var lx = Math.cos(angle);
        var ly = Math.sin(angle);
        var len = Math.sqrt(lx * lx + ly * ly);
        if (len > 0) {
            lx /= len;
            ly /= len;
        }
        return [lx, ly];
    }

    /**
     * Returns [leftIsLit, shadowX, shadowY, lightDotAbs]
     * - px,py: perpendicular pointing to left side of the hand
     * - baseShadowOffset: pixels of shadow distance
     */
    function computeLightDecision(px, py, baseShadowOffset) as Array {
        var lv = computeLightVectorFromClock(LIGHT_CLOCK_POS);
        var lightX = lv[0];
        var lightY = lv[1];

        var lightDot = (px * lightX) + (py * lightY);
        var leftIsLit = (lightDot > 0);

        // shadow offset is away from the light (negative of light vector)
        var shadowX = -lightX * baseShadowOffset;
        var shadowY = -lightY * baseShadowOffset;

        return [leftIsLit, shadowX, shadowY, lightDot.abs()];
    }


    // ---------- Shading & color math (no alpha) ----------

    /**
     * Compute a highlight and dark color from a base color and the lightDotAbs in [0..1].
     * Returns [highlightColor, darkColor] as opaque 0xRRGGBB integers.
     *
     * Strategy:
     *  - highlight: blend base color toward white; strength increases with lightDotAbs
     *  - dark: blend base color toward black; strength increases when facing away (1 - lightDotAbs)
     */
    function computeShadingColors(baseColor as Number, lightDotAbs) as Array {
        // clamp just in case
        if (lightDotAbs < 0) { lightDotAbs = 0; }
        if (lightDotAbs > 1) { lightDotAbs = 1; }

        // highlight blend factor: minimal 0.15 up to 0.65
        var highlightT = 0.15 + (0.50 * lightDotAbs); // [0.15 .. 0.65]
        // dark side blend factor: minimal 0.25 up to 0.75 when facing away
        var darkT = 0.25 + (0.50 * (1.0 - lightDotAbs)); // [0.25 .. 0.75]

        // blended highlight toward white
        var highlight = blendColors(baseColor, CustomColors.WHITE, highlightT);
        // blended dark toward black
        var dark = blendColors(baseColor, CustomColors.BLACK, darkT);

        return [highlight, dark];
    }

    // Blend c1 toward c2 by t (0..1) linearly per channel
    function blendColors(c1 as Number, c2 as Number, t as Float) as Number {
        if (t <= 0) { return c1; }
        if (t >= 1) { return c2; }

        var r1 = ((c1 >> 16) & 0xFF);
        var g1 = ((c1 >> 8)  & 0xFF);
        var b1 = ( c1        & 0xFF);

        var r2 = ((c2 >> 16) & 0xFF);
        var g2 = ((c2 >> 8)  & 0xFF);
        var b2 = ( c2        & 0xFF);

        var r = clamp((r1 + (r2 - r1) * t).toNumber(), 0, 255);
        var g = clamp((g1 + (g2 - g1) * t).toNumber(), 0, 255);
        var b = clamp((b1 + (b2 - b1) * t).toNumber(), 0, 255);

        return ((r << 16) | (g << 8) | b);
    }

    // Scale RGB channels by factor (factor >1 brightens, <1 darkens). Result clamped.
    function adjustColor(color as Number, factor as Float) as Number {
        var r = ((color >> 16) & 0xFF);
        var g = ((color >> 8)  & 0xFF);
        var b = ( color        & 0xFF);

        r = clamp((r * factor).toNumber(), 0, 255);
        g = clamp((g * factor).toNumber(), 0, 255);
        b = clamp((b * factor).toNumber(), 0, 255);

        return ((r << 16) | (g << 8) | b);
    }

    function clamp(value as Number, min as Number, max as Number) as Number {
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }


    // ---------- Polygon helper (unchanged shape) ----------
    function drawHalfHand(dc, cx, cy, cosA, sinA, px, py, len, tail, wBase, wTip, isLeft) {
        var side = isLeft ? 1 : -1;

        var tipX = cx + (len * cosA);
        var tipY = cy + (len * sinA);
        var tailX = cx - (tail * cosA);
        var tailY = cy - (tail * sinA);

        var points = [
            [tipX, tipY], // The spine (tip)
            [tipX + (px * wTip * side), tipY + (py * wTip * side)], // Outer edge tip
            [cx + (px * wBase * side), cy + (py * wBase * side)],   // Outer edge base
            [tailX + (px * 3 * side), tailY + (py * 3 * side)],     // Outer edge tail
            [tailX, tailY] // The spine (tail)
        ];
        dc.fillPolygon(points);
    }
    


}
