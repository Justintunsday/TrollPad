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

// Historical iOS13/14 evidence only; these role IDs are NOT an iOS16 mapping.
int TPLegacyRoleRequestMatches(double screenWidth, double requestedWidth,
                               int role, int orientation);
#endif
