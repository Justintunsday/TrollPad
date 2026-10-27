#ifndef TP_VERTICAL_GEOMETRY_H
#define TP_VERTICAL_GEOMETRY_H

// Independent layout math in logical points. Does not activate or resize scenes.
typedef struct { double x, y, width, height; } TPRect;
typedef struct { TPRect upper, lower; double dividerY; } TPVerticalLayout;

// viewport must already be expressed in the scene host coordinate system,
// excluding whatever safe areas / keyboard space that host actually reserves.
// Portrait=1 only. Failure leaves output untouched. minimumPaneHeight > 0.
int TPComputeVerticalLayout(TPRect viewport, double requestedDividerY,
                            double gap, double minimumPaneHeight,
                            int orientation, TPVerticalLayout *output);

// Binary-exact point/half-point grid for native touch-region edge comparisons.
// step must be 1 or 0.5; viewport and half-gap must already be on that grid.
int TPComputeAlignedVerticalLayout(TPRect viewport, double requestedDividerY,
                                   double gap, double minimumPaneHeight,
                                   int orientation, double step, TPVerticalLayout *output);

// Project an already validated live-scene pane into the switcher's host bounds.
// Host bounds may be scaled, translated or landscape-shaped during animation.
// Keep live-scene alignment/minimum sizes in viewport; do not reapply them to
// a thumbnail. Failure leaves output untouched.
int TPProjectVerticalPane(TPRect viewport, TPRect bounds, TPRect pane, TPRect *output);

// Returns upper=1, lower=2, or 0 outside either pane (including the gap).
int TPVerticalRoleAtPoint(const TPVerticalLayout *layout, double x, double y);

// Fit a live pane's aspect ratio at the native snapshot width, retaining the
// native origin. Failure leaves output untouched.
int TPVerticalSnapshotFrame(TPRect pane, TPRect nativeFrame, TPRect *output);

// Historical iOS13/14 evidence only; these role IDs are NOT an iOS16 mapping.
int TPLegacyRoleRequestMatches(double screenWidth, double requestedWidth,
                               int role, int orientation);
#endif
