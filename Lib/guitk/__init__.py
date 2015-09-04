import _guitk

class Window(_guitk.Window):
    def __init__(self, width, height, title):
        _guitk.Window.__init__(self, width, height, title)
    def add(self, control):
        _guitk.Window.add(self, control)
