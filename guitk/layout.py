from guitk import gui
import array

class Grid(gui.Layout):
    def __new__(cls, nrows, ncols):
        assert nrows > 0
        assert ncols > 0
        self = super().__new__(cls, nrows * ncols)
        self.nrows = nrows
        self.ncols = ncols
        return self
    def __getitem__(self, key):
        i, j = key
        k = i * self.ncols + j
        return super().__getitem__(k)
    def __setitem__(self, key, value):
        i, j = key
        k = i * self.ncols + j
        super().__setitem__(k, value)
    def layout(self, x, y, width, height):
        heights = array.array('f', [0]*self.nrows)
        widths = array.array('f', [0]*self.ncols)
        hexpand = array.array('b', [0]*self.ncols)
        vexpand = array.array('b', [0]*self.nrows)
        keys = [(i,j) for i in range(self.nrows) for j in range(self.ncols)]
        for k, (i, j) in enumerate(keys):
            widget = super().__getitem__(k)
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
        for k, (i, j) in enumerate(keys):
            widget = super().__getitem__(k)
            if widget is None:
                continue
            widget.place(xs[j], ys[i], widths[j], heights[i])
            if isinstance(widget, gui.Layout):
                widget.layout(xs[j], ys[i], widths[j], heights[i])
    def calculate_minimum_size(self):
        heights = array.array('f', [0]*self.nrows)
        widths = array.array('f', [0]*self.ncols)
        keys = [(i,j) for i in range(self.nrows) for j in range(self.ncols)]
        for k, (i, j) in enumerate(keys):
            widget = super().__getitem__(k)
            if widget is None:
                continue
            width, height = widget.minimum_size
            widths[j] = max(widths[j], width)
            heights[i] = max(heights[i], height)
        width = sum(widths)
        height = sum(heights)
        size = (width, height)
        return size
