// src/dungeon_crawler.gleam
// A simple text-based dungeon crawler game

import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

// Types
pub type Direction {
  North
  South
  East
  West
}

pub type Item {
  Weapon(String, Int)
  // name, damage
  Potion(String, Int)
  // name, health_restore
  Key(String)
  // name
}

pub type Enemy {
  Enemy(String, Int, Int)
  // name, health, damage
}

pub type Room {
  Room(Int, String, String, List(Item))
  // id, name, description, items
}

pub type Player {
  Player(String, Int, Int, List(Item), Int)
  // name, health, max_health, inventory, current_room_id
}

pub type GameState {
  GameState(Player, Bool, Bool)
  // player, game_over, won
}

// We use dictionaries for all our lookups
pub type GameWorld {
  GameWorld(
    dict.Dict(Int, Room),
    // rooms by id
    dict.Dict(Int, Enemy),
    // enemies by room id 
    dict.Dict(Int, dict.Dict(Direction, Int)),
    // exits by room id
    dict.Dict(Int, String),
    // required keys by room id
  )
}

// Initialize the game world
pub fn create_game(player_name: String) -> #(GameState, GameWorld) {
  let rusty_sword = Weapon("Rusty Sword", 5)
  let steel_sword = Weapon("Steel Sword", 10)
  let healing_potion = Potion("Healing Potion", 20)
  let dungeon_key = Key("Dungeon Key")
  let exit_key = Key("Exit Key")

  let goblin = Enemy("Goblin", 15, 3)
  let troll = Enemy("Troll", 30, 5)

  // Create rooms
  let entrance =
    Room(
      1,
      "Dungeon Entrance",
      "A dark, damp room with stone walls. The entrance behind you is blocked by debris.",
      [rusty_sword],
    )

  let hallway =
    Room(
      2,
      "Long Hallway",
      "A long, narrow hallway with flickering torches on the walls.",
      [healing_potion],
    )

  let storage =
    Room(
      3,
      "Storage Room",
      "A small room filled with broken furniture and empty crates.",
      [dungeon_key],
    )

  let treasure =
    Room(
      4,
      "Treasure Room",
      "A room glittering with gold coins and valuable artifacts.",
      [steel_sword, exit_key],
    )

  let exit_room =
    Room(5, "Dungeon Exit", "A heavy iron door that leads to freedom.", [])

  // Store rooms in a dictionary
  let rooms =
    dict.new()
    |> dict.insert(1, entrance)
    |> dict.insert(2, hallway)
    |> dict.insert(3, storage)
    |> dict.insert(4, treasure)
    |> dict.insert(5, exit_room)

  // Store enemies in a dictionary by room id
  let enemies =
    dict.new()
    |> dict.insert(2, goblin)
    |> dict.insert(4, troll)

  // Store exits in a dictionary by room id
  let room1_exits = dict.new() |> dict.insert(East, 2) |> dict.insert(South, 3)
  let room2_exits = dict.new() |> dict.insert(West, 1) |> dict.insert(East, 4)
  let room3_exits = dict.new() |> dict.insert(North, 1)
  let room4_exits = dict.new() |> dict.insert(West, 2) |> dict.insert(North, 5)
  let room5_exits = dict.new() |> dict.insert(South, 4)

  let exits =
    dict.new()
    |> dict.insert(1, room1_exits)
    |> dict.insert(2, room2_exits)
    |> dict.insert(3, room3_exits)
    |> dict.insert(4, room4_exits)
    |> dict.insert(5, room5_exits)

  // Store required keys in a dictionary by room id
  let required_keys =
    dict.new()
    |> dict.insert(4, "Dungeon Key")
    // Treasure room requires dungeon key
    |> dict.insert(5, "Exit Key")
  // Exit room requires exit key

  // Create player
  let player =
    Player(
      player_name,
      50,
      // health
      50,
      // max_health  
      [],
      // inventory
      1,
      // starting in room 1
    )

  // Create game state
  let state =
    GameState(
      player,
      False,
      // game_over
      False,
      // won
    )

  // Create game world
  let world = GameWorld(rooms, enemies, exits, required_keys)

  #(state, world)
}

// Helper function to get a room by id
pub fn get_room(world: GameWorld, room_id: Int) -> Room {
  let GameWorld(rooms, _, _, _) = world
  case dict.get(rooms, room_id) {
    Ok(room) -> room
    Error(Nil) -> Room(0, "Void", "You shouldn't be here...", [])
  }
}

// Helper function to get current room
pub fn get_current_room(state: GameState, world: GameWorld) -> Room {
  let GameState(player, _, _) = state
  let Player(_, _, _, _, current_room_id) = player
  get_room(world, current_room_id)
}

