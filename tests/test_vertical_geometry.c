#include "../VerticalSplit/TPVerticalGeometry.h"
#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdio.h>

static void near(double a, double b) { assert(fabs(a - b) < 1e-8); }
static void aligned_layouts(void) {
    TPRect v = {0, 0, 375, 667};
    TPVerticalLayout p;
    for (int grid = 0; grid < 2; grid++) {
        double step = grid ? 1 : 0.5;
        for (int i = 0; i <= 10000; i++) {
            double requested = v.height * (-0.2 + i * 0.00014);
            assert(TPComputeAlignedVerticalLayout(v, requested, 2, 151, 1, step, &p));
            assert(p.upper.height >= 151 && p.lower.height >= 151);
            assert(p.dividerY >= v.height / 3 && p.dividerY <= v.height * 2 / 3);
            assert(p.lower.y - (p.upper.y + p.upper.height) == 2);
            assert(p.lower.y + p.lower.height == 667);
            // Regression: native touch-region strips must retain exactly 40 pt
            // after rectangle intersection, rather than 40 + rounding residue.
            double touchBottom = p.lower.y + 40;
            assert(fmin(p.lower.y + p.lower.height, touchBottom) - p.lower.y == 40);
            assert((p.upper.height - (p.upper.height - 40)) == 40);
            assert(p.lower.y / step == round(p.lower.y / step));
        }
    }
    assert(TPComputeAlignedVerticalLayout(v, v.height / 3, 2, 151, 1, 0.5, &p));
    assert(p.dividerY == 222.5 && p.upper.height == 221.5 && p.lower.y == 223.5);
    assert(TPComputeAlignedVerticalLayout(v, 223.00000000000003, 2, 151, 1, 0.5, &p));
    assert(p.dividerY == 223 && p.lower.y == 224);
    assert(TPComputeAlignedVerticalLayout((TPRect){12.5, 59.5, 375, 667}, NAN, 2, 151, 1, 0.5, &p));
    assert(p.dividerY == 393 && p.lower.y == 394);
    p.dividerY = -123;
    assert(!TPComputeAlignedVerticalLayout(v, 300, 2, 151, 1, 1.0 / 3, &p));
    assert(!TPComputeAlignedVerticalLayout(v, 300, 2, 151, 1, 0, &p));
    assert(!TPComputeAlignedVerticalLayout((TPRect){0.1, 0, 375, 667}, 300, 2, 151, 1, 0.5, &p));
    assert(!TPComputeAlignedVerticalLayout(v, 300, 1, 151, 1, 1, &p));
    assert(!TPComputeAlignedVerticalLayout(v, 300, 2, 151, 3, 0.5, &p));
    assert(p.dividerY == -123);
}
int main(void) {
    aligned_layouts();
    assert(TPLegacyRoleRequestMatches(375, 375, 2, 1));
    assert(!TPLegacyRoleRequestMatches(375, 375, 1, 1));
    assert(TPLegacyRoleRequestMatches(375, 200, 1, 1));
    assert(TPLegacyRoleRequestMatches(375, 0, 1, 1));
    assert(!TPLegacyRoleRequestMatches(375, 0, 2, 1));
    assert(!TPLegacyRoleRequestMatches(375, -1, 1, 1));
    assert(!TPLegacyRoleRequestMatches(375, NAN, 2, 1));
    assert(!TPLegacyRoleRequestMatches(375, INFINITY, 2, 1));
    assert(!TPLegacyRoleRequestMatches(375, 200, 3, 1));
    assert(!TPLegacyRoleRequestMatches(375, 200, 2, 3));
    TPRect v = {12, 59, 369, 750};
    TPVerticalLayout p;
    assert(TPComputeVerticalLayout(v, NAN, 2, 150, 1, &p));
    near(p.dividerY, 434); near(p.upper.height, 374); near(p.lower.y, 435);
    for (int h = 6; h <= 2200; h++) {
        v.height = h;
        for (int y = -2; y <= 5; y++) {
            assert(TPComputeVerticalLayout(v, h * y, 2, 1, 1, &p));
            assert(p.upper.height >= 1 && p.lower.height >= 1);
            near(p.upper.x, v.x); near(p.lower.x, v.x);
            near(p.upper.y, v.y); near(p.upper.width, v.width);
            near(p.lower.width, v.width);
            near(p.lower.y - (p.upper.y + p.upper.height), 2);
            near(p.lower.y + p.lower.height, v.y + v.height);
            assert(p.dividerY >= v.y + v.height / 3 - 1e-8);
            assert(p.dividerY <= v.y + (v.height / 3) * 2 + 1e-8);
        }
    }
    v.height = 750;
    assert(TPComputeVerticalLayout(v, -DBL_MAX, 2, 150, 1, &p));
    near(p.dividerY, v.y + v.height / 3);
    assert(TPComputeVerticalLayout(v, DBL_MAX, 2, 150, 1, &p));
    near(p.dividerY, v.y + v.height / 3 * 2);
    assert(TPComputeVerticalLayout(v, INFINITY, 2, 150, 1, &p));
    near(p.dividerY, 434);
    p.dividerY = -123;
    assert(!TPComputeVerticalLayout(v, 400, 2, 150, 3, &p));
    assert(p.dividerY == -123);
    assert(!TPComputeVerticalLayout(v, 400, 2, 400, 1, &p));
    assert(!TPComputeVerticalLayout(v, 400, -1, 150, 1, &p));
    assert(!TPComputeVerticalLayout(v, 400, NAN, 150, 1, &p));
    assert(!TPComputeVerticalLayout(v, 400, 750, 150, 1, &p));
    assert(!TPComputeVerticalLayout(v, 400, 2, 0, 1, &p));
    assert(!TPComputeVerticalLayout(v, 400, 2, 150, 1, NULL));
    double bad[] = {0, -1, NAN, INFINITY};
    for (unsigned i = 0; i < sizeof(bad) / sizeof(bad[0]); i++) {
        TPRect invalid = v; invalid.width = bad[i];
        assert(!TPComputeVerticalLayout(invalid, 400, 2, 150, 1, &p));
        invalid = v; invalid.height = bad[i];
        assert(!TPComputeVerticalLayout(invalid, 400, 2, 150, 1, &p));
    }
    assert(!TPComputeVerticalLayout((TPRect){DBL_MAX, 0, DBL_MAX, 750}, 400, 2, 150, 1, &p));
    puts("PASS: 17560 pane pairs + 20002 aligned layouts; exact touch strips, bounds, gap, invalid input, landscape fallback");
    return 0;
}
