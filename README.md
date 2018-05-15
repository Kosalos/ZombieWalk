# ZombieWalk
Chase game for iPad using Swift and Quartz

Just the beginnings of a chase game.\
The intent is that a swarm of slow moving zombies will chase you around an uneven terrain.

So far:
1. the uneven terrain is created (darker regions are harder/slower to cross)
2. a single zombie determines the easiest path from starting point to destination.
3. a slider allows you to smooth the uneven terrain.
4. click on screen to move the start point or endpoint to new position.

next steps:\
5. add the human player, controlled by movement widgets (or maybe tilt)\
6. more zombies,  who update their path as necessary..

Note: added segment Control with Move, Lighter and Darker.\
Move affects the endpoints as before.\
Lighter, Darker alter the terrain cells you touch.

** Added player carries a lamp.
Electricity has gone out.
Human player carries a lamp to explore the office (draw some walls to denote several rooms).
Zombies will be standing still in the dark, but will start to chase when they see the lamp.
Maybe after you run away, they continue to walk for awhile in the current direction.
Or maybe, even in the dark, they can hear you walking (if not obscured by a wall), and advance slowly.
The un-even terrian effect can by used to denote office furniture, or stairs..

![Screenshot](screenshot.png)

