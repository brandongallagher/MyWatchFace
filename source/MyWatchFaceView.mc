import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.System;
import Toybox.Weather;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;

class MyWatchFaceView extends WatchUi.WatchFace {

    var showFontSamples = false;  // Set to true to display font samples

    
    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ENABLE ANTI-ALIASING: Critical for Venu 3
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;
        var radius = (width < height ? width : height) / 2 - 10;

        // Draw clock dial
        drawClockDial(dc, centerX, centerY, radius);

        // Get the current time
        var clockTime = System.getClockTime();

        // Draw sunset indicator
        drawSunsetIndicator(dc, centerX, centerY, radius);

        // drawDate at top right
        drawDateStacked(dc, centerX + radius - 75, centerY - 75);
        
        // Draw battery percent at top center
        drawBatteryPercent(dc, centerX, 50);

        // Draw weather widget on the left
        drawWeatherWidget(dc, centerX - 105, centerY - 50);

        drawAltitudeOnDial(dc, centerX, centerY, radius);   
        drawAltitude(dc, centerX, centerY + 90);

        // Draw active minutes widget on the right
        drawActiveMinutesWidget(dc, centerX, centerY, radius);

        // Draw font samples if enabled
        if (showFontSamples) {
            drawFontSamples(dc, radius);
        }



        // do these last so they are on top of everything else

        // Draw clock hands
        drawHourHand(dc, centerX, centerY, clockTime.hour, clockTime.min, radius);
        drawMinuteHand(dc, centerX, centerY, clockTime.min, radius);
        drawSecondHand(dc, centerX, centerY, clockTime.sec, radius);

