from guitk import gui
import numpy as np

font = gui.Font("Helvetica", 40)

window = gui.Window()
label = gui.Label("Check out the icon", font)
window.content = label

image = np.zeros((100,100,3), 'B')
image[:50,:50] = (0, 0, 255)
image[:50,50:] = (255, 0, 255)
image[50:,:50] = (0, 128, 255)
image[50:,50:] = (128, 128, 0)
image = gui.Image(image)

gui.set_icon(image)

window.show()
