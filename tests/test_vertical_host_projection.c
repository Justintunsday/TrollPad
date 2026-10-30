#include "../VerticalSplit/TPVerticalGeometry.h"
#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdio.h>

static void near(double a, double b) { assert(fabs(a - b) < 1e-8); }

static void check_projection(TPRect viewport, TPRect bounds, double ratio) {
    TPVerticalLayout live;
    TPRect upper, lower;
    assert(TPComputeAlignedVerticalLayout(viewport, viewport.y + viewport.height * ratio,
                                         2, 151, 1, 0.5, &live));
    assert(TPProjectVerticalPane(viewport, bounds, live.upper, &upper));
    assert(TPProjectVerticalPane(viewport, bounds, live.lower, &lower));
    assert(upper.width > 0 && upper.height > 0 && lower.width > 0 && lower.height > 0);
    near(upper.x, bounds.x); near(lower.x, bounds.x);
    near(upper.y, bounds.y);
    near(upper.width, bounds.width); near(lower.width, bounds.width);
    near(lower.y + lower.height, bounds.y + bounds.height);
    near(lower.y - (upper.y + upper.height), 2 * bounds.height / viewport.height);
    near(upper.height / bounds.height, live.upper.height / viewport.height);
    near((lower.y - bounds.y) / bounds.height, (live.lower.y - viewport.y) / viewport.height);
}

int main(void) {
    TPRect viewport = {0, 0, 375, 667};
    TPVerticalLayout live;
    TPRect result;
    assert(TPComputeAlignedVerticalLayout(viewport, 333.5, 2, 151, 1, 0.5, &live));
    assert(TPProjectVerticalPane(viewport, viewport, live.lower, &result));
    assert(result.y == 334.5 && result.height == 332.5);

    // Regression: a switcher card is smaller than the live scene. The old
    // full-screen-size gate fell back to native horizontal panes here.
    check_projection(viewport, (TPRect){0, 0, 200, 356}, 0.5);
    // A short, wide host is valid; live-scene minimum heights still apply only
    // to the scene, and must not reject or clamp its animated thumbnail.
    check_projection(viewport, (TPRect){19, -12, 320, 100}, 1.0 / 3);
    check_projection((TPRect){12.5, 59.5, 375, 667}, (TPRect){-69, 20, 45, 80}, 2.0 / 3);

    // Sweep through the previous 0.5 pt gate in both directions. Normalized
    // pane geometry stays constant throughout translated, nonuniform scaling.
    for (int i = 0; i <= 2000; i++) {
        double scale = 0.05 + i * 0.000475;
        TPRect bounds = {-23 + 14 * scale, 47 - 39 * scale,
                         viewport.width * scale, viewport.height * scale};
        check_projection(viewport, bounds, 0.5);
        check_projection(viewport, bounds, 0.6);
    }
    check_projection(viewport, (TPRect){0, 0, 374.49, 666.49}, 0.5);
    check_projection(viewport, (TPRect){0, 0, 374.51, 666.51}, 0.5);
    check_projection(viewport, (TPRect){0, 0, 375.51, 667.51}, 0.5);

    // Full-size hosts retain exact aligned touch geometry, including a
    // translated origin, rather than gaining floating-point residue.
    assert(TPProjectVerticalPane(viewport, (TPRect){12.5, 59.5, 375, 667}, live.lower, &result));
    assert(result.y == 394 && result.height == 332.5);

    TPRect invalid[] = {
        {0, 0, 0, 356}, {0, 0, 200, -1}, {NAN, 0, 200, 356},
        {0, INFINITY, 200, 356}, {0, 0, INFINITY, 356},
        {DBL_MAX, 0, DBL_MAX, 356}, {0, DBL_MAX, 200, DBL_MAX}
    };
    for (unsigned i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
        result.y = -123;
        assert(!TPProjectVerticalPane(viewport, invalid[i], live.upper, &result));
        assert(result.y == -123);
        assert(!TPProjectVerticalPane(invalid[i], viewport, live.upper, &result));
        assert(result.y == -123);
    }
    TPRect invalidPanes[] = {
        {0, -1, 375, 332.5}, {0, 334.5, 375, 333}, {1, 0, 374, 332.5},
        {0, 0, 375, 0}, {0, 0, 375, NAN}
    };
    for (unsigned i = 0; i < sizeof(invalidPanes) / sizeof(invalidPanes[0]); i++) {
        result.y = -123;
        assert(!TPProjectVerticalPane(viewport, viewport, invalidPanes[i], &result));
        assert(result.y == -123);
    }
    assert(!TPProjectVerticalPane(viewport, viewport, live.upper, NULL));
    puts("PASS: vertical host projection; 4002 animated layouts, scaled gaps, exact endpoints, invalid input");
    return 0;
}
