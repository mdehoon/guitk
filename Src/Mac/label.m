#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"
#include "colors.h"
#include "image.h"
#include "text.h"
#include "font.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif

typedef enum {LEFT, CENTER, RIGHT} Alignment;

typedef enum {PY_ANCHOR_N,
              PY_ANCHOR_NE,
              PY_ANCHOR_E,
              PY_ANCHOR_SE,
              PY_ANCHOR_S,
              PY_ANCHOR_SW,
              PY_ANCHOR_W,
              PY_ANCHOR_NW,
              PY_ANCHOR_C} Anchor;

typedef enum {PY_COMPOUND_NONE,
              PY_COMPOUND_BOTTOM,
              PY_COMPOUND_TOP,
              PY_COMPOUND_LEFT,
              PY_COMPOUND_RIGHT,
              PY_COMPOUND_CENTER} Compound;

typedef enum {PY_RELIEF_RAISED,
              PY_RELIEF_SUNKEN,
              PY_RELIEF_FLAT,
              PY_RELIEF_RIDGE,
              PY_RELIEF_SOLID,
              PY_RELIEF_GROOVE} Relief;

typedef enum {NORMAL, ACTIVE, DISABLED} State;

typedef enum {PY_STICKY_N = 0x1,
              PY_STICKY_W = 0x2,
              PY_STICKY_S = 0x4,
              PY_STICKY_E = 0x8,
             } Sticky;

@interface LabelView : WidgetView
- (BOOL)isFlipped;
- (void)drawRect:(NSRect)rect;
@end

typedef struct {
    WidgetObject widget;
    ColorObject* foreground;
    ColorObject* background;
    ColorObject* active_background;
    ColorObject* active_foreground;
    ColorObject* disabled_foreground;
    ColorObject* highlight_background;
    ColorObject* highlight_color;
    double border_width;
    double height;
    double width;
    double highlight_thickness;
    Alignment alignment;
    Relief relief;
    Sticky sticky;
    double padx;
    double pady;
    Anchor anchor;
    Compound compound;
    ImageObject* image;
    State state;
    CFStringRef text;
    FontObject* font;
    Py_ssize_t underline;
    long wrap_length;
    bool take_focus;
    bool is_first_responder;
} LabelObject;


/* TkComputeAnchor */
static void
_compute_anchor(LabelObject* object, const CGSize outer, const CGSize inner,
                CGFloat* x, CGFloat* y)
{
    Anchor anchor = object->anchor;
    CGFloat padx = object->padx;
    CGFloat pady = object->pady;

    switch (anchor) {
    case PY_ANCHOR_NW:
    case PY_ANCHOR_W:
    case PY_ANCHOR_SW:
        *x = object->border_width + object->highlight_thickness + padx;
        break;

    case PY_ANCHOR_N:
    case PY_ANCHOR_C:
    case PY_ANCHOR_S:
        *x = (outer.width - inner.width) / 2;
        break;

    case PY_ANCHOR_NE:
    case PY_ANCHOR_E:
    case PY_ANCHOR_SE:
        *x = outer.width - inner.width - object->border_width - object->highlight_thickness - padx;
        break;
    default:
        /* raise an Exception */
        break;
    }
    switch (anchor) {
    case PY_ANCHOR_NW:
    case PY_ANCHOR_N:
    case PY_ANCHOR_NE:
        *y = object->border_width + object->highlight_thickness + pady;
        break;

    case PY_ANCHOR_W:
    case PY_ANCHOR_C:
    case PY_ANCHOR_E:
        *y = (outer.height - inner.height) / 2;
        break;

    case PY_ANCHOR_SW:
    case PY_ANCHOR_S:
    case PY_ANCHOR_SE:
        *y = outer.height - inner.height - object->border_width - object->highlight_thickness- pady;
        break;

    default:
        break;
    }
}

static void _get_dark_shadow(unsigned short* red, unsigned short* green, unsigned short *blue)
/* TkpGetShadows */
{
    const unsigned short r = *red;
    const unsigned short g = *green;
    const unsigned short b = *blue;
    if (r*0.5*r + g*1.0*g + b*0.28*b < USHRT_MAX*0.05*USHRT_MAX) {
        *red = (USHRT_MAX + 3*r)/4;
        *green = (USHRT_MAX + 3*g)/4;
        *blue = (USHRT_MAX + 3*b)/4;
    } else {
        *red = (60 * r)/100;
        *green = (60 * g)/100;
        *blue = (60 * b)/100;
    }
}

static void _get_light_shadow(unsigned short* red, unsigned short* green, unsigned short *blue)
/* TkpGetShadows */
{
    const unsigned short r = *red;
    const unsigned short g = *green;
    const unsigned short b = *blue;
    if (g > USHRT_MAX * 0.95) {
        *red = (90 * r)/100;
        *green = (90 * g)/100;
        *blue = (90 * b)/100;
    } else {
        int tmp1, tmp2;
        tmp1 = (14 * r)/10;
        if (tmp1 > USHRT_MAX) {
            tmp1 = USHRT_MAX;
        }
        tmp2 = (USHRT_MAX + r)/2;
        *red = (tmp1 > tmp2) ? tmp1 : tmp2;
        tmp1 = (14 * g)/10;
        if (tmp1 > USHRT_MAX) {
            tmp1 = USHRT_MAX;
        }
        tmp2 = (USHRT_MAX + g)/2;
        *green = (tmp1 > tmp2) ? tmp1 : tmp2;
        tmp1 = (14 * b)/10;
        if (tmp1 > USHRT_MAX) {
            tmp1 = USHRT_MAX;
        }
        tmp2 = (USHRT_MAX + b)/2;
        *blue = (tmp1 > tmp2) ? tmp1 : tmp2;
    }
}

