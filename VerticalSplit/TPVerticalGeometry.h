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

// Historical iOS13/14 evidence only; these role IDs are NOT an iOS16 mapping.
int TPLegacyRoleRequestMatches(double screenWidth, double requestedWidth,
                               int role, int orientation);
#endif
