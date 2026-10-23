#include "TPVerticalGeometry.h"
#include <math.h>

static int positive(double x) { return isfinite(x) && x > 0; }

int TPLegacyRoleRequestMatches(double width, double request, int role, int orientation) {
    if (!positive(width) || !isfinite(request) || request < 0 || orientation != 1)
        return 0;
    return (role == 2 && request > 0) || (role == 1 && request < width);
}

int TPComputeVerticalLayout(TPRect v, double requested, double gap, double minimum,
                            int orientation, TPVerticalLayout *out) {
    if (!out || orientation != 1 || !isfinite(v.x) || !isfinite(v.y) ||
        !positive(v.width) || !positive(v.height) || !isfinite(gap) || gap < 0 ||
        !positive(minimum) || !isfinite(v.x + v.width) ||
        !isfinite(v.y + v.height) || gap >= v.height)
        return 0;
    double halfGap = gap / 2;
    double low = fmax(v.height / 3, minimum + halfGap);
    double high = fmin((v.height / 3) * 2, v.height - minimum - halfGap);
    if (!isfinite(low) || !isfinite(high) || low > high) return 0;
    double relative = isfinite(requested) ? requested - v.y : v.height / 2;
    relative = fmax(low, fmin(relative, high));
    double upperHeight = relative - halfGap;
    double lowerHeight = v.height - relative - halfGap;
    double lowerY = v.y + relative + halfGap;
    if (!positive(upperHeight) || !positive(lowerHeight) || !isfinite(lowerY)) return 0;
    *out = (TPVerticalLayout){
        {v.x, v.y, v.width, upperHeight},
        {v.x, lowerY, v.width, lowerHeight},
        v.y + relative
    };
    return 1;
}

static int on_grid(double value, double step) {
    double units = value / step;
    return isfinite(units) && units == round(units);
}

int TPComputeAlignedVerticalLayout(TPRect v, double requested, double gap, double minimum,
                                   int orientation, double step, TPVerticalLayout *out) {
    TPVerticalLayout continuous, aligned;
    if (!out || (step != 0.5 && step != 1) ||
        !TPComputeVerticalLayout(v, requested, gap, minimum, orientation, &continuous) ||
        !on_grid(v.x, step) || !on_grid(v.y, step) ||
        !on_grid(v.width, step) || !on_grid(v.height, step) || !on_grid(gap / 2, step)) return 0;
    double low = ceil((v.y + fmax(v.height / 3, minimum + gap / 2)) / step) * step;
    double high = floor((v.y + fmin(v.height / 3 * 2, v.height - minimum - gap / 2)) / step) * step;
    if (!isfinite(low) || !isfinite(high) || low > high) return 0;
    double divider = round(continuous.dividerY / step) * step;
    divider = fmax(low, fmin(divider, high));
    if (!TPComputeVerticalLayout(v, divider, gap, minimum, orientation, &aligned) ||
        !on_grid(aligned.upper.height, step) || !on_grid(aligned.lower.y, step) ||
        !on_grid(aligned.lower.height, step)) return 0;
    *out = aligned;
    return 1;
}