/* Tk_3DVerticalBevel */
static void
_draw_3d_vertical_bevel(CGContextRef cr,
                        ColorObject* color,
                        CGFloat x, CGFloat y,
                        CGFloat width, CGFloat height,
                        bool left_bevel, Relief relief)
{
    unsigned short red = color->rgba[0];
    unsigned short green = color->rgba[1];
    unsigned short blue = color->rgba[2];
    unsigned short alpha = color->rgba[3];

    if (relief == PY_RELIEF_RAISED) {
        CGRect rect = CGRectMake(x, y, width, height);
        if (left_bevel) {
            _get_light_shadow(&red, &green, &blue);
        } else {
            _get_dark_shadow(&red, &green, &blue);
        }
        CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                     ((CGFloat)green)/USHRT_MAX,
                                     ((CGFloat)blue)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_SUNKEN) {
        CGRect rect = CGRectMake(x, y, width, height);
        if (left_bevel) {
            _get_dark_shadow(&red, &green, &blue);
        } else {
            _get_light_shadow(&red, &green, &blue);
        }
        CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                     ((CGFloat)green)/USHRT_MAX,
                                     ((CGFloat)blue)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_RIDGE) {
        unsigned short red_shadow;
        unsigned short green_shadow;
        unsigned short blue_shadow;
        CGRect rect;
        CGFloat half = width/2;
        if (!left_bevel && (width > 0.0)) half++;
        red_shadow = red;
        green_shadow = green;
        blue_shadow = blue;
        _get_light_shadow(&red_shadow, &green_shadow, &blue_shadow);
        rect.origin.x = x;
        rect.origin.y = y;
        rect.size.width = half;
        rect.size.height = height;
        CGContextSetRGBFillColor(cr, ((CGFloat)red_shadow)/USHRT_MAX,
                                     ((CGFloat)green_shadow)/USHRT_MAX,
                                     ((CGFloat)blue_shadow)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
        rect.origin.x = x + half;
        rect.size.width = width - half;
        red_shadow = red;
        green_shadow = green;
        blue_shadow = blue;
        _get_dark_shadow(&red_shadow, &green_shadow, &blue_shadow);
        CGContextSetRGBFillColor(cr, ((CGFloat)red_shadow)/USHRT_MAX,
                                     ((CGFloat)green_shadow)/USHRT_MAX,
                                     ((CGFloat)blue_shadow)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_GROOVE) {
        unsigned short red_shadow;
        unsigned short green_shadow;
        unsigned short blue_shadow;
        CGRect rect;
        CGFloat half = width/2;
        if (!left_bevel && (width > 0.0)) half++;
        red_shadow = red;
        green_shadow = green;
        blue_shadow = blue;
        _get_dark_shadow(&red_shadow, &green_shadow, &blue_shadow);
        rect.origin.x = x;
        rect.origin.y = y;
        rect.size.width = half;
        rect.size.height = height;
        CGContextSetRGBFillColor(cr, ((CGFloat)red_shadow)/USHRT_MAX,
                                     ((CGFloat)green_shadow)/USHRT_MAX,
                                     ((CGFloat)blue_shadow)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
        rect.origin.x = x + half;
        rect.size.width = width - half;
        red_shadow = red;
        green_shadow = green;
        blue_shadow = blue;
        _get_light_shadow(&red_shadow, &green_shadow, &blue_shadow);
        CGContextSetRGBFillColor(cr, ((CGFloat)red_shadow)/USHRT_MAX,
                                     ((CGFloat)green_shadow)/USHRT_MAX,
                                     ((CGFloat)blue_shadow)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_FLAT) {
        CGRect rect = CGRectMake(x, y, width, height);
        CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                     ((CGFloat)green)/USHRT_MAX,
                                     ((CGFloat)blue)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_SOLID) {
        CGRect rect = CGRectMake(x, y, width, height);
        CGContextSetRGBFillColor(cr, 0.0, 0.0, 0.0, 1.0);
        CGContextFillRect(cr, rect);
    }
}

/* Tk_3DHorizontalBevel */
static void
_draw_3d_horizontal_bevel(CGContextRef cr,
                          ColorObject* color,
                          CGFloat x, CGFloat y,
                          CGFloat width, CGFloat height,
                          bool left_in, bool right_in, bool top_bevel,
                          Relief relief)
{
    int bottom, halfway, x1, x2, x1Delta, x2Delta;

    unsigned short red = color->rgba[0];
    unsigned short green = color->rgba[1];
    unsigned short blue = color->rgba[2];
    unsigned short alpha = color->rgba[3];

    unsigned short red_top = red;
    unsigned short green_top = green;
    unsigned short blue_top = blue;

    unsigned short red_bottom = red;
    unsigned short green_bottom = green;
    unsigned short blue_bottom = blue;

    switch (relief) {
    case PY_RELIEF_FLAT:
        break;
    case PY_RELIEF_GROOVE:
        _get_dark_shadow(&red_top, &green_top, &blue_top);
        _get_light_shadow(&red_bottom, &green_bottom, &blue_bottom);
        break;
    case PY_RELIEF_RAISED:
        if (top_bevel) {
            _get_light_shadow(&red_top, &green_top, &blue_top);
            _get_light_shadow(&red_bottom, &green_bottom, &blue_bottom);
        } else {
            _get_dark_shadow(&red_top, &green_top, &blue_top);
            _get_dark_shadow(&red_bottom, &green_bottom, &blue_bottom);
        }
        break;
    case PY_RELIEF_RIDGE:
        _get_light_shadow(&red_top, &green_top, &blue_top);
        _get_dark_shadow(&red_bottom, &green_bottom, &blue_bottom);
        break;
    case PY_RELIEF_SOLID: {
        CGRect rect = CGRectMake(x, y, width, height);
        CGContextSetRGBFillColor(cr, 0.0, 0.0, 0.0, 1.0);
        CGContextFillRect(cr, rect);
        return;
    }
    case PY_RELIEF_SUNKEN:
        if (top_bevel) {
            _get_dark_shadow(&red_top, &green_top, &blue_top);
            _get_dark_shadow(&red_bottom, &green_bottom, &blue_bottom);
        } else {
            _get_light_shadow(&red_top, &green_top, &blue_top);
            _get_light_shadow(&red_bottom, &green_bottom, &blue_bottom);
        }
        break;
    }

    x1 = x;
    if (!left_in) {
        x1 += height;
    }
    x2 = x+width;
    if (!right_in) {
        x2 -= height;
    }
    x1Delta = (left_in) ? 1 : -1;
    x2Delta = (right_in) ? -1 : 1;
    halfway = y + height/2;
    if (!top_bevel && (height > 0)) {
        halfway++;
    }
    bottom = y + height;

    /* use CGContextDrawPath */
    for ( ; y < bottom; y++) {
        if (x1 < SHRT_MIN) {
            x1 = SHRT_MIN;
        }
        if (x2 > SHRT_MAX) {
            x2 = SHRT_MAX;
        }
        if (x1 < x2) {
            CGRect rect = CGRectMake(x1, y, x2 - x1, 1);
            if (y < halfway)
                CGContextSetRGBFillColor(cr, ((CGFloat)red_top)/USHRT_MAX,
                                             ((CGFloat)green_top)/USHRT_MAX,
                                             ((CGFloat)blue_top)/USHRT_MAX,
                                             ((CGFloat)alpha)/USHRT_MAX);
            else
                CGContextSetRGBFillColor(cr, ((CGFloat)red_bottom)/USHRT_MAX,
                                             ((CGFloat)green_bottom)/USHRT_MAX,
                                             ((CGFloat)blue_bottom)/USHRT_MAX,
                                             ((CGFloat)alpha)/USHRT_MAX);
            CGContextFillRect(cr, rect);
        }
        x1 += x1Delta;
        x2 += x2Delta;
    }
}

/* Tk_DrawFocusHighlight */
static void
_draw_focus_highlight(CGContextRef cr, ColorObject* color, CGRect rect, CGFloat width)
{
/*
    On X11: TkDrawInsetFocusHighlight(tkwin, gc, width, drawable, 0);
    On Max: TkMacOSXDrawSolidBorder
*/
    unsigned short red, green, blue, alpha;
    red = color->rgba[0];
    green = color->rgba[1];
    blue = color->rgba[2];
    alpha = color->rgba[3];
    CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                 ((CGFloat)green)/USHRT_MAX,
                                 ((CGFloat)blue)/USHRT_MAX,
                                 ((CGFloat)alpha)/USHRT_MAX);
    CGRect inner = CGRectInset(rect, width, width);
    CGContextBeginPath(cr);
    CGContextAddRect(cr, rect);
    CGContextAddRect(cr, inner);
    CGContextEOFillPath(cr);
}

@implementation LabelView
- (BOOL)becomeFirstResponder {
    ((LabelObject*)object)->is_first_responder = true;
    [self setNeedsDisplay:YES];
    return YES;
}

- (BOOL)resignFirstResponder {
    ((LabelObject*)object)->is_first_responder = false;
    [self setNeedsDisplay:YES];
    return YES;
}

- (BOOL)acceptsFirstResponder {
    LabelObject* label = (LabelObject*)object;
    if (label->take_focus) return YES;
    else return NO;
}

/* TkpDisplayButton */
- (void)drawRect:(NSRect)dirtyRect
{
    CFMutableAttributedStringRef string = NULL;
    CFDictionaryRef attributes = NULL;
    CGContextRef cr;
    NSGraphicsContext* gc;
    CGFloat x;
    CGFloat y;
    CGSize size;
    CGRect rect;
    CGPathRef path;
    CGFloat width = 0;
    CGFloat height = 0;
    CGFloat imageWidth;
    CGFloat imageHeight;
    CTFrameRef frame = NULL;
    CTFramesetterRef framesetter = NULL;
    CFRange fitRange;
    unsigned short red, green, blue, alpha;
    LabelObject* label = (LabelObject*)object;

fprintf(stderr, "In drawRect for %p\n", self);

    Sticky sticky = label->sticky;
    CFStringRef keys[] = { kCTFontAttributeName,
                           kCTForegroundColorFromContextAttributeName };
    CFTypeRef values[] = { label->font->font,
                           kCFBooleanTrue };
    const Relief relief = label->relief;
    CGImageRef image = NULL;

    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = [gc CGContext];
#else
    cr = (CGContextRef) [gc graphicsPort];
#endif
    switch (label->state) {
        case ACTIVE:
            red = label->active_background->rgba[0];
            green = label->active_background->rgba[1];
            blue = label->active_background->rgba[2];
            alpha = label->active_background->rgba[3];
            break;
        case NORMAL:
        case DISABLED:
            red = label->background->rgba[0];
            green = label->background->rgba[1];
            blue = label->background->rgba[2];
            alpha = label->background->rgba[3];
            break;
    }

CFShow(label->text);
fprintf(stderr, "minimum size is %f, %f\n", label->widget.minimum_size.width, label->widget.minimum_size.height);
    CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                 ((CGFloat)green)/USHRT_MAX,
                                 ((CGFloat)blue)/USHRT_MAX,
                                 ((CGFloat)alpha)/USHRT_MAX);
    rect = self.frame;
    if ((sticky & (PY_STICKY_W | PY_STICKY_E)) == (PY_STICKY_W | PY_STICKY_E)) {
        rect.origin.x = 0;
    }
    else if (sticky & PY_STICKY_W) {
        rect.origin.x = 0;
        rect.size.width = label->widget.minimum_size.width;
    }
    else if (sticky & PY_STICKY_E) {
        rect.origin.x = rect.size.width - label->widget.minimum_size.width;
        rect.size.width = label->widget.minimum_size.width;
    }
    else {
        rect.origin.x = 0.5 * (rect.size.width - label->widget.minimum_size.width);
        rect.size.width = label->widget.minimum_size.width;
    }
    if ((sticky & (PY_STICKY_N | PY_STICKY_S)) == (PY_STICKY_N | PY_STICKY_S)) {
        rect.origin.y = 0;
    }
    else if (sticky & PY_STICKY_N) {
        rect.origin.y = 0;
        rect.size.height = label->widget.minimum_size.height;
    }
    else if (sticky & PY_STICKY_S) {
        rect.origin.y = rect.size.height - label->widget.minimum_size.height;
        rect.size.height = label->widget.minimum_size.height;
    }
    else {
        rect.origin.y = 0.5 * (rect.size.height - label->widget.minimum_size.height);
        rect.size.height = label->widget.minimum_size.height;
    }

/*
    Tk_Fill3DRectangle(tkwin, pixmap, border, 0, 0, Tk_Width(tkwin),
            Tk_Height(tkwin), 0, TK_RELIEF_FLAT);
*/
    CGContextFillRect(cr, rect);
    /*
     * Display image or bitmap or text for button.
     */
    if (label->image) {
        image = label->image->data;
        width = CGImageGetWidth(image);
        height = CGImageGetHeight(image);
    }
    imageWidth = width;
    imageHeight = height;

    if (label->text) {
        CFRange range = CFRangeMake(0, CFStringGetLength(label->text));
        string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
        if (!string) return;
        CFAttributedStringReplaceString(string, CFRangeMake(0, 0), label->text);
        attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                        (const void**)&keys,
                                        (const void**)&values,
                                        2,
                                        &kCFTypeDictionaryKeyCallBacks,
                                        &kCFTypeDictionaryValueCallBacks);
        if (attributes) {
            Py_ssize_t underline = label->underline;
            CFAttributedStringSetAttributes(string, range, attributes, false);
            CFRelease(attributes);
            if (underline >= 0) {
                CTUnderlineStyle value = kCTUnderlineStyleSingle;
                CFNumberRef number = CFNumberCreate(kCFAllocatorDefault,
                                                    kCFNumberNSIntegerType,
                                                    &value);
                if (number) {
                    CFAttributedStringSetAttribute(string,
                                                   CFRangeMake(underline, 1),
                                                   kCTUnderlineStyleAttributeName,
                                                   number);
                    CFRelease(number);
                }
            }
            framesetter = CTFramesetterCreateWithAttributedString(string);
        }
        // Use CTLineRef line = CTLineCreateWithAttributedString(string); to
        // ensure that the string is not wrapped, and is written completely
        // (and then clipped manually).
        CFRelease(string);
        if (!framesetter) return;
        size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, range, NULL, self.bounds.size, &fitRange);

        width = self.frame.size.width;
        height = self.frame.size.height;
        path = CGPathCreateWithRect(CGRectMake(0, 0, rect.size.width, rect.size.height), NULL);
        if (path) {
            frame = CTFramesetterCreateFrame(framesetter, range, path, NULL);
            CFRelease(framesetter);
        }
        CFRelease(path);

        if (!frame) return;

        if (label->compound != PY_COMPOUND_NONE && label->image && label->text)
        {
            switch (label->compound) {
                case PY_COMPOUND_TOP:
                case PY_COMPOUND_BOTTOM:
  // FIXME calculate position if there is both text and image
            }
        }
/*
            TkComputeAnchor(butPtr->anchor, tkwin, butPtr->padX, butPtr->padY,
                    butPtr->indicatorSpace + butPtr->textWidth,
                    butPtr->textHeight, &x, &y);
*/
        x = rect.origin.x + 0.5 * rect.size.width - 0.5 * size.width;
        y = rect.origin.y + 0.5 * rect.size.height - 0.5 * size.height;
        _compute_anchor(label, rect.size, size, &x, &y);
fprintf(stderr, "HIER rect.size = %f, %f size = %f, %f x = %f y = %f\n", rect.size.width, rect.size.height, size.width, size.height, x, y);

        switch (label->state) {
            case NORMAL:
                red = label->foreground->rgba[0];
                green = label->foreground->rgba[1];
                blue = label->foreground->rgba[2];
                alpha = label->foreground->rgba[3];
                break;
            case ACTIVE:
                red = label->active_foreground->rgba[0];
                green = label->active_foreground->rgba[1];
                blue = label->active_foreground->rgba[2];
                alpha = label->active_foreground->rgba[3];
                break;
            case DISABLED:
                red = label->disabled_foreground->rgba[0];
                green = label->disabled_foreground->rgba[1];
                blue = label->disabled_foreground->rgba[2];
                alpha = label->disabled_foreground->rgba[3];
                break;
        }
        CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                     ((CGFloat)green)/USHRT_MAX,
                                     ((CGFloat)blue)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextSaveGState(cr);
        CGContextClipToRect(cr, self.bounds);
        CGContextTranslateCTM(cr, x + rect.origin.x, rect.size.height + y + rect.origin.y);
        CGContextScaleCTM(cr, 1.0, -1.0);
        CTFrameDraw(frame, cr);   // or CTLineDraw(line, cr);
        CGContextRestoreGState(cr);
        CFRelease(frame);
    }

    if (relief != PY_RELIEF_FLAT) {
        ColorObject* color;
        CGFloat inset = label->highlight_thickness;
        CGFloat border_width = label->border_width;
        x = rect.origin.x + inset;
        y = rect.origin.y + inset;
        width = rect.size.width - 2 * inset;
        height = rect.size.height - 2 * inset;
        switch (label->state) {
            case ACTIVE:
                color = label->active_background;
                break;
            case NORMAL:
            case DISABLED:
                color = label->background;
                break;
        }
/*
        Tk_Draw3DRectangle(tkwin, pixmap, border, inset, inset,
                Tk_Width(tkwin) - 2*inset, Tk_Height(tkwin) - 2*inset,
                butPtr->borderWidth, relief);
*/
        if (width < 2 * border_width) border_width = width / 2.0;
        if (height < 2 * border_width) border_width = height / 2.0;
        _draw_3d_vertical_bevel(cr, color, x, y, border_width, height, true, relief);
        _draw_3d_vertical_bevel(cr, color, x+width-border_width, y, border_width, height, false, relief);
        _draw_3d_horizontal_bevel(cr, color, x, y, width, border_width, true, true, true, relief);
        _draw_3d_horizontal_bevel(cr, color, x, y+height-border_width, width, border_width, false, false, false, relief);
    }
    if (label->highlight_thickness > 0) {
        Window* window = (Window*) [self window];
        ColorObject* color;
        if (window.object->is_key && label->is_first_responder) {
            color = label->highlight_color;
        }
        else {
            color = label->highlight_background;
        }
/*
            Tk_DrawFocusHighlight(tkwin, gc, butPtr->highlightWidth, pixmap);
*/
        _draw_focus_highlight(cr, color, rect, label->highlight_thickness);
    }
    if (image) {
        CGRect rect;
        rect.origin.x = 0;
        rect.origin.y = 0;
        rect.size.width = imageWidth;
        rect.size.height = imageHeight;
        CGContextDrawImage(cr, rect, image);
    }
fprintf(stderr, "Leaving drawRect for %p\n", self);
}