// Helper function to get exits for a room
pub fn get_exits(world: GameWorld, room_id: Int) -> dict.Dict(Direction, Int) {
  let GameWorld(_, _, exits, _) = world
  case dict.get(exits, room_id) {
    Ok(room_exits) -> room_exits
    Error(Nil) -> dict.new()
  }
}

// Helper function to get enemy in a room
pub fn get_enemy(world: GameWorld, room_id: Int) -> Result(Enemy, Nil) {
  let GameWorld(_, enemies, _, _) = world
  dict.get(enemies, room_id)
}

// Helper function to check if a room requires a key
pub fn get_required_key(world: GameWorld, room_id: Int) -> Result(String, Nil) {
  let GameWorld(_, _, _, required_keys) = world
  dict.get(required_keys, room_id)
}

// Helper function to update a room in the world
pub fn update_room(world: GameWorld, room: Room) -> GameWorld {
  let GameWorld(rooms, enemies, exits, required_keys) = world
  let Room(id, _, _, _) = room
  GameWorld(dict.insert(rooms, id, room), enemies, exits, required_keys)
}

// Helper function to update an enemy in the world
pub fn update_enemy(
  world: GameWorld,
  room_id: Int,
  enemy: Result(Enemy, Nil),
) -> GameWorld {
  let GameWorld(rooms, enemies, exits, required_keys) = world

  let new_enemies = case enemy {
    Ok(e) -> dict.insert(enemies, room_id, e)
    Error(Nil) -> dict.delete(enemies, room_id)
  }

  GameWorld(rooms, new_enemies, exits, required_keys)
}

pub fn move_player(
  state: GameState,
  world: GameWorld,
  direction: Direction,
) -> #(GameState, GameWorld) {
  let GameState(player, game_over, won) = state
  let Player(name, health, max_health, inventory, current_room_id) = player

  // Get available exits for the current room
  let room_exits = get_exits(world, current_room_id)

  case dict.get(room_exits, direction) {
    // Exit exists in that direction
    Ok(target_room_id) -> {
      // Check if room requires a key
      case get_required_key(world, target_room_id) {
        Ok(key_name) -> {
          // Check if player has the key
          let has_key =
            list.any(inventory, fn(item) {
              case item {
                Key(name) -> name == key_name
                _ -> False
              }
            })

          case has_key {
            True -> {
              // Move to the room
              let new_player =
                Player(name, health, max_health, inventory, target_room_id)

              // Check for win condition
              let new_won = target_room_id == 5
              // Exit room ID

              #(GameState(new_player, game_over, new_won), world)
            }
            False -> {
              io.println("You need the " <> key_name <> " to enter this room.")
              #(state, world)
            }
          }
        }
        Error(Nil) -> {
          // No key required, move to the room
          let new_player =
            Player(name, health, max_health, inventory, target_room_id)
          #(GameState(new_player, game_over, won), world)
        }
      }
    }
    // No exit in that direction
    Error(Nil) -> {
      io.println("You cannot go that way.")
      #(state, world)
    }
  }
}

pub fn pick_up_item(
  state: GameState,
  world: GameWorld,
  item_name: String,
) -> #(GameState, GameWorld) {
  let GameState(player, game_over, won) = state
  let Player(name, health, max_health, inventory, current_room_id) = player

  let current_room = get_current_room(state, world)
  let Room(room_id, room_name, description, items) = current_room

  // Find the item in the room
  let item_result =
    list.find(items, fn(item) {
      case item {
        Weapon(item_name_, _) ->
          string.lowercase(item_name_) == string.lowercase(item_name)
        Potion(item_name_, _) ->
          string.lowercase(item_name_) == string.lowercase(item_name)
        Key(item_name_) ->
          string.lowercase(item_name_) == string.lowercase(item_name)
      }
    })

  case item_result {
    Ok(item) -> {
      // Add item to inventory
      let new_inventory = [item, ..inventory]

      // Remove item from room
      let new_items =
        list.filter(items, fn(i) {
          case i, item {
            Weapon(a, _), Weapon(b, _) -> a != b
            Potion(a, _), Potion(b, _) -> a != b
            Key(a), Key(b) -> a != b
            _, _ -> True
          }
        })

      let new_room = Room(room_id, room_name, description, new_items)
      let new_world = update_room(world, new_room)
      let new_player =
        Player(name, health, max_health, new_inventory, current_room_id)

      #(GameState(new_player, game_over, won), new_world)
    }
    Error(Nil) -> {
      io.println("There is no " <> item_name <> " here.")
      #(state, world)
    }
  }
}

