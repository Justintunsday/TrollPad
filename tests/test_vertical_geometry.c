#include "../VerticalSplit/TPVerticalGeometry.h"
#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdio.h>

static void near(double a, double b) { assert(fabs(a - b) < 1e-8); }
int main(void) {
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
    puts("PASS: 17560 pane pairs; viewport offsets, gap, clamping, invalid input, legacy guards, landscape fallback");
    return 0;
}