- (BOOL)isFlipped
{
    return YES;
}
@end

static PyObject*
Label_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    WidgetObject* widget;
    LabelObject *self = (LabelObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    widget = (WidgetObject*)self;
    widget->view = nil;
    widget->minimum_size = CGSizeZero;
    self->foreground = NULL;
    self->background = NULL;
    self->active_foreground = NULL;
    self->active_background = NULL;
    self->disabled_foreground = NULL;
    self->highlight_background = NULL;
    self->highlight_color = NULL;
    self->border_width = 1.0;
    self->highlight_thickness = 0.0;
    self->alignment = CENTER;
    self->padx = 1.0;
    self->pady = 1.0;
    self->relief = PY_RELIEF_FLAT;
    self->sticky = 0;
    self->state = NORMAL;
    self->take_focus = false;
    self->is_first_responder = false;
    self->underline = -1;
    self->width = 0.0;
    self->height = 0.0;
    self->text = NULL;
    self->font = NULL;
    self->anchor = PY_ANCHOR_C;
    self->image = NULL;
    self->compound = PY_COMPOUND_NONE;
    self->wrap_length = 0;
    // self->minimum_size = CGSizeZero;
    return (PyObject*)self;
}

static int
compound_converter(PyObject* argument, void* pointer)
{
    const char* value;
    Compound* compound = pointer;
    if (argument == NULL) return 1;
    if (!PyUnicode_Check(argument)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return 0;
    }
    value = PyUnicode_AsUTF8(argument);
    if (!value) return 0;
    if (PyOS_stricmp(value, "N")==0
     || PyOS_stricmp(value, "NONE")==0) *compound = PY_COMPOUND_NONE;
    else if (PyOS_stricmp(value, "B")==0
          || PyOS_stricmp(value, "BOTTOM")==0) *compound = PY_COMPOUND_BOTTOM;
    else if (PyOS_stricmp(value, "T")==0
          || PyOS_stricmp(value, "TOP")==0) *compound = PY_COMPOUND_TOP;
    else if (PyOS_stricmp(value, "B")==0
          || PyOS_stricmp(value, "BOTTOM")==0) *compound = PY_COMPOUND_BOTTOM;
    else if (PyOS_stricmp(value, "L")==0
          || PyOS_stricmp(value, "LEFT")==0) *compound = PY_COMPOUND_LEFT;
    else if (PyOS_stricmp(value, "R")==0
          || PyOS_stricmp(value, "RIGHT")==0) *compound = PY_COMPOUND_RIGHT;
    else if (PyOS_stricmp(value, "C")==0
          || PyOS_stricmp(value, "CENTER")==0) *compound = PY_COMPOUND_CENTER;
    else {
        PyErr_Format(PyExc_ValueError,
            "expected 'NONE', 'N', 'BOTTOM', 'B', 'TOP', 'T', "
            "'LEFT', 'L', 'RIGHT', 'R', 'CENTER', or 'C' "
            "(case-insensitive), got '%s'", value);
        return 0;
    }
    return Py_CLEANUP_SUPPORTED;
}