pub fn use_item(
  state: GameState,
  world: GameWorld,
  item_name: String,
) -> #(GameState, GameWorld) {
  let GameState(player, game_over, won) = state
  let Player(name, health, max_health, inventory, current_room_id) = player

  // Find the item in inventory
  let item_result =
    list.find(inventory, fn(item) {
      case item {
        Weapon(item_name_, _) ->
          string.lowercase(item_name_) == string.lowercase(item_name)
        Potion(item_name_, _) ->
          string.lowercase(item_name_) == string.lowercase(item_name)
        _ -> False
      }
    })

  case item_result {
    Ok(item) -> {
      case item {
        Weapon(weapon_name, damage) -> {
          io.println(
            "You equip the "
            <> weapon_name
            <> " (Damage: "
            <> int.to_string(damage)
            <> ")",
          )
          // We don't track equipped weapons in this simplified version
          #(state, world)
        }
        Potion(potion_name, health_restore) -> {
          io.println(
            "You drink the "
            <> potion_name
            <> " and restore "
            <> int.to_string(health_restore)
            <> " health.",
          )

          // Remove potion from inventory
          let new_inventory =
            list.filter(inventory, fn(i) {
              case i {
                Potion(n, _) -> n != potion_name
                _ -> True
              }
            })

          // Restore health (up to max)
          let new_health = int.min(health + health_restore, max_health)
          let new_player =
            Player(name, new_health, max_health, new_inventory, current_room_id)

          #(GameState(new_player, game_over, won), world)
        }
        _ -> {
          io.println("You can't use that item right now.")
          #(state, world)
        }
      }
    }
    Error(Nil) -> {
      io.println("You don't have a " <> item_name <> " in your inventory.")
      #(state, world)
    }
  }
}

pub fn attack(state: GameState, world: GameWorld) -> #(GameState, GameWorld) {
  let GameState(player, game_over, won) = state
  let Player(name, health, max_health, inventory, current_room_id) = player

  case get_enemy(world, current_room_id) {
    Ok(enemy) -> {
      let Enemy(enemy_name, enemy_health, enemy_damage) = enemy

      // Calculate damage - in this simple version we'll just use a fixed value
      let weapon_damage = 5
      // Fixed damage for simplicity

      io.println(
        "You attack the "
        <> enemy_name
        <> " with "
        <> int.to_string(weapon_damage)
        <> " damage!",
      )

      let new_enemy_health = enemy_health - weapon_damage

      case new_enemy_health <= 0 {
        True -> {
          // Enemy defeated
          io.println("You defeated the " <> enemy_name <> "!")

          let new_world = update_enemy(world, current_room_id, Error(Nil))
          #(state, new_world)
        }
        False -> {
          // Enemy still alive, counter-attacks
          let new_enemy = Enemy(enemy_name, new_enemy_health, enemy_damage)
          io.println(
            "The "
            <> enemy_name
            <> " has "
            <> int.to_string(new_enemy_health)
            <> " health left and attacks you for "
            <> int.to_string(enemy_damage)
            <> " damage!",
          )

          let new_player_health = health - enemy_damage

          // Update world with wounded enemy
          let new_world = update_enemy(world, current_room_id, Ok(new_enemy))

          // Check if player died
          case new_player_health <= 0 {
            True -> {
              io.println("You have been defeated!")
              let new_player =
                Player(name, 0, max_health, inventory, current_room_id)
              #(GameState(new_player, True, won), new_world)
            }
            False -> {
              let new_player =
                Player(
                  name,
                  new_player_health,
                  max_health,
                  inventory,
                  current_room_id,
                )
              #(GameState(new_player, game_over, won), new_world)
            }
          }
        }
      }
    }
    Error(Nil) -> {
      io.println("There's nothing to attack here.")
      #(state, world)
    }
  }
}

// Display functions
pub fn display_room(state: GameState, world: GameWorld) -> Nil {
  let current_room = get_current_room(state, world)
  let Room(room_id, name, description, items) = current_room

  io.println("\n" <> name)
  io.println(string.repeat("-", string.length(name)))
  io.println(description)

  // Display items
  case items {
    [] -> Nil
    _ -> {
      io.println("\nItems in this room:")
      list.each(items, fn(item) {
        case item {
          Weapon(name, damage) ->
            io.println(
              "- " <> name <> " (Damage: " <> int.to_string(damage) <> ")",
            )
          Potion(name, health) ->
            io.println(
              "- " <> name <> " (Heals: " <> int.to_string(health) <> ")",
            )
          Key(name) -> io.println("- " <> name)
        }
      })
    }
  }

  // Display enemy
  case get_enemy(world, room_id) {
    Ok(enemy) -> {
      let Enemy(name, health, damage) = enemy
      io.println("\nEnemy:")
      io.println(
        "- "
        <> name
        <> " (Health: "
        <> int.to_string(health)
        <> ", Damage: "
        <> int.to_string(damage)
        <> ")",
      )
    }
    Error(Nil) -> Nil
  }

  // Display exits
  let exits = get_exits(world, room_id)
  io.println("\nExits:")
  dict.fold(exits, Nil, fn(_, direction, _) {
    case direction {
      North -> io.println("- North")
      South -> io.println("- South")
      East -> io.println("- East")
      West -> io.println("- West")
    }
  })
}

