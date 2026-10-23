/**
 * Advances a damped spring by dt from offset x0 (value minus target) and velocity v0; returns [x, v].
 */
function step(x0, v0, w, z, dt) {
    if (z < 1) {
        var wd = w * Math.sqrt(1 - z * z);
        var e = Math.exp(-z * w * dt);
        var c = Math.cos(wd * dt);
        var s = Math.sin(wd * dt);
        var b = (v0 + z * w * x0) / wd;
        return [e * (x0 * c + b * s), e * (c * (b * wd - z * w * x0) - s * (x0 * wd + z * w * b))];
    }
    if (z === 1) {
        var ec = Math.exp(-w * dt);
        var bc = v0 + w * x0;
        return [(x0 + bc * dt) * ec, (bc - w * (x0 + bc * dt)) * ec];
    }
    var r = Math.sqrt(z * z - 1);
    var r1 = -w * (z - r);
    var r2 = -w * (z + r);
    var c1 = (v0 - r2 * x0) / (r1 - r2);
    var c2 = x0 - c1;
    var e1 = Math.exp(r1 * dt);
    var e2 = Math.exp(r2 * dt);
    return [c1 * e1 + c2 * e2, c1 * r1 * e1 + c2 * r2 * e2];
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { step };
}