static int
Label_init(LabelObject *self, PyObject *args, PyObject *keywords)
{
    WidgetObject* widget;
    LabelView *label;
    CFStringRef text = NULL;
    NSRect rect;
    FontObject* font = default_font_object;
    ImageObject* image = NULL;
    Compound compound = PY_COMPOUND_NONE;

    static char* kwlist[] = {"text", "font", "image", "compound", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|O&O!O!O&", kwlist,
                                     string_converter, &text,
                                     &FontType, &font,
                                     &ImageType, &image,
                                     compound_converter, &compound))
        return -1;


/*
    TkWindow* parentPtr;
    TkDisplay *dispPtr = parentPtr->dispPtr;
    int screenNum = parentPtr->screenNum;

    if ((parentPtr != NULL) && (parentPtr->display == winPtr->display)
            && (parentPtr->screenNum == winPtr->screenNum)) {
        winPtr->visual = parentPtr->visual;
        winPtr->depth = parentPtr->depth;
    } else {
        winPtr->visual = DefaultVisual(dispPtr->display, screenNum);
        winPtr->depth = DefaultDepth(dispPtr->display, screenNum);
    }
    winPtr->window = None;
    winPtr->childList = NULL;
    winPtr->lastChildPtr = NULL;
    winPtr->parentPtr = NULL;
    winPtr->nextPtr = NULL;
    winPtr->mainPtr = NULL;
    winPtr->pathName = NULL;
    winPtr->nameUid = NULL;
    winPtr->classUid = NULL;
    winPtr->changes = defChanges;
    winPtr->dirtyChanges = CWX|CWY|CWWidth|CWHeight|CWBorderWidth;
    winPtr->atts = defAtts;
    if ((parentPtr != NULL) && (parentPtr->display == winPtr->display)
            && (parentPtr->screenNum == winPtr->screenNum)) {
        winPtr->atts.colormap = parentPtr->atts.colormap;
    } else {
        winPtr->atts.colormap = DefaultColormap(dispPtr->display, screenNum);
    }
    winPtr->dirtyAtts = CWEventMask|CWColormap|CWBitGravity;
    winPtr->flags = 0;
    winPtr->handlerList = NULL;
#ifdef TK_USE_INPUT_METHODS
    winPtr->ximGeneration = 0;
    winPtr->inputContext = NULL;
#endif
    winPtr->tagPtr = NULL;
    winPtr->numTags = 0;
    winPtr->optionLevel = -1;
    winPtr->selHandlerList = NULL;
    winPtr->geomMgrPtr = NULL;
    winPtr->geomData = NULL;
    winPtr->geomMgrName = NULL;
    winPtr->maintainerPtr = NULL;
    winPtr->reqWidth = winPtr->reqHeight = 1;
    winPtr->internalBorderLeft = 0;
    winPtr->wmInfoPtr = NULL;
    winPtr->classProcsPtr = NULL;
    winPtr->instanceData = NULL;
    winPtr->privatePtr = NULL;
    winPtr->internalBorderRight = 0;
    winPtr->internalBorderTop = 0;
    winPtr->internalBorderBottom = 0;
    winPtr->minReqWidth = 0;
    winPtr->minReqHeight = 0;

    optionTable = Tk_CreateOptionTable(interp, optionSpecs[type]);

    Tk_SetClass(tkwin, classNames[type]);
    butPtr = TkpCreateButton(tkwin);

    Tk_SetClassProcs(tkwin, &tkpButtonProcs, butPtr);
    butPtr->tkwin = tkwin;
    butPtr->display = Tk_Display(tkwin);
    butPtr->interp = interp;
    butPtr->widgetCmd = Tcl_CreateObjCommand(interp, Tk_PathName(tkwin),
            ButtonWidgetObjCmd, butPtr, ButtonCmdDeletedProc);
    butPtr->type = type;
    butPtr->optionTable = optionTable;
    butPtr->textPtr = NULL;
    butPtr->underline = -1;
    butPtr->textVarNamePtr = NULL;
    butPtr->bitmap = None;
    butPtr->imagePtr = NULL;
    butPtr->image = NULL;
    butPtr->selectImagePtr = NULL;
    butPtr->selectImage = NULL;
    butPtr->tristateImagePtr = NULL;
    butPtr->tristateImage = NULL;
    butPtr->state = STATE_NORMAL;
    butPtr->normalBorder = NULL;
    butPtr->activeBorder = NULL;
    butPtr->borderWidthPtr = NULL;
    butPtr->borderWidth = 0;
    butPtr->relief = TK_RELIEF_FLAT;
    butPtr->highlightWidthPtr = NULL;
    butPtr->highlightWidth = 0;
    butPtr->highlightBorder = NULL;
    butPtr->highlightColorPtr = NULL;
    butPtr->inset = 0;
    butPtr->tkfont = NULL;
    butPtr->normalFg = NULL;
    butPtr->activeFg = NULL;
    butPtr->disabledFg = NULL;
    butPtr->normalTextGC = NULL;
    butPtr->activeTextGC = NULL;
    butPtr->disabledGC = NULL;
    butPtr->stippleGC = NULL;
    butPtr->gray = None;
    butPtr->copyGC = NULL;
    butPtr->widthPtr = NULL;
    butPtr->width = 0;
    butPtr->heightPtr = NULL;
    butPtr->height = 0;
    butPtr->wrapLengthPtr = NULL;
    butPtr->wrapLength = 0;
    butPtr->padXPtr = NULL;
    butPtr->padX = 0;
    butPtr->padYPtr = NULL;
    butPtr->padY = 0;
    butPtr->anchor = TK_ANCHOR_CENTER;
    butPtr->justify = TK_JUSTIFY_CENTER;
    butPtr->indicatorOn = 0;
    butPtr->selectBorder = NULL;
    butPtr->textWidth = 0;
    butPtr->textHeight = 0;
    butPtr->textLayout = NULL;
    butPtr->indicatorSpace = 0;
    butPtr->indicatorDiameter = 0;
    butPtr->defaultState = DEFAULT_DISABLED;
    butPtr->selVarNamePtr = NULL;
    butPtr->onValuePtr = NULL;
    butPtr->offValuePtr = NULL;
    butPtr->tristateValuePtr = NULL;
    butPtr->cursor = NULL;
    butPtr->takeFocusPtr = NULL;
    butPtr->commandPtr = NULL;
    butPtr->flags = 0;

    Tk_CreateEventHandler(butPtr->tkwin,
            ExposureMask|StructureNotifyMask|FocusChangeMask,
            ButtonEventProc, butPtr);

    if (Tk_InitOptions(interp, (char *) butPtr, optionTable, tkwin)
            != TCL_OK) {
        Tk_DestroyWindow(butPtr->tkwin);
        return TCL_ERROR;
    }
    if (ConfigureButton(interp, butPtr, objc - 2, objv + 2) != TCL_OK) {
        Tk_DestroyWindow(butPtr->tkwin);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, TkNewWindowObj(butPtr->tkwin));
    return TCL_OK;
*/

    widget = (WidgetObject*)self;
    Py_INCREF(font);
    if (self->text) CFRelease(self->text);
    if (text) CFRetain(text);
    self->text = text;
    self->font = font;

    Py_XDECREF(self->image);
    if (image) Py_INCREF(image);
    self->image = image;
    self->compound = compound;

    rect.origin.x = 0;
    rect.origin.y = 0;
    rect.size = widget->minimum_size;

    label = [[LabelView alloc] initWithFrame: rect];
    widget->view = label;
    label->object = widget;

    Py_INCREF(systemTextColor);
    Py_INCREF(systemTextColor);
    Py_INCREF(systemTextColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    Py_XDECREF(self->active_foreground);
    Py_XDECREF(self->active_background);
    Py_XDECREF(self->disabled_foreground);
    Py_XDECREF(self->highlight_background);
    Py_XDECREF(self->highlight_color);
    self->foreground = systemTextColor;
    self->background = systemWindowBackgroundColor;
    self->active_foreground = systemTextColor;
    self->active_background = systemWindowBackgroundColor;
    self->disabled_foreground = systemTextColor;
    self->highlight_background = systemWindowBackgroundColor;
    self->highlight_color = systemWindowBackgroundColor;

    self->anchor = PY_ANCHOR_C;

    return 0;
}

