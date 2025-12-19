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

        
        // Draw battery percent at top center
        drawBatteryPercent(dc, centerX, 40);

        // Draw weather widget on the left
        drawWeatherWidget(dc, centerX, centerY);

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
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, 5);

    }

    // Draw the clock dial with hour markers
    function drawClockDial(dc as Dc, centerX as Number, centerY as Number, radius as Number) as Void {
        // Draw minute markers as circles
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        for (var i = 0; i < 60; i++) {
            if (i % 5 != 0) {  // Skip positions where hours are
                var angle = (i * 6 - 90) * Math.PI / 180.0;
                var outerX = centerX + (radius * Math.cos(angle)).toNumber();
                var outerY = centerY + (radius * Math.sin(angle)).toNumber();
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
            var innerRadius = radius - 15;
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

            // Debug: log conditions properties to console
            System.println("DEBUG: Weather.getCurrentConditions() available properties:");
            System.println("  temperature: " + conditions.temperature);
            System.println("  condition: " + conditions.condition);
            System.println("  hiTemp: " + conditions.highTemperature);
            System.println("  lowTemp: " + conditions.lowTemperature);
            System.println("  feelsLike: " + conditions.feelsLikeTemperature);
            System.println("  humidity: " + conditions.relativeHumidity);
            System.println("  windSpeed: " + conditions.windSpeed);
            System.println("  windBearing: " + conditions.windBearing);

            var forecast = Weather.getDailyForecast();
            if (forecast == null) { return; }

            // Debug: log conditions properties to console
            System.println("DEBUG: Weather.getDailyForecast available properties:");
            System.println("  forecast: " + forecast[1].toString);


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
                var indicatorX = centerX + radius * Math.cos(angleRad);
                var indicatorY = centerY + radius * Math.sin(angleRad);

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

        dc.setColor(0x00FF00, Graphics.COLOR_BLACK);

        // Hour angle: 30° per hour + 0.5° per minute
        var totalMinutes = (hours % 12) * 60 + minutes;
        var angle = (totalMinutes * 0.5 - 90) * Math.PI / 180.0;

        var handLength = (radius * 0.7).toNumber();
        var halfWidthBase = 6;     // base thickness / 2
        var halfWidthTip  = 3;     // taper toward tip

        // Direction vector
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        // Perpendicular vector
        var px = -sinA;
        var py =  cosA;

        // Tail extends in opposite direction
        var tailLength = handLength * 0.2;
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

        // Draw center bulge (pin attachment)
        dc.setColor(0x00FF00, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, 5);
    }


    // Draw the minute hand as a polygon (blunt, tapered) with tail and center bulge
    function drawMinuteHand(dc as Dc, centerX as Number, centerY as Number, minutes as Number, radius as Number) as Void {
        dc.setColor(0x00FF00, Graphics.COLOR_BLACK);  // Fluorescent green

        // Calculate minute hand angle (6 degrees per minute)
        var angle = (minutes * 6 - 90) * Math.PI / 180.0;

        var handLength = (radius * 0.9).toNumber();
        var halfWidthBase = 6;     // base thickness / 2
        var halfWidthTip  = 3;     // taper toward tip

        // Direction vector
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        // Perpendicular vector
        var px = -sinA;
        var py =  cosA;

        // Tail extends in opposite direction
        var tailLength = handLength * 0.2;
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

        // Draw center bulge (pin attachment)
        dc.setColor(0x00FF00, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, 5);
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
        var halfWidthBase = 1.5;   // base thickness / 2
        var halfWidthTip  = 0.75;  // taper toward tip

        // Direction vector
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        // Perpendicular vector
        var px = -sinA;
        var py =  cosA;

        // Tail extends in opposite direction
        var tailLength = handLength * 0.2;
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
            [tailX - (px * 1.5).toNumber(), tailY - (py * 1.5).toNumber()],

            // Tail left
            [tailX + (px * 1.5).toNumber(), tailY + (py * 1.5).toNumber()],

            // Base left (at center)
            [centerX + (px * halfWidthBase).toNumber(), centerY + (py * halfWidthBase).toNumber()]
        ];

        dc.fillPolygon(points);

        // Draw center bulge (pin attachment)
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, 5);
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
    function drawBatteryPercent(dc as Dc, centerX as Number, y as Number) as Void {
        var batteryPercent = System.getSystemStats().battery;
        var batteryString = batteryPercent.format("%.0f") + "%";
        
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(centerX, y, Graphics.FONT_XTINY, batteryString, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Draw weather widget on the left with current, high, low, and icon
    function drawWeatherWidget(dc as Dc, centerX as Number, centerY as Number) as Void {
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

        var x = centerX - 110;  // position to the left

        // Draw current temperature
        dc.setColor(getTemperatureColor(currentTemp.toNumber()), Graphics.COLOR_BLACK);
        dc.drawText(x, centerY - 45, Graphics.FONT_SMALL, currentTemp + "°", Graphics.TEXT_JUSTIFY_CENTER);
        
        // reset the text color
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

        // Draw high/low temperatures
        dc.drawText(x, centerY, Graphics.FONT_XTINY, highTemp + " / " + lowTemp, Graphics.TEXT_JUSTIFY_CENTER);
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


    

    // Helper to keep code clean
    function toRad(deg) {
        return deg * Math.PI / 180.0;
    }

    function drawActiveMinutesWidget(dc as Dc, cx as Number, cy as Number, radius as Number) as Void {
        // 1. Setup & Config
        // ENABLE ANTI-ALIASING: Critical for Venu 3
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var thickness = 14; // Increased slightly for the larger Venu 3 screen
        var outerR = radius - 25; // Push it closer to edge for modern look
        var midR = outerR - (thickness / 2.0);
        var capR = thickness / 2.0 - 1.5;
        
        // Angles
        var startDeg = -115.0; // Use float
        var totalSweep = 50.0; 
        
        // Gap size in degrees (cleaner than drawing a black line)
        var gapDeg = 1.5; 

        // 2. Data Fetching
        var activeDay = 120.0;
        var activeWeek = 455.0;
        var weekGoal = 900.0; 

        // var info = ActivityMonitor.getInfo();
        // if (info != null) {
        //     if (info.activeMinutesDay != null) { activeDay = info.activeMinutesDay.total.toFloat(); }
        //     if (info.activeMinutesWeek != null) { activeWeek = info.activeMinutesWeek.total.toFloat(); }
        //     if (info.activeMinutesWeekGoal != null) { weekGoal = info.activeMinutesWeekGoal.toFloat(); }
        // }

        // Safety checks
        if (weekGoal < 1.0) { weekGoal = 150.0; }

        // 3. Logic Calculations
        var weekFrac = activeWeek / weekGoal;
        if (weekFrac > 1.0) { weekFrac = 1.0; }

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

        dc.setPenWidth(thickness);

        // ---------------------------------------------------------
        // DRAWING
        // ---------------------------------------------------------

        // A. Background (Gray)
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, midR, Graphics.ARC_COUNTER_CLOCKWISE, startDeg, startDeg + totalSweep);

        // NEW: Background End Cap (the far right side)
        var radBgEnd = Math.toRadians(startDeg + totalSweep);
        dc.fillCircle(cx + midR * Math.cos(radBgEnd), cy - midR * Math.sin(radBgEnd), capR);

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

            // End Cap (Bright Red)
            var radEnd = toRad(endDeg);
            dc.fillCircle(cx + midR * Math.cos(radEnd), cy - midR * Math.sin(radEnd), capR);

            // If the Week part was hidden (because day == week), we need a Start Cap in Bright Red
            if ((weekSweep - daySweep) <= gapDeg) {
                var radSplit = toRad(splitDeg); // Roughly the start
                dc.fillCircle(cx + midR * Math.cos(radSplit), cy - midR * Math.sin(radSplit), capR);
            }
        }
    }

    // // Helper: draw a thick ring arc (outer->inner) from startDeg clockwise sweepDeg degrees
    // function drawRingArc(dc as Dc, cx as Number, cy as Number, outerR as Number, innerR as Number, startDeg as Number, sweepDeg as Number, color as Number) as Void {
    //     if (sweepDeg <= 0) { return; }
        
    //     var thickness = outerR - innerR;
    //     var midRadius = innerR + (thickness / 2.0);
    //     var capRadius = thickness / 2.0;

    //     dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    //     dc.setPenWidth(thickness);

    //     // 1. Draw the main arc
    //     var endDeg = startDeg - sweepDeg;
    //     dc.drawArc(cx, cy, midRadius, Graphics.ARC_CLOCKWISE, startDeg, endDeg);

    //     // 2. Draw Round Caps
    //     // Convert start and end angles to radians for trigonometry
    //     // Note: We use -90 because Garmin 0 degrees is at 3 o'clock
    //     var startRad = Math.toRadians(startDeg);
    //     var endRad = Math.toRadians(endDeg);

    //     // Draw cap at the start
    //     var startX = cx + midRadius * Math.cos(startRad);
    //     var startY = cy - midRadius * Math.sin(startRad); // Subtract because Y increases downwards
    //     dc.fillCircle(startX, startY, capRadius);

    //     // Draw cap at the end
    //     var endX = cx + midRadius * Math.cos(endRad);
    //     var endY = cy - midRadius * Math.sin(endRad);
    //     dc.fillCircle(endX, endY, capRadius);
        
    //     dc.setPenWidth(1);
    // }

    
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
