from guitk import gui

window = gui.Window(300,100, 'Hello')
label = gui.Label("Hello, world!")
grid = gui.Grid(1,1)
griditem = grid[0,0].put(label)
window.put(grid)
window.show()

