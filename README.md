# Dungeon Crawler Game - Installation and Playing Instructions

I've created a fully playable text-based dungeon crawler game in Gleam that you can run on your local machine. This game features:

- Multiple rooms to explore
- Items to collect and use
- Enemies to fight
- A real game loop that lets you play until you win or lose

## Prerequisites

Make sure you have Gleam and Erlang properly installed:

```bash
# Check your installations
gleam --version
erl -version
```

## Setup Instructions

1. Create a new Gleam project:

```bash
gleam new dungeon_crawler
cd dungeon_crawler
```

2. Replace the content of `src/dungeon_crawler.gleam` with the code from the "Playable Dungeon Crawler in Gleam" artifact.

3. Compile and run the game:

```bash
gleam run
```

## Game Map

The dungeon consists of the following rooms:

```
       [Exit Room] (5)
           ↑
           |
[Entrance] (1) → [Hallway] (2) → [Treasure Room] (4)
     ↓
[Storage Room] (3)
```

- **Dungeon Entrance (1)**: Starting point with a rusty sword
- **Long Hallway (2)**: Contains a healing potion and a goblin enemy
- **Storage Room (3)**: Contains the dungeon key
- **Treasure Room (4)**: Contains a steel sword, the exit key, and a troll enemy (requires dungeon key)
- **Dungeon Exit (5)**: The final room (requires exit key)

## How to Play

When you start the game, you'll be asked to enter your name. After that, you'll be placed in the first room of the dungeon.

### Available Commands

- `look` - Look around the current room
- `north`, `south`, `east`, `west` - Move in a direction
- `take [item]` - Pick up an item from the room
- `use [item]` - Use an item from your inventory (equip a weapon or drink a potion)
- `attack` - Attack an enemy in the room
- `inventory` or `inv` - Show your inventory
- `status` or `stat` - Show your player status
- `help` - Show the list of commands
- `quit` - Exit the game

## Game Strategy

1. Start by picking up the rusty sword in the entrance room.
2. Use the rusty sword to equip it.
3. Go east to the hallway.
4. Attack the goblin (you may need multiple attacks to defeat it).
5. Take the healing potion and use it if needed.
6. Go back west to the entrance, then south to the storage room.
7. Take the dungeon key.
8. Go north to the entrance, then east to the hallway, then east to the treasure room (which requires the key).
9. Take the steel sword and exit key.
10. Use the steel sword to get a stronger weapon.
11. Attack and defeat the troll.
12. Go north to the exit room (which requires the exit key).
13. You win!

Enjoy your adventure in the dungeon!