static PyObject*
Label_repr(LabelObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    return PyUnicode_FromFormat("Label object %p wrapping NSView %p",
                                self, widget->view);
}

static void
Label_dealloc(LabelObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    LabelView* label = (LabelView*) (widget->view);
    CFStringRef text = self->text;
    if (label) [label release];
    if (text) CFRelease(text);
    Py_XDECREF(self->font);
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    Py_XDECREF(self->active_foreground);
    Py_XDECREF(self->active_background);
    Py_XDECREF(self->disabled_foreground);
    Py_XDECREF(self->highlight_background);
    Py_XDECREF(self->highlight_color);
    Py_XDECREF(self->image);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Label_set_position(LabelObject* self, PyObject *args)
{
    float x;
    float y;
    NSPoint position;
    WidgetObject* widget = (WidgetObject*)self;
    LabelView* label = (LabelView*) (widget->view);
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &x, &y))
        return NULL;

    position.x = x;
    position.y = y;
    [label setFrameOrigin: position];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject* Label_calculate_minimum_size(LabelObject* self, void* closure)
{
    /* follows the logic in TkpComputeButtonGeometry */
    CFAttributedStringRef string = NULL;
    CFDictionaryRef attributes = NULL;
    CGSize size;
    CGFloat width;
    CGFloat height;
    CFRange range = CFRangeMake(0, 0);
    CGSize constraints = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    CTFramesetterRef framesetter = NULL;
    CFRange fitRange;
    CFStringRef keys[] = { kCTFontAttributeName };
    CFTypeRef values[] = { self->font->font } ;
    PyObject* tuple = NULL;

    attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                    (const void**)&keys,
                                    (const void**)&values,
                                    1,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);
    if (!attributes) {
        PyErr_SetString(PyExc_MemoryError,
                        "failed to create attributes dictionary");
        return NULL;
    }

    if (self->text && (self->width == 0 || self->height == 0)) {
        string = CFAttributedStringCreate(kCFAllocatorDefault,
                                          self->text,
                                          attributes);
        if (!string) {
            PyErr_SetString(PyExc_MemoryError,
                            "failed to create attributed string");
            goto exit;
        }
        framesetter = CTFramesetterCreateWithAttributedString(string);
        CFRelease(string);
        if (!framesetter) {
            PyErr_SetString(PyExc_MemoryError, "failed to create framesetter");
            goto exit;
        }
        size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter,
                                                            range,
                                                            NULL,
                                                            constraints,
                                                            &fitRange);
        width = size.width;
        height = size.height;
    }

    if (self->width > 0 || self->height > 0) {
        string = CFAttributedStringCreate(kCFAllocatorDefault,
                                          CFSTR("0"),
                                          attributes);
        if (!string) {
            PyErr_SetString(PyExc_MemoryError,
                            "failed to create attributed string");
            goto exit;
        }
        if (framesetter) CFRelease(framesetter);
        framesetter = CTFramesetterCreateWithAttributedString(string);
        CFRelease(string);
        if (!framesetter) {
            PyErr_SetString(PyExc_MemoryError, "failed to create framesetter");
            goto exit;
        }
        size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter,
                                                            range,
                                                            NULL,
                                                            constraints,
                                                            &fitRange);
        if (self->width > 0) width = self->width * size.width;
        if (self->height > 0) height = self->height * size.height;
    }

    if (self->image) {
        CGImageRef image = self->image->data;
        size_t image_width = CGImageGetWidth(image);
        size_t image_height = CGImageGetHeight(image);

        switch (self->compound) {
            case PY_COMPOUND_TOP:
            case PY_COMPOUND_BOTTOM:
                height += self->pady + image_height;
                width = (width > image_width ? width : image_width);
                break;
            case PY_COMPOUND_LEFT:
            case PY_COMPOUND_RIGHT:
                height = (height > image_height ? height : image_height);
                width += self->padx + image_width;
                break;
            case PY_COMPOUND_CENTER:
                height = (height > image_height ? height : image_height);
                width = (width > image_width ? width : image_width);
                break;
            default:
                break;
        }
    }

    if (width > 0 && height > 0) {
        width += 2 * (self->padx + self->highlight_thickness + self->border_width);
        height += 2 * (self->pady + self->highlight_thickness + self->border_width);
    }

    tuple = Py_BuildValue("ff", width, height);

