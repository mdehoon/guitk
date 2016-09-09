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
        for i in range(self.nrows):
            for j in range(self.ncols):
                object = self.objects[i][j]
                if object is None:
                    continue
                width, height = object.minimum_size
                widths[j] = max(widths[j], width)
                heights[i] = max(heights[i], height)
        width, height = self.size
        extra_height = (height - sum(heights))/self.nrows
        extra_width = (width - sum(widths))/self.ncols
        for i in range(self.nrows):
            heights[i] += extra_height
        for j in range(self.ncols):
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
                object.origin = (xs[j], ys[i])
                object.size = (widths[j], heights[i])
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
    @property
    def size(self):
        return gui.Layout.size.__get__(self)
    @size.setter
    def size(self, size):
        gui.Layout.size.__set__(self, size)
        self.layout()
