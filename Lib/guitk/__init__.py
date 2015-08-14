import _guitk

class Window(_guitk.Window):
    def __init__(self, width, height, title):
        _guitk.Window.__init__(self, width, height, title)
        self.children = []
    def add(self, control):
        _guitk.Window.add(self, control)
        self.children.append(control)
    def pack(self):
        x0, y0 = 0, 0
        x1, y1 = self.get_size()
        cavity = [x0, y0, x1, y1]
        for child in self.children:
            child.pack(cavity)