exit:
    if (attributes) CFRelease(attributes);
    if (framesetter) CFRelease(framesetter);
    return tuple;
}

static char
Label_calculate_minimum_size__doc__[] = "minimum size requested by label.";

static PyMethodDef Label_methods[] = {
    {"set_position",
     (PyCFunction)Label_set_position,
     METH_VARARGS,
     "Moves the label to the new position."
    },
    {"calculate_minimum_size",
     (PyCFunction)Label_calculate_minimum_size,
     METH_VARARGS,
     Label_calculate_minimum_size__doc__
    },
    {NULL}  /* Sentinel */
};

static PyObject* Label_get_text(LabelObject* self, void* closure)
{
    if (self->text) return PyString_FromCFString(self->text);

    Py_INCREF(Py_None);
    return Py_None;
}

static int
Label_set_text(LabelObject* self, PyObject* value, void* closure)
{
    CFStringRef text;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (Py_IsNone(value)) self->text = NULL;
    else {
        text = PyString_AsCFString(value);
        if (!text) return -1;
        if (self->text) CFRelease(self->text);
        self->text = text;
    }
    fprintf(stderr, "In Label_set_text for NSView %p with object %p; setting Widget_unset_minimum_size\n", label, self);
    Widget_unset_minimum_size(widget);
    fprintf(stderr, "In Label_set_text for NSView %p with object %p; after calling Widget_unset_minimum_size\n", label, self);
    label.needsDisplay = YES;
    return 0;
}

static char Label_text__doc__[] = "label text.";

static PyObject* Label_get_font(LabelObject* self, void* closure)
{
    PyObject* font = (PyObject*) self->font;
    Py_INCREF(font);
    return font;
}

static int
Label_set_font(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyObject_IsInstance(value, (PyObject *)&FontType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Font object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->font);
    self->font = (FontObject*) value;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_font__doc__[] = "font for label";

static PyObject* Label_get_underline(LabelObject* self, void* closure)
{
    Py_ssize_t underline = self->underline;
    if (underline == -1) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromSsize_t(underline);
}

static int
Label_set_underline(LabelObject* self, PyObject* value, void* closure)
{
    Py_ssize_t underline;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (value == Py_None) underline = -1;
    else {
        if (!PyLong_Check(value)) {
            PyErr_SetString(PyExc_ValueError, "expected an integer.");
            return -1;
        }
        underline = PyLong_AsSsize_t(value);
        if (underline == -1 && PyErr_Occurred()) return -1;
        if (underline < 0) {
            PyErr_SetString(PyExc_ValueError, "expected a positive integer.");
            return -1;
        }
    }
    self->underline = underline;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_underline__doc__[] = "specifies the index of the character to underline.";

static PyObject* Label_get_image(LabelObject* self, void* closure)
{
    PyObject* image = (PyObject*) self->image;
    if (!image) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    Py_INCREF(image);
    return image;
}

static int
Label_set_image(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (Py_IsNone(value)) {
        Py_XDECREF(self->image);
        self->image = NULL;
    }
    else if (PyObject_IsInstance(value, (PyObject *)&ImageType)) {
        Py_INCREF(value);
        Py_XDECREF(self->image);
        self->image = (ImageObject*) value;
    }
    else {
        PyErr_SetString(PyExc_ValueError, "expected an Image object");
        return -1;
    }
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_image__doc__[] = "the image associated with the label, if any";

static PyObject* Label_get_active_foreground(LabelObject* self, void* closure)
{
    Py_INCREF(self->active_foreground);
    return (PyObject*) self->active_foreground;
}

static int
Label_set_active_foreground(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->active_foreground);
    self->active_foreground = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_active_foreground__doc__[] = "active foreground color.";

static PyObject* Label_get_active_background(LabelObject* self, void* closure)
{
    Py_INCREF(self->active_background);
    return (PyObject*) self->active_background;
}

static int
Label_set_active_background(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->active_background);
    self->active_background = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_active_background__doc__[] = "background color if active.";

static PyObject* Label_get_highlight_background(LabelObject* self, void* closure)
{
    Py_INCREF(self->highlight_background);
    return (PyObject*) self->highlight_background;
}

static int
Label_set_highlight_background(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->highlight_background);
    self->highlight_background = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_highlight_background__doc__[] = "background color when the label does not have focus.";

static PyObject* Label_get_highlight_color(LabelObject* self, void* closure)
{
    Py_INCREF(self->highlight_color);
    return (PyObject*) self->highlight_color;
}

static int
Label_set_highlight_color(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->highlight_color);
    self->highlight_color = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_highlight_color__doc__[] = "background color when the label has focus.";

static PyObject* Label_get_foreground(LabelObject* self, void* closure)
{
    Py_INCREF(self->foreground);
    return (PyObject*) self->foreground;
}

static int
Label_set_foreground(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->foreground);
    self->foreground = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_foreground__doc__[] = "foreground color.";

static PyObject* Label_get_background(LabelObject* self, void* closure)
{
    Py_INCREF(self->background);
    return (PyObject*) self->background;
}

static int
Label_set_background(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->background);
    self->background = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_background__doc__[] = "background color.";

static PyObject* Label_get_disabled_foreground(LabelObject* self, void* closure)
{
    Py_INCREF(self->disabled_foreground);
    return (PyObject*) self->disabled_foreground;
}

static int
Label_set_disabled_foreground(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->disabled_foreground);
    self->disabled_foreground = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_disabled_foreground__doc__[] = "foreground color when disabled.";

static PyObject* Label_get_state(LabelObject* self, void* closure)
{
    switch (self->state) {
        case NORMAL: return PyUnicode_FromString("NORMAL");
        case ACTIVE: return PyUnicode_FromString("ACTIVE");
        case DISABLED: return PyUnicode_FromString("DISABLED");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected NORMAL (%d), ACTIVE (%d), or DISABLED (%d), got %d",
                NORMAL, ACTIVE, DISABLED, self->state);
            return NULL;
    }
}

static int
Label_set_state(LabelObject* self, PyObject* value, void* closure)
{
    const char* state;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyUnicode_Check(value)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return -1;
    }
    state = PyUnicode_AsUTF8(value);
    if (!state) return -1;
    if (PyOS_stricmp(state, "NORMAL")==0) self->state = NORMAL;
    else if (PyOS_stricmp(state, "ACTIVE")==0) self->state = ACTIVE;
    else if (PyOS_stricmp(state, "DISABLED")==0) self->state = DISABLED;
    else {
        PyErr_Format(PyExc_ValueError,
            "expected 'NORMAL', 'ACTIVE', 'DISABLED (case-insensitive)' "
            "got %s", state);
        return -1;
    }
    label.needsDisplay = YES;
    return 0;
}

static char Label_state__doc__[] = "state of the label ('NORMAL', 'ACTIVE', or 'DISABLED').";

static PyObject* Label_get_take_focus(LabelObject* self, void* closure)
{
    if (self->take_focus) Py_RETURN_TRUE;
    else Py_RETURN_FALSE;
}

static int
Label_set_take_focus(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (value == Py_True) self->take_focus = true;
    else if (value == Py_False) self->take_focus = false;
    else {
        PyErr_SetString(PyExc_ValueError, "expected either True or False");
        return -1;
    }
    label.needsDisplay = YES;
    return 0;
}

static char Label_take_focus__doc__[] = "True if the label accepts the focus during keyboard traversal, False otherwise.";

static PyObject* Label_get_relief(LabelObject* self, void* closure)
{
    switch (self->relief) {
        case PY_RELIEF_RAISED: return PyUnicode_FromString("RAISED");
        case PY_RELIEF_SUNKEN: return PyUnicode_FromString("SUNKEN");
        case PY_RELIEF_FLAT: return PyUnicode_FromString("FLAT");
        case PY_RELIEF_RIDGE: return PyUnicode_FromString("RIDGE");
        case PY_RELIEF_SOLID: return PyUnicode_FromString("SOLID");
        case PY_RELIEF_GROOVE: return PyUnicode_FromString("GROOVE");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected RAISED (%d), SUNKEN (%d), FLAT (%d), "
                "RIDGE (%d), SOLID (%d), or GROOVE (%d), got %d",
                PY_RELIEF_RAISED, PY_RELIEF_SUNKEN, PY_RELIEF_FLAT,
                PY_RELIEF_RIDGE, PY_RELIEF_SOLID, PY_RELIEF_GROOVE,
                self->relief);
            return NULL;
    }
}

