# Project description and objectives

H42N42 a simulator where you manage a population of creatures, threatened by a virus. The goal is to keep them alive by keeping them away from a toxic river and bringing the sick ones to the hospital.

This project puts into practice client-side web programming in OCaml with the Ocsigen framework.

# Prerequisites

- Docker
- Docker Compose
- make

# Installation and setup instructions

Install make for Linux: `sudo apt-get install build-essential`

Install make for Windows: `choco install make`

Install Docker: https://docs.docker.com/get-started/get-docker/

# How to run the application 

```bash
make
```

# How to access the application in the browser

http://localhost:8080

# Brief explanation of the game rules

- Objective: Keep at least one healthy creet alive as long as possible
- Toxic river: Located at the top of the screen, any creet that touches it falls sick (it changes color and loses 15% speed)
- Hospital: Located at the bottom of the screen, you must catch sick creets and drop them at the hospital to heal them
- Interactions: You can click and drag a creet, during which time it is invulnerable
- Contagion: A sick creet that comes into contact with a healthy creet has a 2% chance of infecting it
- Mutations: Sick creets have a 10% chance to evolve into:
  - Berserk: Grows rapidly until it explodes, increasing its contagion area
  - Mean: Shrinks and actively chases healthy creets to infect them
  
    (Mutated creets can neither be caught nor healed)
- Difficulty: The speed of the creets gradually increases over time
- Game over: The game ends when there are no healthy creets left
