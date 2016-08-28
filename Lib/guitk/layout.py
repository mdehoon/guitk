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
                width, height = self.objects[i][j].minimum_size
                widths[j] = max(widths[j], width)
                heights[i] = max(heights[i], height)
        width, height = self.size
        extra_height = (height - sum(heights))/self.ncols
        extra_width = (width - sum(widths))/self.nrows
        for i in range(self.nrows):
            heights[i] += extra_height
        for j in range(self.ncols):
            widths[j] += extra_width
        xs = array.array('f', [0]*self.ncols)
        ys = array.array('f', [0]*self.nrows)
        for i in range(self.nrows-1):
            ys[i-1] = ys[i] + heights[i]
        for j in range(self.ncols-1):
            xs[j-1] = xs[j] + widths[j]
        for i in range(self.nrows):
            for j in range(self.ncols):
                self.objects[i][j].origin = (xs[j], ys[i])
                self.objects[i][j].size = (widths[j], heights[i])
