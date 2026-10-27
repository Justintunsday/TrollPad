#include "../VerticalSplit/TPVerticalGeometry.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    TPVerticalLayout layout;
    TPRect viewport={0,0,375,667}, snapshot;
    assert(TPComputeAlignedVerticalLayout(viewport,333.5,2,151,1,0.5,&layout));
    // Device regression: the lower pane must stay the target as x crosses the
    // native leading/trailing and Slide Over gutters.
    for(int x=0;x<375;x++) {
        assert(TPVerticalRoleAtPoint(&layout,x,278.5)==1);
        assert(TPVerticalRoleAtPoint(&layout,x,474)==2);
        assert(TPVerticalRoleAtPoint(&layout,x,333.5)==0);
    }
    assert(TPVerticalRoleAtPoint(&layout,106,474)==2);
    assert(TPVerticalRoleAtPoint(&layout,237,468)==2);
    assert(TPVerticalRoleAtPoint(&layout,0,0)==1);
    assert(TPVerticalRoleAtPoint(&layout,0,334.5)==2);
    assert(TPVerticalRoleAtPoint(&layout,375,474)==0);
    assert(TPVerticalRoleAtPoint(&layout,-1,474)==0);
    assert(TPVerticalRoleAtPoint(&layout,100,667)==0);
    assert(TPVerticalRoleAtPoint(&layout,NAN,100)==0);
    assert(TPVerticalRoleAtPoint(NULL,100,100)==0);

    assert(TPVerticalSnapshotFrame(layout.upper,(TPRect){-69,18,200,667},&snapshot));
    assert(snapshot.x==-69 && snapshot.y==18 && snapshot.width==200);
    assert(fabs(snapshot.height-200*332.5/375)<1e-8);
    assert(TPVerticalSnapshotFrame(layout.lower,viewport,&snapshot));
    assert(snapshot.height==332.5 && snapshot.y==0);
    snapshot.y=-123;
    assert(!TPVerticalSnapshotFrame(layout.upper,(TPRect){0,0,0,667},&snapshot));
    assert(snapshot.y==-123);
    assert(!TPVerticalSnapshotFrame((TPRect){0,0,375,NAN},viewport,&snapshot));
    assert(!TPVerticalSnapshotFrame(layout.upper,viewport,NULL));
    assert(TPComputeAlignedVerticalLayout((TPRect){12.5,59.5,375,667},393,2,151,1,0.5,&layout));
    assert(TPVerticalRoleAtPoint(&layout,100,60)==1);
    assert(TPVerticalRoleAtPoint(&layout,100,500)==2);
    assert(TPVerticalRoleAtPoint(&layout,100,393)==0);
    puts("PASS: vertical drop targets and snapshot aspect; device-point regressions, gap, translations, invalid input");
    return 0;
}
