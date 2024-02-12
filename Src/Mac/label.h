#include <Cocoa/Cocoa.h>
#include <Python.h>


@interface LabelView : WidgetView
{
}
- (BOOL)isFlipped;
- (void)drawRect:(NSRect)rect;
- (void)viewWillDraw;
@end
