import guitk

window = guitk.Window(300,100, 'Hello')
label = guitk._guitk.Label("Hello, world!")
window.add(label)
window.pack()
window.show()