static int
Label_set_relief(LabelObject* self, PyObject* value, void* closure)
{
    const char* relief;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyUnicode_Check(value)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return -1;
    }
    relief = PyUnicode_AsUTF8(value);
    if (!relief) return -1;
    if (PyOS_stricmp(relief, "RAISED")==0) self->relief = PY_RELIEF_RAISED;
    else if (PyOS_stricmp(relief, "SUNKEN")==0) self->relief = PY_RELIEF_SUNKEN;
    else if (PyOS_stricmp(relief, "FLAT")==0) self->relief = PY_RELIEF_FLAT;
    else if (PyOS_stricmp(relief, "RIDGE")==0) self->relief = PY_RELIEF_RIDGE;
    else if (PyOS_stricmp(relief, "SOLID")==0) self->relief = PY_RELIEF_SOLID;
    else if (PyOS_stricmp(relief, "GROOVE")==0) self->relief = PY_RELIEF_GROOVE;
    else {
        PyErr_Format(PyExc_ValueError,
            "expected 'RAISED', 'SUNKEN', 'FLAT', 'RIDGE', 'SOLID', 'GROOVE' "
            "(case-insensitive), got %s.", relief);
        return -1;
    }
    label.needsDisplay = YES;
    return 0;
}

static char Label_relief__doc__[] = "desired 3D effect of the label ('NORMAL', 'ACTIVE', or 'DISABLED').";

static PyObject* Label_get_sticky(LabelObject* self, void* closure)
{
    char str[4];
    Sticky sticky = self->sticky;
    Py_ssize_t i = 0;
    if (sticky & PY_STICKY_N) str[i++] = 'N';
    if (sticky & PY_STICKY_W) str[i++] = 'W';
    if (sticky & PY_STICKY_S) str[i++] = 'S';
    if (sticky & PY_STICKY_E) str[i++] = 'E';
    return PyUnicode_FromStringAndSize(str, i);
}

static int
Label_set_sticky(LabelObject* self, PyObject* value, void* closure)
{
    char c;
    const char* str;
    Py_ssize_t i;
    Py_ssize_t length;
    Sticky sticky = 0;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyUnicode_Check(value)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return -1;
    }
    length = PyUnicode_GET_LENGTH(value);
    str = PyUnicode_AsUTF8(value);
    for (i = 0; i < length; i++) {
        c = str[i];
        switch(c) {
            case 'N':
            case 'n':
                if (sticky & PY_STICKY_N) {
                    PyErr_Format(PyExc_ValueError,
                                 "'N' included more than once");
                    return -1;
                }
                sticky |= PY_STICKY_N;
                break;
            case 'W':
            case 'w':
                if (sticky & PY_STICKY_W) {
                    PyErr_Format(PyExc_ValueError,
                                 "'W' included more than once");
                    return -1;
                }
                sticky |= PY_STICKY_W;
                break;
            case 'S':
            case 's':
                if (sticky & PY_STICKY_S) {
                    PyErr_Format(PyExc_ValueError,
                                 "'S' included more than once");
                    return -1;
                }
                sticky |= PY_STICKY_S;
                break;
            case 'E':
            case 'e':
                if (sticky & PY_STICKY_E) {
                    PyErr_Format(PyExc_ValueError,
                                 "'E' included more than once");
                    return -1;
                }
                sticky |= PY_STICKY_E;
                break;
            default:
                PyErr_Format(PyExc_ValueError,
                    "expected string consisting of 'N', 'W', 'S', and 'E', "
                    "got '%c'", c);
                return -1;
        }
    }
    self->sticky = sticky;
    label.needsDisplay = YES;
    return 0;
}

static char Label_sticky__doc__[] = "Specifies if the label should stretch if its assigned size is greater than its minimum size. Use a string consisting of 'N', 'W', 'S', 'E' to set this property.";

static PyObject* Label_get_border_width(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->border_width);
}

static int
Label_set_border_width(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat border_width = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->border_width = border_width;
    label.needsDisplay = YES;
    return 0;
}

static char Label_border_width__doc__[] = "width of the 3-D border to draw around the outside of the label.";

static PyObject* Label_get_padx(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->padx);
}

static int
Label_set_padx(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat padx = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->padx = padx;
    label.needsDisplay = YES;
    return 0;
}

static char Label_padx__doc__[] = "extra space to request for the label in the X-direction.";

static PyObject* Label_get_pady(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->pady);
}

static int
Label_set_pady(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat pady = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->pady = pady;
    label.needsDisplay = YES;
    return 0;
}

static char Label_pady__doc__[] = "extra space to request for the label in the Y-direction.";

static PyObject* Label_get_highlight_thickness(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->highlight_thickness);
}

static int
Label_set_highlight_thickness(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat highlight_thickness = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->highlight_thickness = highlight_thickness;
    label.needsDisplay = YES;
    return 0;
}

static char Label_highlight_thickness__doc__[] = "width of the highlight rectangle to draw around the outside of the label when it has the input focus.";

static PyObject* Label_get_width(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->width);
}

static int
Label_set_width(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat width = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->width = width;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_width__doc__[] = "preferred label width in characters (in case of text only) or pixels (if the label includes an image).";

static PyObject* Label_get_height(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->height);
}

