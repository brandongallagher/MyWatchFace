import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

module ClockHandRendererStaticShading {

    // Draw the hour hand as a polygon (blunt, tapered) with tail and center bulge
    function drawHourHand(
        dc as Dc,
        centerX as Number,
        centerY as Number,
        hours as Number,
        minutes as Number,
        radius as Number
    ) as Void {

        dc.setColor(CustomColors.FLUORESCENT_GREEN, Graphics.COLOR_BLACK);

        // Hour angle: 30° per hour + 0.5° per minute
        var totalMinutes = (hours % 12) * 60 + minutes;
        var angle = (totalMinutes * 0.5 - 90) * Math.PI / 180.0;

        var handLength = (radius * 0.7).toNumber();
        var halfWidthBase = 7;     // base thickness / 2
        var halfWidthTip  = 3;     // taper toward tip

        // Direction vector
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        // Perpendicular vector
        var px = -sinA;
        var py =  cosA;

        // Tail extends in opposite direction
        var tailLength = handLength * 0.2;

        // DROP SHADOW (Optional but effective)
        // Draw the whole shape slightly offset in transparent black
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        var shadowOffset = 3;
        drawHalfHand(dc, centerX + shadowOffset, centerY + shadowOffset, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, true);
        drawHalfHand(dc, centerX + shadowOffset, centerY + shadowOffset, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, false);

        // 2. DRAW THE LIGHT SIDE (Top half)
        dc.setColor(CustomColors.FLUORESCENT_GREEN, Graphics.COLOR_TRANSPARENT); // A brighter "highlight" green
        drawHalfHand(dc, centerX, centerY, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, true);

        // 3. DRAW THE DARK SIDE (Bottom half)
        dc.setColor(CustomColors.FLUORESCENT_GREEN_SHADOW, Graphics.COLOR_TRANSPARENT);
        drawHalfHand(dc, centerX, centerY, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, false);

        // Draw center bulge (pin attachment)
        dc.setColor(CustomColors.FLUORESCENT_GREEN, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, 6);
    }


    function drawMinuteHand(dc as Dc, centerX as Number, centerY as Number, minutes as Number, radius as Number) as Void {
        
        var angle = (minutes * 6 - 90) * Math.PI / 180.0;
        var handLength = (radius * 0.9).toNumber();
        var tailLength = handLength * 0.2;
        var halfWidthBase = 7;
        var halfWidthTip  = 3;

        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);
        var px = -sinA;
        var py = cosA;

        // OLD
        // drawSimpleHand(dc, centerX, centerY, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, tailLength, handLength);

        // DROP SHADOW (Optional but effective)
        // Draw the whole shape slightly offset in transparent black
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        var shadowOffset = 3;
        drawHalfHand(dc, centerX + shadowOffset, centerY + shadowOffset, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, true);
        drawHalfHand(dc, centerX + shadowOffset, centerY + shadowOffset, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, false);

        // 2. DRAW THE LIGHT SIDE (Top half)
        dc.setColor(CustomColors.FLUORESCENT_GREEN, Graphics.COLOR_TRANSPARENT); // A brighter "highlight" green
        drawHalfHand(dc, centerX, centerY, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, true);

        // 3. DRAW THE DARK SIDE (Bottom half)
        dc.setColor(CustomColors.FLUORESCENT_GREEN_SHADOW, Graphics.COLOR_TRANSPARENT);
        drawHalfHand(dc, centerX, centerY, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, false);

        // 4. CENTER PIN (With a small highlight)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, 6);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, 2); // Tiny "hole" or pin head for realism
    }

    // Draw the second hand as a polygon (blunt, tapered) with tail and center bulge
    function drawSecondHand(dc as Dc, centerX as Number, centerY as Number, seconds as Number, radius as Number) as Void {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);

        // if there are any notifications, make the second hand purple
        var unreadNotifications = System.getDeviceSettings().notificationCount;
        if (unreadNotifications > 0) {
            dc.setColor(CustomColors.PURPLE, Graphics.COLOR_BLACK);
        }

        // Calculate second hand angle (6 degrees per second)
        var angle = (seconds * 6 - 90) * Math.PI / 180.0;

        var handLength = (radius * 0.95).toNumber();
        var halfWidthBase = 5;   // base thickness / 2
        var halfWidthTip  = 2.5;  // taper toward tip

        // Direction vector
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        // Perpendicular vector
        var px = -sinA;
        var py =  cosA;

        // Tail extends in opposite direction
        var tailLength = handLength * 0.2;

        // DROP SHADOW (Optional but effective)
        // Draw the whole shape slightly offset in transparent black
        dc.setColor(CustomColors.DROP_SHADOW, Graphics.COLOR_TRANSPARENT);
        var shadowOffset = 3;
        // drawHalfHand(dc, centerX + shadowOffset, centerY + shadowOffset, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, true);
        drawHalfHand(dc, centerX + shadowOffset, centerY + shadowOffset, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, false);

        // 2. DRAW THE LIGHT SIDE (Top half)
        dc.setColor(CustomColors.RED2, Graphics.COLOR_TRANSPARENT); // A brighter "highlight" green
        drawHalfHand(dc, centerX, centerY, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, true);

        // 3. DRAW THE DARK SIDE (Bottom half)
        dc.setColor(CustomColors.DARK_RED, Graphics.COLOR_TRANSPARENT);
        drawHalfHand(dc, centerX, centerY, cosA, sinA, px, py, handLength, tailLength, halfWidthBase, halfWidthTip, false);

        // Draw center bulge (pin attachment)
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, 4);
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

    function drawSimpleHand(dc, centerX, centerY, cosA, sinA, px, py, len, tail, halfWidthBase, halfWidthTip, tailLength, handLength) {
        var tailX = centerX - (tailLength * cosA).toNumber();
        var tailY = centerY - (tailLength * sinA).toNumber();

        // Tip of the hand
        var tipX = centerX + (handLength * cosA).toNumber();
        var tipY = centerY + (handLength * sinA).toNumber();

        // Polygon points (clockwise) - now includes tail
        var points = [
            // Tip left
            [tipX + (px * halfWidthTip).toNumber(), tipY + (py * halfWidthTip).toNumber()],

            // Tip right
            [tipX - (px * halfWidthTip).toNumber(), tipY - (py * halfWidthTip).toNumber()],

            // Base right (at center)
            [centerX - (px * halfWidthBase).toNumber(), centerY - (py * halfWidthBase).toNumber()],

            // Tail right
            [tailX - (px * 3).toNumber(), tailY - (py * 3).toNumber()],

            // Tail left
            [tailX + (px * 3).toNumber(), tailY + (py * 3).toNumber()],

            // Base left (at center)
            [centerX + (px * halfWidthBase).toNumber(), centerY + (py * halfWidthBase).toNumber()]
        ];

        dc.fillPolygon(points);
    }
}