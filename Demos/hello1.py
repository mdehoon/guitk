from guitk import gui

window = gui.Window(300,100, 'Hello')
label = gui.Label("Hello, world!")
label.background = (1, 1, 0, 0.5)
window.contents = label
window.show()