static int
Label_set_height(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat height = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->height = height;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_height__doc__[] = "preferred label height as the number of text lines (in case of text only) or pixels (if the label includes an image).";

static PyObject* Label_get_anchor(LabelObject* self, void* closure)
{
    switch (self->anchor) {
        case PY_ANCHOR_N: return PyUnicode_FromString("N");
        case PY_ANCHOR_NE: return PyUnicode_FromString("NE");
        case PY_ANCHOR_E: return PyUnicode_FromString("E");
        case PY_ANCHOR_SE: return PyUnicode_FromString("SE");
        case PY_ANCHOR_S: return PyUnicode_FromString("S");
        case PY_ANCHOR_SW: return PyUnicode_FromString("SW");
        case PY_ANCHOR_W: return PyUnicode_FromString("W");
        case PY_ANCHOR_NW: return PyUnicode_FromString("NW");
        case PY_ANCHOR_C: return PyUnicode_FromString("C");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected N (%d), NE (%d), E (%d), SE (%d), S (%d), SW (%d), "
                "W (%d), NW (%d), or C (%d), got %d",
                PY_ANCHOR_N, PY_ANCHOR_NE, PY_ANCHOR_E, PY_ANCHOR_SE,
                PY_ANCHOR_S, PY_ANCHOR_SW, PY_ANCHOR_W, PY_ANCHOR_NW,
                PY_ANCHOR_C, self->anchor);
            return NULL;
    }
}

static int
Label_set_anchor(LabelObject* self, PyObject* value, void* closure)
{
    const char* anchor;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyUnicode_Check(value)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return -1;
    }
    anchor = PyUnicode_AsUTF8(value);
    if (!anchor) return -1;
    if (PyOS_stricmp(anchor, "N")==0
     || PyOS_stricmp(anchor, "NORTH")==0) self->anchor = PY_ANCHOR_N;
    else if (PyOS_stricmp(anchor, "NE")==0
          || PyOS_stricmp(anchor, "NORTHEAST")==0) self->anchor = PY_ANCHOR_NE;
    else if (PyOS_stricmp(anchor, "E")==0
          || PyOS_stricmp(anchor, "EAST")==0) self->anchor = PY_ANCHOR_E;
    else if (PyOS_stricmp(anchor, "SE")==0
          || PyOS_stricmp(anchor, "SOUTHEAST")==0) self->anchor = PY_ANCHOR_SE;
    else if (PyOS_stricmp(anchor, "S")==0
          || PyOS_stricmp(anchor, "SOUTH")==0) self->anchor = PY_ANCHOR_S;
    else if (PyOS_stricmp(anchor, "SW")==0
          || PyOS_stricmp(anchor, "SOUTHWEST")==0) self->anchor = PY_ANCHOR_SW;
    else if (PyOS_stricmp(anchor, "W")==0
          || PyOS_stricmp(anchor, "WEST")==0) self->anchor = PY_ANCHOR_W;
    else if (PyOS_stricmp(anchor, "NW")==0
          || PyOS_stricmp(anchor, "NORTHWEST")==0) self->anchor = PY_ANCHOR_NW;
    else if (PyOS_stricmp(anchor, "C")==0
          || PyOS_stricmp(anchor, "CENTER")==0) self->anchor = PY_ANCHOR_C;
    else {
        PyErr_Format(PyExc_ValueError,
            "expected 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', or 'C' "
            "(case-insensitive), got '%s'", anchor);
        return -1;
    }
    label.needsDisplay = YES;
    return 0;
}

static char Label_anchor__doc__[] = "anchor specifying location of the label.";

static PyObject* Label_get_compound(LabelObject* self, void* closure)
{
    switch (self->compound) {
        case PY_COMPOUND_NONE: return PyUnicode_FromString("NONE");
        case PY_COMPOUND_BOTTOM: return PyUnicode_FromString("BOTTOM");
        case PY_COMPOUND_TOP: return PyUnicode_FromString("TOP");
        case PY_COMPOUND_LEFT: return PyUnicode_FromString("LEFT");
        case PY_COMPOUND_RIGHT: return PyUnicode_FromString("RIGHT");
        case PY_COMPOUND_CENTER: return PyUnicode_FromString("CENTER");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected NONE (%d), BOTTOM (%d), TOP (%d), "
                "LEFT (%d), RIGHT (%d), or CENTER (%d)",
                PY_COMPOUND_NONE, PY_COMPOUND_BOTTOM, PY_COMPOUND_TOP,
                PY_COMPOUND_LEFT, PY_COMPOUND_RIGHT, PY_COMPOUND_CENTER,
                self->compound);
            return NULL;
    }
}

static int
Label_set_compound(LabelObject* self, PyObject* value, void* closure)
{
    if (compound_converter(value, &self->compound)) {
        WidgetObject* widget = (WidgetObject*) self;
        LabelView* label = (LabelView*) (widget->view);
        label.needsDisplay = YES;
        return 0;
    }
    return -1;
}

static char Label_compound__doc__[] = "for compound labels, the location of the image relative to the text.";


static PyGetSetDef Label_getseters[] = {
    {"text", (getter)Label_get_text, (setter)Label_set_text, Label_text__doc__, NULL},
    {"font", (getter)Label_get_font, (setter)Label_set_font, Label_font__doc__, NULL},
    {"image", (getter)Label_get_image, (setter)Label_set_image, Label_image__doc__, NULL},
    {"underline", (getter)Label_get_underline, (setter)Label_set_underline, Label_underline__doc__, NULL},
    {"foreground", (getter)Label_get_foreground, (setter)Label_set_foreground, Label_foreground__doc__, NULL},
    {"background", (getter)Label_get_background, (setter)Label_set_background, Label_background__doc__, NULL},
    {"active_foreground", (getter)Label_get_active_foreground, (setter)Label_set_active_foreground, Label_active_foreground__doc__, NULL},
    {"active_background", (getter)Label_get_active_background, (setter)Label_set_active_background, Label_active_background__doc__, NULL},
    {"disabled_foreground", (getter)Label_get_disabled_foreground, (setter)Label_set_disabled_foreground, Label_disabled_foreground__doc__, NULL},
    {"highlight_background", (getter)Label_get_highlight_background, (setter)Label_set_highlight_background, Label_highlight_background__doc__, NULL},
    {"highlight_color", (getter)Label_get_highlight_color, (setter)Label_set_highlight_color, Label_highlight_color__doc__, NULL},
    {"sticky", (getter)Label_get_sticky, (setter)Label_set_sticky, Label_sticky__doc__, NULL},
    {"relief", (getter)Label_get_relief, (setter)Label_set_relief, Label_relief__doc__, NULL},
    {"state", (getter)Label_get_state, (setter)Label_set_state, Label_state__doc__, NULL},
    {"take_focus", (getter)Label_get_take_focus, (setter)Label_set_take_focus, Label_take_focus__doc__, NULL},
    {"anchor", (getter)Label_get_anchor, (setter)Label_set_anchor, Label_anchor__doc__, NULL},
    {"compound", (getter)Label_get_compound, (setter)Label_set_compound, Label_compound__doc__, NULL},
    {"border_width", (getter)Label_get_border_width, (setter)Label_set_border_width, Label_border_width__doc__, NULL},
    {"padx", (getter)Label_get_padx, (setter)Label_set_padx, Label_padx__doc__, NULL},
    {"pady", (getter)Label_get_pady, (setter)Label_set_pady, Label_pady__doc__, NULL},
    {"highlight_thickness", (getter)Label_get_highlight_thickness, (setter)Label_set_highlight_thickness, Label_highlight_thickness__doc__, NULL},
    {"width", (getter)Label_get_width, (setter)Label_set_width, Label_width__doc__, NULL},
    {"height", (getter)Label_get_height, (setter)Label_set_height, Label_height__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Label_doc[] =
"A Label object wraps a Cocoa NSTextField object.\n";

Py_LOCAL_SYMBOL PyTypeObject LabelType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "_guitk.Label",
    .tp_basicsize = sizeof(LabelObject),
    .tp_dealloc = (destructor)Label_dealloc,
    .tp_repr = (reprfunc)Label_repr,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_doc = Label_doc,
    .tp_methods = Label_methods,
    .tp_getset = Label_getseters,
    .tp_base = &WidgetType,
    .tp_init = (initproc)Label_init,
    .tp_new = Label_new,
};
