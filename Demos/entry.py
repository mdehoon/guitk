from guitk import gui, layout

def callback():
    print textbox.text

window = gui.Window()
grid = layout.Grid(2,1)
textbox = gui.Textbox()
textbox.hexpand = True
textbox.text = 'Some text'
button = gui.Button("get")
button.command = callback
button.hexpand = True
grid[0,0] = textbox
grid[1,0] = button
window.content = grid
window.show()