pub fn display_player(state: GameState) -> Nil {
  let GameState(player, _, _) = state
  let Player(name, health, max_health, inventory, _) = player

  io.println("\nPlayer Status:")
  io.println("Name: " <> name)
  io.println(
    "Health: " <> int.to_string(health) <> "/" <> int.to_string(max_health),
  )

  // Display inventory
  case inventory {
    [] -> io.println("Inventory: Empty")
    _ -> {
      io.println("Inventory:")
      list.each(inventory, fn(item) {
        case item {
          Weapon(name, damage) ->
            io.println(
              "- " <> name <> " (Damage: " <> int.to_string(damage) <> ")",
            )
          Potion(name, health) ->
            io.println(
              "- " <> name <> " (Heals: " <> int.to_string(health) <> ")",
            )
          Key(name) -> io.println("- " <> name)
        }
      })
    }
  }
}

pub fn display_help() -> Nil {
  io.println("\nCommands:")
  io.println("- look: Look around the room")
  io.println("- north/south/east/west: Move in a direction")
  io.println("- take [item]: Pick up an item")
  io.println("- use [item]: Use an item (equip weapon or drink potion)")
  io.println("- attack: Attack an enemy in the room")
  io.println("- inventory: Show your inventory")
  io.println("- status: Show your status")
  io.println("- help: Show this help message")
  io.println("- quit: Quit the game")
}

// Process user commands
pub fn process_command(
  state: GameState,
  world: GameWorld,
  command: String,
) -> #(GameState, GameWorld) {
  case string.lowercase(command) {
    "look" -> {
      display_room(state, world)
      #(state, world)
    }
    "north" -> move_player(state, world, North)
    "south" -> move_player(state, world, South)
    "east" -> move_player(state, world, East)
    "west" -> move_player(state, world, West)
    "inventory" | "inv" | "i" -> {
      display_player(state)
      #(state, world)
    }
    "status" | "stat" | "st" -> {
      display_player(state)
      #(state, world)
    }
    "attack" | "fight" -> attack(state, world)
    "help" -> {
      display_help()
      #(state, world)
    }
    _ -> {
      // Handle commands with arguments
      case string.split(command, " ") {
        ["take", item_name] -> pick_up_item(state, world, item_name)
        ["get", item_name] -> pick_up_item(state, world, item_name)
        ["pickup", item_name] -> pick_up_item(state, world, item_name)
        ["use", item_name] -> use_item(state, world, item_name)
        ["equip", item_name] -> use_item(state, world, item_name)
        ["drink", item_name] -> use_item(state, world, item_name)
        _ -> {
          io.println(
            "I don't understand that command. Type 'help' for a list of commands.",
          )
          #(state, world)
        }
      }
    }
  }
}

// Main game loop using recursion
pub fn game_loop(state: GameState, world: GameWorld) -> Nil {
  // For demonstration, we'll use a fixed command sequence
  // In a real application, you would use Erlang interop or compile to JavaScript
  // to get user input

  let demo_command = "look"
  // This would be user input in a real game
  io.print("\n> " <> demo_command <> "\n")

  // Since we can't get real input, just run one command and exit
  let #(new_state, new_world) = process_command(state, world, demo_command)

  // In a real game, this would check game status and continue the loop
  io.println("\nThis is a demo. In a real game, the loop would continue...")
}

pub fn main() -> Nil {
  io.println("Welcome to the Simple Dungeon Crawler!")
  io.println("(Note: This is a simplified version that shows basic structure)")

  // Use a hardcoded name since we can't get user input
  let player_name = "Adventurer"

  let #(initial_state, world) = create_game(player_name)

  io.println("\nWelcome, " <> player_name <> "! Your adventure begins...")
  io.println("Type 'help' for a list of commands.")

  display_room(initial_state, world)

  // Start the game loop
  game_loop(initial_state, world)

  io.println("\nThank you for trying the Gleam Dungeon Crawler demo!")
}
