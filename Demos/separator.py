from guitk import gui, layout

window = gui.Window()
grid = layout.Grid(1,3)
window.content = grid
grid[0,0] = layout.Grid(3,1)
grid[0,1] = gui.Separator()
grid[0,2] = gui.Label()
grid[0,0].hexpand = True
grid[0,0].vexpand = True
grid[0,1].hexpand = False
grid[0,1].vexpand = True
grid[0,2].hexpand = True
grid[0,2].vexpand = True
grid = grid[0,0]
grid[0,0] = gui.Label("Apples")
grid[1,0] = gui.Separator()
grid[2,0] = gui.Label("Oranges")
grid[0,0].hexpand = True
grid[0,0].vexpand = True
grid[1,0].hexpand = True
grid[1,0].vexpand = False
grid[2,0].hexpand = True
grid[2,0].vexpand = True
window.show()
