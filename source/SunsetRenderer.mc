using Toybox.Graphics;

module SunsetRenderer {

    // x, y: center of the sphere
    // radius: size of the sphere
    function drawSunsetSphere(dc, x, y, radius) {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // --- SUNSET PALETTE ---
        // Shadow: Deep Burnt Red-Orange
        var rS = 0xAA; // 170
        var gS = 0x22; // 34
        var bS = 0x00; // 0

        // Highlight: Pale Yellow (Sunset Light)
        var rH = 0xFF; // 255
        var gH = 0xFF; // 255
        var bH = 0xAA; // 170

        var steps = 15; // More steps for a smoother "glow"
        
        for (var i = 0; i < steps; i++) {
            var ratio = i.toFloat() / (steps - 1);

            // 1. Interpolate Colors
            var r = (rS + (rH - rS) * ratio).toNumber();
            var g = (gS + (gH - gS) * ratio).toNumber();
            var b = (bS + (bH - bS) * ratio).toNumber();
            
            // Using 5.x createColor for better precision
            var currentColor = Graphics.createColor(255, r, g, b);

            // 2. Shrink radius for each layer
            var currentR = radius * (1.0 - (i.toFloat() / steps));

            // 3. Offset the highlight
            // To make it look like a sun, keep the offset subtle (0.2 instead of 0.4)
            var offsetMultiplier = radius * 0.4; 
            var curX = x - (ratio * offsetMultiplier);
            var curY = y - (ratio * offsetMultiplier);

            dc.setColor(currentColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(curX, curY, currentR);
        }
    }
}