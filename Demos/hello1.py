import guitk

window = guitk.Window(300,100, 'Hello')
label = guitk._guitk.Label("Hello, world!")
grid = guitk._guitk.Grid(1,1)
griditem = grid[0,0].put(label)
# window.put(grid)
# window.show()

