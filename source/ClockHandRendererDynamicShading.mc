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


    // Add these inside your existing module (e.g. ClockHandRenderer).
    // They are standalone and do not change your existing geometry or lighting math.

    class HandProfile {
        // all fields are public
        var highlightBoost;
        var shadowDarken;
        var highlightPow;
        var shadowPow;
        var highlightScale;
        var shadowScale;

        //! Constructor
        function initialize(hb, sd, hp, sp, hs, ss) {
            highlightBoost = hb;
            shadowDarken   = sd;
            highlightPow   = hp;
            shadowPow      = sp;
            highlightScale = hs;
            shadowScale    = ss;
        }
    }

    const HAND_PROFILES = [
        new HandProfile(0.36, 0.48, 0.85, 1.6, 0.95, 1.0), // HAND_HOUR
        new HandProfile(0.32, 0.46, 0.9, 1.6, 0.92, 1.0),   // HAND_MINUTE
        new HandProfile(0.12, 0.36, 1.15, 1.8, 0.55, 0.9)   // HAND_SECOND
    ];




    // Utility: clamp
    function _clamp(v, a, b) {
        return (v < a) ? a : ((v > b) ? b : v);
    }

    // Integer <-> RGB helpers (0..255)
    function _intToRgb(c) {
        var r = (c >> 16) & 0xFF;
        var g = (c >> 8) & 0xFF;
        var b = c & 0xFF;
        return [r, g, b];
    }
    function _rgbToInt(r, g, b) {
        r = _clamp(Math.round(r), 0, 255).toNumber();
        g = _clamp(Math.round(g), 0, 255).toNumber();
        b = _clamp(Math.round(b), 0, 255).toNumber();
        return ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
    }


    // RGB (0..255) -> HSL (h: 0..360, s: 0..1, l: 0..1)
    function _rgbToHsl(r, g, b) {
        var rn = r / 255.0;
        var gn = g / 255.0;
        var bn = b / 255.0;
        var maxc = _max(_max(rn, gn), bn);
        var minc = _min(_min(rn, gn), bn);
        var d = maxc - minc;
        var l = (maxc + minc) / 2.0;
        var s = 0.0;
        var h = 0.0;
        if (d != 0.0) {
            s = (l > 0.5) ? (d / (2.0 - maxc - minc)) : (d / (maxc + minc));
            var dr = (((maxc - rn) / 6.0) + (d / 2.0)) / d;
            var dg = (((maxc - gn) / 6.0) + (d / 2.0)) / d;
            var db = (((maxc - bn) / 6.0) + (d / 2.0)) / d;
            if (rn == maxc) {
                h = db - dg;
            } else if (gn == maxc) {
                h = (1.0 / 3.0) + dr - db;
            } else if (bn == maxc) {
                h = (2.0 / 3.0) + dg - dr;
            }
            if (h < 0.0) {
                h += 1.0;
            }
            if (h > 1.0) {
                h -= 1.0;
            }
            h = h * 360.0;
        }
        return [h, s, l];
    }

    // Returns the larger of two numbers
    function _max(a, b) {
        if (a > b) {
            return a;
        } else {
            return b;
        }
    }

    // Returns the smaller of two numbers
    function _min(a, b) {
        if (a < b) {
            return a;
        } else {
            return b;
        }
    }

    // HSL (h: 0..360, s:0..1, l:0..1) -> RGB (0..255)
    function _hslToRgb(h, s, l) {
        var r, g, b;
        var hh = _clamp(h / 360.0, 0.0, 1.0);
        if (s == 0.0) {
            r = l;
            g = l;
            b = l;
        } else {
            
            var q = (l < 0.5) ? (l * (1.0 + s)) : (l + s - l * s);
            var p = 2.0 * l - q;
            r = hue2rgb(p, q, hh + 1.0/3.0);
            g = hue2rgb(p, q, hh);
            b = hue2rgb(p, q, hh - 1.0/3.0);
        }
        return [Math.round(r * 255.0), Math.round(g * 255.0), Math.round(b * 255.0)];
    }

    function hue2rgb(p, q, t) {
                if (t < 0.0) {
                    t += 1.0;
                }
                if (t > 1.0) {
                    t -= 1.0;
                }
                if (t < (1.0/6.0)) {
                    return p + (q - p) * 6.0 * t;
                }
                if (t < 0.5) {
                    return q;
                }
                if (t < (2.0/3.0)) {
                    return p + (q - p) * ((2.0/3.0) - t) * 6.0;
                }
                return p;
            }


    class ColorVariants {
        var base;
        var shadow;
        var highlight;
        var baseHsl;
        var highlightL;
        var shadowL;

        function initialize(baseColorInt, shadowColorInt, highlightColorInt, baseHslArray, highlightLVal, shadowLVal) {
            base = baseColorInt;
            shadow = shadowColorInt;
            highlight = highlightColorInt;
            baseHsl = baseHslArray;
            highlightL = highlightLVal;
            shadowL = shadowLVal;
        }
    }

    // Derive highlight/shadow variants from baseColor (int 0xRRGGBB).
    // Preservation of hue/saturation is prioritized; we adjust only L (lightness).
    function deriveVariantsFromBase(baseColorInt, profile) {
        var rgb = _intToRgb(baseColorInt);
        var hsl = _rgbToHsl(rgb[0], rgb[1], rgb[2]);
        var h = hsl[0];
        var s = hsl[1];
        var l = hsl[2];

        var shadowL = _clamp(l * (1.0 - profile.shadowDarken), 0.02, 0.9);
        var highlightL = l + (1.0 - l) * profile.highlightBoost;
        highlightL = _clamp(highlightL, l, 1.0 - 0.001);

        var shadowRgb = _hslToRgb(h, s, shadowL);
        var highlightRgb = _hslToRgb(h, s, highlightL);

        return new ColorVariants(
            baseColorInt,
            _rgbToInt(shadowRgb[0], shadowRgb[1], shadowRgb[2]),
            _rgbToInt(highlightRgb[0], highlightRgb[1], highlightRgb[2]),
            [h, s, l],
            highlightL,
            shadowL
        );
    }


    // Mix two integer colors (0xRRGGBB) with t in [0..1]
    function _mixColorInt(aInt, bInt, t) {
        t = _clamp(t, 0.0, 1.0);
        var a = _intToRgb(aInt);
        var b = _intToRgb(bInt);
        var r = a[0] + (b[0] - a[0]) * t;
        var g = a[1] + (b[1] - a[1]) * t;
        var bch = a[2] + (b[2] - a[2]) * t;
        return _rgbToInt(r, g, bch);
    }

    // Main public helper: from base color + dot + hand type -> resulting color int
    function calculateHandColor(baseColorInt, dot, handType) {
        // dot expected in [-1..1] where >0 means lit side
        dot = _clamp(dot, -1.0, 1.0);

        var profile = HAND_PROFILES[handType];
        if (profile == null) {
            // fallback to minute profile if unknown
            profile = HAND_PROFILES[1];
        }

        var variants = deriveVariantsFromBase(baseColorInt, profile);

        // Asymmetric response:
        if (dot >= 0.0) {
            // lit side
            // compress highlight curve: raise to profile.highlightPow (pow <1 = gentle, >1 = sharper).
            var t = Math.pow(dot, profile.highlightPow);
            // apply highlight scale to reduce amplitude (e.g., second hand)
            t = t * profile.highlightScale;
            // mix base -> highlight
            return _mixColorInt(variants.base, variants.highlight, t);
        } else {
            // shadow side
            var sDot = -dot; // in (0..1]
            var t = Math.pow(sDot, profile.shadowPow);
            t = t * profile.shadowScale;
            // mix base -> shadow
            return _mixColorInt(variants.base, variants.shadow, t);
        }
    }


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
            centerInner,
            handType
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
        centerInnerRadius as Number,
        handType as Number
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
        // signed dot in [-1..1] (positive = original sign)
        var lightDotSigned = ld[3];
        // magnitude for amplitude-only uses
        var lightDotAbs = lightDotSigned.abs();

        // Compute lit and dark colors using the new helper with the signed dot.
        // Passing the signed dot directly avoids any boolean→sign reconstruction problems.
        var litColor = calculateHandColor(baseHighlightColor, lightDotSigned, handType);
        var darkSideColor = calculateHandColor(baseHighlightColor, -lightDotSigned, handType);

        // Optionally let caller-specified baseDarkColor influence the dark side slightly:
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
        var leftIsLit = (lightDot < 0);

        // shadow offset is away from the light (negative of light vector)
        var shadowX = -lightX * baseShadowOffset;
        var shadowY = -lightY * baseShadowOffset;

        return [leftIsLit, shadowX, shadowY, lightDot];
    }


    // ---------- Shading & color math (no alpha) ----------

    // /**
    //  * Compute a highlight and dark color from a base color and the lightDotAbs in [0..1].
    //  * Returns [highlightColor, darkColor] as opaque 0xRRGGBB integers.
    //  *
    //  * Strategy:
    //  *  - highlight: blend base color toward white; strength increases with lightDotAbs
    //  *  - dark: blend base color toward black; strength increases when facing away (1 - lightDotAbs)
    //  */
    // function computeShadingColors(baseColor as Number, lightDotAbs) as Array {
    //     // clamp just in case
    //     if (lightDotAbs < 0) { lightDotAbs = 0; }
    //     if (lightDotAbs > 1) { lightDotAbs = 1; }

    //     // highlight blend factor: minimal 0.15 up to 0.65
    //     var highlightT = 0.15 + (0.50 * lightDotAbs); // [0.15 .. 0.65]
    //     // dark side blend factor: minimal 0.25 up to 0.75 when facing away
    //     var darkT = 0.25 + (0.50 * (1.0 - lightDotAbs)); // [0.25 .. 0.75]

    //     // blended highlight toward white
    //     var highlight = blendColors(baseColor, CustomColors.WHITE, highlightT);
    //     // blended dark toward black
    //     var dark = blendColors(baseColor, CustomColors.BLACK, darkT);

    //     return [highlight, dark];
    // }

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
            [tipX.toNumber(), tipY.toNumber()], // The spine (tip)
            [(tipX + (px * wTip * side)).toNumber(), (tipY + (py * wTip * side)).toNumber()], // Outer edge tip
            [(cx + (px * wBase * side)).toNumber(), (cy + (py * wBase * side)).toNumber()],   // Outer edge base
            [(tailX + (px * 3 * side)).toNumber(), (tailY + (py * 3 * side)).toNumber()],     // Outer edge tail
            [tailX.toNumber(), tailY.toNumber()] // The spine (tail)
        ];
        dc.fillPolygon(points);
    }
    


}
