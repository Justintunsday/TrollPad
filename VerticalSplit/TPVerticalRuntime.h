#pragma once
#import <UIKit/UIKit.h>
#import "TPVerticalGeometry.h"

// Experimental layout. Read feature preferences at SpringBoard start.
void TPStartVerticalRuntime(void);
UIWindowScene *TPVerticalWindowScene(void);
BOOL TPCopyActiveVerticalLayout(TPVerticalLayout *layout);
BOOL TPResizeVerticalSplit(double ratio);
void TPStartVerticalDivider(void);
