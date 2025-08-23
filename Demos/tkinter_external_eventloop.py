import os
import tkinter
from guitk import events_tcltk

window = tkinter.Tk()

label = tkinter.Label(window, text="Tkinter", font='Helvetica 40', width=20)
label.pack()

def clicked():
    print("Tkinter button clicked")

def trigger():
    message = "Tkinter file descriptor triggered"
    n = os.write(writing_fd, message.encode())
 
def handle_io(fd, mask):
    message = os.read(fd, 1024)
    print(message.decode())

def update(counter=0):
    print("Tkinter timer update %d" % counter)
    window.after(1000, update, counter+1)

button1 = tkinter.Button(window, text="Click me", command=clicked, font='Helvetica 20', width=20)
button1.pack()

reading_fd, writing_fd = os.pipe()
window.tk.createfilehandler(reading_fd, tkinter.READABLE, handle_io)
button2 = tkinter.Button(window, text="Trigger the file descriptor", command=trigger, font='Helvetica 20', width=20)
button2.pack()

button3 = tkinter.Button(window, text="Start the timer", command=update, font='Helvetica 20', width=20)
button3.pack()

events_tcltk.simple()
events_tcltk.start()
