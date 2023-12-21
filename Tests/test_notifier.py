import os
from guitk import events

r, w = os.pipe()

counter = 0
def f(s):
    global counter
    counter += 1
    print("timer", counter, s)
    os.write(w, b'x')

def g(s):
    print("notifier", counter, s)
    if counter==5:
        timer.stop()
    x = os.read(r, 1)
    events.create_notifier(g, r, events.READABLE)

def h(s):
    print("stopping event loop", s)
    events.stop()

timer = events.create_timer(f, 1, True)
stoptimer = events.create_timer(h, 10)
notifier = events.create_notifier(g, r)
events.run()
