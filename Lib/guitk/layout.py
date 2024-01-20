from guitk import gui
import array

class Grid(gui.Layout):
    def __init__(self, nrows, ncols):
        assert nrows > 0
        assert ncols > 0
        self.nrows = nrows
        self.ncols = ncols
        self.widgets = [[None for j in range(ncols)] for i in range(nrows)]
    def __getitem__(self, key):
        i, j = key
        return self.widgets[i][j]
    def __setitem__(self, key, value):
        i, j = key
        obj = self.widgets[i][j]
        if obj:
            obj.remove()
        self.widgets[i][j] = value
        self.add(value)
    def layout(self):
        print("Performing layout")
        heights = array.array('f', [0]*self.nrows)
        widths = array.array('f', [0]*self.ncols)
        hexpand = array.array('b', [0]*self.ncols)
        vexpand = array.array('b', [0]*self.nrows)
        for i in range(self.nrows):
            for j in range(self.ncols):
                widget = self.widgets[i][j]
                if widget is None:
                    continue
                width, height = widget.minimum_size
                widths[j] = max(widths[j], width)
                heights[i] = max(heights[i], height)
                if widget.hexpand:
                    hexpand[j] = 1
                if widget.vexpand:
                    vexpand[i] = 1
        width, height = self.size
        shexpand = sum(hexpand)
        svexpand = sum(vexpand)
        if svexpand > 0:
            extra_height = (height - sum(heights))/svexpand
            for i in range(self.nrows):
                if vexpand[i]:
                    heights[i] += extra_height
        if shexpand > 0:
            extra_width = (width - sum(widths))/shexpand
            for j in range(self.ncols):
                if hexpand[j]:
                    widths[j] += extra_width
        xs = array.array('f', [0]*self.ncols)
        ys = array.array('f', [0]*self.nrows)
        for i in range(1,self.nrows):
            ys[i] = ys[i-1] + heights[i-1]
        for j in range(1,self.ncols):
            xs[j] = xs[j-1] + widths[j-1]
        for i in range(self.nrows):
            for j in range(self.ncols):
                widget = self.widgets[i][j]
                if widget is None:
                    continue
                x, y, w, h = widget.place(xs[j], ys[i], widths[j], heights[i])
                widget.origin = (x, y)
                widget.size = (w, h)
    def calculate_minimum_size(self):
        heights = array.array('f', [0]*self.nrows)
        widths = array.array('f', [0]*self.ncols)
        for i in range(self.nrows):
            for j in range(self.ncols):
                widget = self.widgets[i][j]
                if widget is None:
                    continue
                width, height = widget.minimum_size
                widths[j] = max(widths[j], width)
                heights[i] = max(heights[i], height)
        width = sum(widths)
        height = sum(heights)
        size = (width, height)
        return size