        // Draw center dot
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, 2);

    }

    // Draw the clock dial with hour markers
    function drawClockDial(dc as Dc, centerX as Number, centerY as Number, radius as Number) as Void {
        // Draw minute markers as circles
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        for (var i = 0; i < 60; i++) {
            if (i % 5 != 0) {  // Skip positions where hours are
                var dotRadius = radius - 5;
                var angle = (i * 6 - 90) * Math.PI / 180.0;
                var outerX = centerX + (dotRadius * Math.cos(angle)).toNumber();
                var outerY = centerY + (dotRadius * Math.sin(angle)).toNumber();
                dc.fillCircle(outerX, outerY, 2);  // Draw as circle with radius 2
            }
        }

        // Draw hour markers (hash marks) as rectangular polygons
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        for (var i = 0; i < 12; i++) {
            var angle = (i * 30 - 90) * Math.PI / 180.0;
            var cosA = Math.cos(angle);
            var sinA = Math.sin(angle);
            
            // Perpendicular vector for width (rotated 90 degrees)
            var perpX = -sinA;
            var perpY = cosA;
            
            // Radial vector (pointing outward)
            var radX = cosA;
            var radY = sinA;
            
            // Outer and inner radii
            var outerRadius = radius;
            var innerRadius = radius - 20;
            var halfWidth = 4;  // half-width of the mark
            
            // Calculate the four corners of the rectangle
            // Each corner = center + (radial * distance) + (perpendicular * offset)
            var p1X = centerX + (outerRadius * radX) + (halfWidth * perpX);
            var p1Y = centerY + (outerRadius * radY) + (halfWidth * perpY);
            
            var p2X = centerX + (outerRadius * radX) - (halfWidth * perpX);
            var p2Y = centerY + (outerRadius * radY) - (halfWidth * perpY);
            
            var p3X = centerX + (innerRadius * radX) - (halfWidth * perpX);
            var p3Y = centerY + (innerRadius * radY) - (halfWidth * perpY);
            
            var p4X = centerX + (innerRadius * radX) + (halfWidth * perpX);
            var p4Y = centerY + (innerRadius * radY) + (halfWidth * perpY);
            
            var points = [
                [p1X.toNumber(), p1Y.toNumber()],
                [p2X.toNumber(), p2Y.toNumber()],
                [p3X.toNumber(), p3Y.toNumber()],
                [p4X.toNumber(), p4Y.toNumber()]
            ];
            
            dc.fillPolygon(points);
        }

        // Draw hour digits (only 4 and 8)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        
        // get the hour of day 1-12
        var currentHour = System.getClockTime().hour % 12;
        if (currentHour == 0) {
            currentHour = 12;
        }
        
        for (var i = 1; i <= 12; i++) {
            if (i == 4 || i == 8) {
                // only show if the current time is near that hour
                if (i < currentHour + 1 && i > currentHour - 1) {
                    var angle = (i * 30 - 90) * Math.PI / 180.0;
                    var digitRadius = radius - 40;
                    var digitX = centerX + (digitRadius * Math.cos(angle)).toNumber();
                    var digitY = centerY + (digitRadius * Math.sin(angle)).toNumber();
                    dc.drawText(digitX, digitY, Graphics.FONT_GLANCE_NUMBER, i.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        }
    }

    // Draw sunset indicator as an orange dot at the 12-hour position corresponding to sunset time
    function drawSunsetIndicator(dc as Dc, centerX as Number, centerY as Number, radius as Number) as Void {
        try {
            var conditions = Weather.getCurrentConditions();
            if (conditions == null) { return; }


            var location = conditions.observationLocationPosition;
            var today = Time.now();
            var sunsetMoment = Weather.getSunset(location, today);

            if (sunsetMoment != null) {
                // Convert to hour/min
                var info = Gregorian.info(sunsetMoment, Time.FORMAT_SHORT);
                var sunsetHour = info.hour;
                var sunsetMinute = info.min;

                // Convert to angle for analog clock (top = 12 o'clock)
                var totalMinutes = (sunsetHour % 12) * 60 + sunsetMinute;
                var angleDegrees = totalMinutes * 0.5 - 90;  // 0 at top
                var angleRad = angleDegrees * Math.PI / 180.0;

                // Dot position on the dial edge
                var dotRadius = radius - 5;
                var indicatorX = centerX + dotRadius * Math.cos(angleRad);
                var indicatorY = centerY + dotRadius * Math.sin(angleRad);

                // Draw orange dot
                dc.setColor(CustomColors.BURNT_ORANGE, Graphics.COLOR_BLACK);
                dc.fillCircle(indicatorX, indicatorY, 8);  // 8px radius

                // // Draw text near the dot with sunset time
                // var timeStr = sunsetHour.format("%02d") + ":" + sunsetMinute.format("%02d");
                // dc.drawText(0, 50, Graphics.FONT_XTINY, timeStr, Graphics.TEXT_JUSTIFY_LEFT);

            }
        } catch (e) {   
            // Weather data not available
            System.println("DEBUG: Exception in drawSunsetIndicator: " + e.toString());
        }
    }

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

    // Helper to draw just one side of the polygon split down the middle
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

    // Called when this View is removed from the screen. Save the
    // the state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }

    // Draw battery percent at top center
    function drawBatteryPercent(dc as Dc, x as Number, y as Number) as Void {
        var batteryPercent = System.getSystemStats().battery;
        var batteryString = batteryPercent.format("%.0f") + "%";
        
        // set the color to indicate a low battery
        if (batteryPercent <= 12) {
            drawPillText(dc, x, y + 20, batteryString, Graphics.COLOR_WHITE, Graphics.COLOR_RED, Graphics.FONT_XTINY);
        } else if (batteryPercent <= 25) {
            drawPillText(dc, x, y + 20, batteryString, Graphics.COLOR_WHITE, Graphics.COLOR_YELLOW, Graphics.FONT_XTINY);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(x, y, Graphics.FONT_XTINY, batteryString, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Helper method to draw a pill-shaped background with centered text
    function drawPillText(dc, x, y, text, textColor, bgColor, font) {
        var paddingH = 14; // Horizontal padding (sides)
        var paddingV = 6;  // Vertical padding (top/bottom)

        // 1. Calculate dimensions based on text size
        var textWidth = dc.getTextWidthInPixels(text, font);
        var fontHeight = dc.getFontHeight(font);
        
        var pillWidth = textWidth + (paddingH * 2);
        var pillHeight = fontHeight + (paddingV * 2);
        var cornerRadius = pillHeight / 2;

        // 2. Draw the pill (Background)
        dc.setColor(bgColor, Graphics.COLOR_TRANSPARENT);
        // x and y represent the center of the pill
        dc.fillRoundedRectangle(
            x - (pillWidth / 2), 
            y - (pillHeight / 2), 
            pillWidth, 
            pillHeight, 
            cornerRadius
        );

        // 3. Draw the text (Foreground)
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x, 
            y, 
            font, 
            text, 
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function drawDate(dc as Dc, x as Number, y as Number) as Void {
        // Get the current time
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_MEDIUM);

        // Format the string: "Wed Dec 19"
        // info.day_of_week and info.month are strings because of FORMAT_MEDIUM
        var dateString = Lang.format("$1$ $2$ $3$", [
            info.day_of_week,
            info.month,
            info.day
        ]);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(x, y, Graphics.FONT_XTINY, dateString, Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawDateStacked(dc as Dc, x as Number, y as Number) as Void {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_MEDIUM);

        // Format the string: "Wed Dec 19"
        var dayOfWeekString = Lang.format("$1$", [info.day_of_week]);
        var dayOfMonthString = Lang.format("$1$", [info.day]);

        var dayOfWeekfont = Graphics.FONT_XTINY;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(x, y, Graphics.FONT_XTINY, dayOfWeekString, Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(x, y + dc.getFontHeight(dayOfWeekfont) + 6, Graphics.FONT_GLANCE_NUMBER, dayOfMonthString, Graphics.TEXT_JUSTIFY_VCENTER);
    }
    
    // Draw weather widget on the left with current, high, low, and icon
    function drawWeatherWidget(dc as Dc, x as Number, y as Number) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        var currentTemp = "--";
        var highTemp = "--";
        var lowTemp = "--";
        
        try {
            var conditions = Weather.getCurrentConditions();
            if (conditions != null) {
                if (conditions.temperature != null) {
                    currentTemp = celsiusToFahrenheit(conditions.temperature).format("%.0f");
                }
                if (conditions.highTemperature != null) {
                    highTemp = celsiusToFahrenheit(conditions.highTemperature).format("%.0f");
                }
                if (conditions.lowTemperature != null) {
                    lowTemp = celsiusToFahrenheit(conditions.lowTemperature).format("%.0f");
                }
            }
        } catch (e) {
            // Weather data not available
        }

        // var x = centerX - 110;  // position to the left

        // Draw current temperature
        dc.setColor(getTemperatureColor(currentTemp.toNumber()), Graphics.COLOR_BLACK);
        dc.drawText(x, y - 45, Graphics.FONT_SMALL, currentTemp, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x + 33, y - 45, Graphics.FONT_SMALL, "°", Graphics.TEXT_JUSTIFY_CENTER);
        
        // reset the text color
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

        // Draw high/low temperatures
        dc.drawText(x, y, Graphics.FONT_XTINY, highTemp + " - " + lowTemp, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function celsiusToFahrenheit(tempC as Number) as Number {
        return Math.round((tempC * 9.0 / 5.0) + 32.0);
    }

    function getTemperatureColor(tempF as Number) as Number {
        if (tempF <= 32) {
            return Graphics.COLOR_PURPLE;    // freezing
        } else if (tempF <= 45) {
            return Graphics.COLOR_DK_BLUE;
        } else if (tempF <= 60) {
            return Graphics.COLOR_BLUE;
        } else if (tempF <= 72) {
            return CustomColors.CYAN;      // comfortable
        } else if (tempF <= 85) {
            return Graphics.COLOR_YELLOW;
        } else if (tempF <= 95) {
            return Graphics.COLOR_ORANGE;
        } else {
            return Graphics.COLOR_RED;        // hot
        }
    }


    function drawAltitude(dc as Dc, x as Number, y as Number) as Void {
        // Get the current elevation
        var positionInfo = Position.getInfo();
        if (positionInfo has :altitude && positionInfo.altitude != null) {
            var altitude = metersToFeet(positionInfo.altitude);
            var altitudeString = altitude.format("%.0f") + "ft";
            System.println("Altitude: " + altitude);

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(x, y, Graphics.FONT_XTINY, altitudeString, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawAltitudeOnDial(dc as Dc, centerX as Number, centerY as Number, radius as Number) as Void {
        var positionInfo = Position.getInfo();
        if (!(positionInfo has :altitude && positionInfo.altitude != null)) {
            return;
        }
        
        // 1. Math Setup
        var altitude = metersToFeet(positionInfo.altitude);
        var totalMinutes = 5.0 * altitude / 1000;
        var angleDegrees = 360.0 * totalMinutes / 60 - 90;
        var angleRad = angleDegrees * Math.PI / 180.0;

        // 1. Define Shape Dimensions
        var bodyHeight = 8;   // Length of the square part
        var roofHeight = 7;   // Length of the triangle part
        var wedgeWidth = 14;  // Total width of the house
        var outerMargin = 2;  

        // Distances from center for the three layers of the house
        var distBase = radius - outerMargin;                // Back of the house
        var distShoulders = distBase - bodyHeight;          // Where roof meets walls
        var distTip = distShoulders - roofHeight;           // The peak pointing inward

        // 2. Angular width (spread)
        var halfWidthSpread = (wedgeWidth / 2.0) / distBase;

        // 3. Define the 5 Points of the "House"
        // Point 1: The Peak (Tip)
        var p1X = centerX + distTip * Math.cos(angleRad);
        var p1Y = centerY + distTip * Math.sin(angleRad);

        // Point 2: Left Shoulder (where roof meets wall)
        var p2X = centerX + distShoulders * Math.cos(angleRad - halfWidthSpread);
        var p2Y = centerY + distShoulders * Math.sin(angleRad - halfWidthSpread);

        // Point 3: Left Bottom Corner (outer edge)
        var p3X = centerX + distBase * Math.cos(angleRad - halfWidthSpread);
        var p3Y = centerY + distBase * Math.sin(angleRad - halfWidthSpread);

        // Point 4: Right Bottom Corner (outer edge)
        var p4X = centerX + distBase * Math.cos(angleRad + halfWidthSpread);
        var p4Y = centerY + distBase * Math.sin(angleRad + halfWidthSpread);

        // Point 5: Right Shoulder (where roof meets wall)
        var p5X = centerX + distShoulders * Math.cos(angleRad + halfWidthSpread);
        var p5Y = centerY + distShoulders * Math.sin(angleRad + halfWidthSpread);

        // 4. Draw the House
        dc.setColor(CustomColors.RED2, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [p1X, p1Y], // Peak
            [p2X, p2Y], // Left Shoulder
            [p3X, p3Y], // Left Base
            [p4X, p4Y], // Right Base
            [p5X, p5Y]  // Right Shoulder
        ]);
    }

    // Converts meters to feet with decimal precision
    function metersToFeet(meters as Float) as Float {
        if (meters == null) {
            return 0.0f;
        }
        return meters * 3.28084f;
    }
    

    // Helper to keep code clean
    function toRad(deg) {
        return deg * Math.PI / 180.0;
    }

    function drawActiveMinutesWidget(dc as Dc, cx as Number, cy as Number, radius as Number) as Void {
        
        var thickness = 14; // Increased slightly for the larger Venu 3 screen
        var outerR = radius - 35; 
        var midR = outerR - (thickness / 2.0);
        var capR = thickness / 2.0 - 1.5;
        
        // Angles
        var startDeg = -115.0; // Use float
        var totalSweep = 50.0; 
        
        // Gap size in degrees (cleaner than drawing a black line)
        var gapDeg = 0.5; 

        // 2. Data Fetching
        var activeDay = 120.0;
        var activeWeek = 455.0;
        var weekGoal = 900.0; 
        var exceededGoal = false;

        var info = ActivityMonitor.getInfo();
        if (info != null) {
            if (info.activeMinutesDay != null) { activeDay = info.activeMinutesDay.total.toFloat(); }
            if (info.activeMinutesWeek != null) { activeWeek = info.activeMinutesWeek.total.toFloat(); }
            if (info.activeMinutesWeekGoal != null) { weekGoal = info.activeMinutesWeekGoal.toFloat(); }
        }

        // Safety checks
        if (weekGoal < 1.0) { weekGoal = 150.0; }

        // 3. Logic Calculations
        var weekFrac = activeWeek / weekGoal;
        if (weekFrac > 1.0) { 
            weekFrac = 1.0;
            exceededGoal = true;
        }

        var dayFrac = activeDay / weekGoal;
        if (dayFrac > 1.0) { dayFrac = 1.0; }
        
        // Prevent weekFrac from being smaller than dayFrac (data sync glitch protection)
        if (weekFrac < dayFrac) { weekFrac = dayFrac; }

        var weekSweep = totalSweep * weekFrac;
        var daySweep = totalSweep * dayFrac;

        // Calculate the "Split" point where Dark Red meets Bright Red
        // We work backwards: The Bright Red is at the VERY END of the progress.
        var endDeg = startDeg + weekSweep;
        var splitDeg = endDeg - daySweep;

        // ---------------------------------------------------------
        // DRAWING
        // ---------------------------------------------------------

        // Thin pen for the gray background
        dc.setPenWidth(thickness/2);

        // A. Background (Gray)
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, midR, Graphics.ARC_COUNTER_CLOCKWISE, startDeg, startDeg + totalSweep);
        
        // Background Start Cap (the far left side)
        var radBgStart = Math.toRadians(startDeg);
        dc.fillCircle(cx + midR * Math.cos(radBgStart), cy - midR * Math.sin(radBgStart), capR/2);
        // Background End Cap (the far right side)
        var radBgEnd = Math.toRadians(startDeg + totalSweep);
        dc.fillCircle(cx + midR * Math.cos(radBgEnd), cy - midR * Math.sin(radBgEnd), capR/2);


        // wider pen for the active minutes ring
        dc.setPenWidth(thickness);
        
        // B. The Week Segment (Dark Red)
        // Draw only if we have enough week progress to separate from the day
        // We stop 'gapDeg' short of the split to create the clean divider
        if ((weekSweep - daySweep) > gapDeg) {
            dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
            // Draw from Start -> (Split - Gap)
            dc.drawArc(cx, cy, midR, Graphics.ARC_COUNTER_CLOCKWISE, startDeg, splitDeg - gapDeg);
            
            // Start Cap (Dark Red)
            var radStart = toRad(startDeg);
            dc.fillCircle(cx + midR * Math.cos(radStart), cy - midR * Math.sin(radStart), capR);
        }

        // C. The Day Segment (Bright Red)
        if (daySweep > 0) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            // Draw from Split -> End
            dc.drawArc(cx, cy, midR, Graphics.ARC_COUNTER_CLOCKWISE, splitDeg, endDeg);

            // End Cap
            var radEnd = toRad(endDeg);
            dc.fillCircle(cx + midR * Math.cos(radEnd), cy - midR * Math.sin(radEnd), capR * 1.75);

            // If the Week part was hidden (because day == week), we need a Start Cap in Bright Red
            if ((weekSweep - daySweep) <= gapDeg) {
                var radSplit = toRad(splitDeg); // Roughly the start
                dc.fillCircle(cx + midR * Math.cos(radSplit), cy - midR * Math.sin(radSplit), capR);
            }
        }

        // if goal exceeded, show a bigger circle at the end
        if (exceededGoal) {
            dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + midR * Math.cos(toRad(endDeg)), cy - midR * Math.sin(toRad(endDeg)), capR * 2.5);
            drawStar(dc, cx + midR * Math.cos(toRad(endDeg)), cy - midR * Math.sin(toRad(endDeg)), capR * 2.25, CustomColors.GOLD);
            
        }

    }

    function drawStar(dc, x, y, outerRadius, color) {
        var numPoints = 5;
        var points = new [numPoints * 2];
        var innerRadius = outerRadius * 0.4; // Adjust this to make it "pointier"
        var angleStep = Math.PI / numPoints; // 36 degrees per step
        
        // Start at the top (subtract 90 degrees or PI/2)
        var currentAngle = -Math.PI / 2.0;

        for (var i = 0; i < numPoints * 2; i++) {
            var r = (i % 2 == 0) ? outerRadius : innerRadius;
            
            var px = x + (Math.cos(currentAngle) * r);
            var py = y + (Math.sin(currentAngle) * r);
            
            points[i] = [px.toNumber(), py.toNumber()];
            currentAngle += angleStep;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(points);
    }

    
    // Draw font samples for testing
    function drawFontSamples(dc as Dc, radius as Number) as Void {
        var y = 20;
        var fonts = [
            [Graphics.FONT_XTINY, "FONT_XTINY"],
            [Graphics.FONT_TINY, "FONT_TINY"],
            [Graphics.FONT_SYSTEM_TINY, "FONT_SYSTEM_TINY"],
            [Graphics.FONT_GLANCE, "FONT_GLANCE"],
            [Graphics.FONT_GLANCE_NUMBER, "FONT_GLANCE_NUMBER"],
            // [Graphics.FONT_AUX1, "FONT_AUX1"],
            // [Graphics.FONT_AUX2, "FONT_AUX2"],
            // [Graphics.FONT_AUX3, "FONT_AUX3"],
            // [Graphics.FONT_AUX4, "FONT_AUX4"],
            // [Graphics.FONT_AUX5, "FONT_AUX5"],
            // [Graphics.FONT_AUX6, "FONT_AUX6"],
            [Graphics.FONT_NUMBER_MILD, "FONT_NUMBER_MILD"],
            // [Graphics.FONT_SYSTEM_NUMBER_THAI_HOT, "FONT_SYSTEM_NUMBER_THAI_HOT"],
            // [Graphics.FONT_NUMBER_HOT, "FONT_NUMBER_HOT"],
        ];

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        
        for (var i = 0; i < fonts.size(); i++) {
            dc.drawText(radius * 1, y, fonts[i][0], fonts[i][1], Graphics.TEXT_JUSTIFY_CENTER);
            y += 40;
        }
    }

}
