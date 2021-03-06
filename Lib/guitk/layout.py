from guitk import gui
import array

class Grid(gui.Layout):
    def __init__(self, nrows, ncols):
        assert nrows > 0
        assert ncols > 0
        self.nrows = nrows
        self.ncols = ncols
        self.objects = [[None for j in xrange(ncols)] for i in xrange(nrows)]
    def __getitem__(self, key):
        i, j = key
        return self.objects[i][j]
    def __setitem__(self, key, value):
        i, j = key
        obj = self.objects[i][j]
        if obj:
            obj.remove()
        self.objects[i][j] = value
        self.add(value)
    def layout(self):
        print "Performing layout"
        heights = array.array('f', [0]*self.nrows)
        widths = array.array('f', [0]*self.ncols)
        hexpand = array.array('b', [0]*self.ncols)
        vexpand = array.array('b', [0]*self.nrows)
        for i in range(self.nrows):
            for j in range(self.ncols):
                object = self.objects[i][j]
                if object is None:
                    continue
                width, height = object.minimum_size
                widths[j] = max(widths[j], width)
                heights[i] = max(heights[i], height)
                if object.hexpand:
                    hexpand[j] = 1
                if object.vexpand:
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
                object = self.objects[i][j]
                if object is None:
                    continue
                x, y, w, h = object.place(xs[j], ys[i], widths[j], heights[i])
                object.origin = (x, y)
                object.size = (w, h)
    @property
    def minimum_size(self):
        heights = array.array('f', [0]*self.nrows)
        widths = array.array('f', [0]*self.ncols)
        for i in range(self.nrows):
            for j in range(self.ncols):
                object = self.objects[i][j]
                if object is None:
                    continue
                width, height = object.minimum_size
                widths[j] = max(widths[j], width)
                heights[i] = max(heights[i], height)
        width = sum(widths)
        height = sum(heights)
        size = (width, height)
        return size
