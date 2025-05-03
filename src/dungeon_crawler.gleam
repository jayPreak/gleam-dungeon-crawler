// src/dungeon_crawler.gleam
// A simple text-based dungeon crawler game

import gleam/io
import gleam/string
import gleam/list
import gleam/int
import gleam/option.{Option, None, Some}
import gleam/map.{Map}

// Types
pub type Direction {
  North
  South
  East
  West
}

pub type Item {
  Weapon(name: String, damage: Int)
  Potion(name: String, health_restore: Int)
  Key(name: String)
}

pub type Enemy {
  Enemy(name: String, health: Int, damage: Int)
}

pub type Room {
  Room(
    id: Int,
    name: String,
    description: String,
    items: List(Item),
    enemy: Option(Enemy),
    exits: Map(Direction, Int),
    requires_key: Option(String),
  )
}

pub type Player {
  Player(
    name: String,
    health: Int,
    max_health: Int,
    inventory: List(Item),
    current_weapon: Option(Item),
    current_room_id: Int,
  )
}

pub type GameState {
  GameState(
    player: Player,
    rooms: Map(Int, Room),
    game_over: Bool,
    won: Bool,
  )
}

// Initialize the game world
pub fn create_game(player_name: String) -> GameState {
  let rusty_sword = Weapon("Rusty Sword", 5)
  let steel_sword = Weapon("Steel Sword", 10)
  let healing_potion = Potion("Healing Potion", 20)
  let dungeon_key = Key("Dungeon Key")
  let exit_key = Key("Exit Key")
  
  let goblin = Enemy("Goblin", 15, 3)
  let troll = Enemy("Troll", 30, 5)
  
  let entrance = Room(
    id: 1,
    name: "Dungeon Entrance",
    description: "A dark, damp room with stone walls. The entrance behind you is blocked by debris.",
    items: [rusty_sword],
    enemy: None,
    exits: map.from_list([#(East, 2), #(South, 3)]),
    requires_key: None,
  )
  
  let hallway = Room(
    id: 2,
    name: "Long Hallway",
    description: "A long, narrow hallway with flickering torches on the walls.",
    items: [healing_potion],
    enemy: Some(goblin),
    exits: map.from_list([#(West, 1), #(East, 4)]),
    requires_key: None,
  )
  
  let storage = Room(
    id: 3,
    name: "Storage Room",
    description: "A small room filled with broken furniture and empty crates.",
    items: [dungeon_key],
    enemy: None,
    exits: map.from_list([#(North, 1)]),
    requires_key: None,
  )
  
  let treasure = Room(
    id: 4,
    name: "Treasure Room",
    description: "A room glittering with gold coins and valuable artifacts.",
    items: [steel_sword, exit_key],
    enemy: Some(troll),
    exits: map.from_list([#(West, 2), #(North, 5)]),
    requires_key: Some("Dungeon Key"),
  )
  
  let exit = Room(
    id: 5,
    name: "Dungeon Exit",
    description: "A heavy iron door that leads to freedom.",
    items: [],
    enemy: None,
    exits: map.from_list([#(South, 4)]),
    requires_key: Some("Exit Key"),
  )
  
  let rooms = map.from_list([
    #(1, entrance),
    #(2, hallway),
    #(3, storage),
    #(4, treasure),
    #(5, exit),
  ])
  
  let player = Player(
    name: player_name,
    health: 50,
    max_health: 50,
    inventory: [],
    current_weapon: None,
    current_room_id: 1,
  )
  
  GameState(
    player: player,
    rooms: rooms,
    game_over: False,
    won: False,
  )
}

// Game logic functions
pub fn get_current_room(state: GameState) -> Room {
  map.get(state.rooms, state.player.current_room_id)
  |> option.unwrap(Room(
    id: 0,
    name: "Void",
    description: "You shouldn't be here...",
    items: [],
    enemy: None,
    exits: map.new(),
    requires_key: None,
  ))
}

pub fn move_player(state: GameState, direction: Direction) -> GameState {
  let current_room = get_current_room(state)
  
  case map.get(current_room.exits, direction) {
    // Exit exists in that direction
    Some(room_id) -> {
      let target_room = map.get(state.rooms, room_id)
      |> option.unwrap(current_room)
      
      // Check if room requires a key
      case target_room.requires_key {
        Some(key_name) -> {
          // Check if player has the key
          let has_key = list.any(
            state.player.inventory,
            fn(item) {
              case item {
                Key(name) if name == key_name -> True
                _ -> False
              }
            },
          )
          
          case has_key {
            True -> {
              // Move to the room
              let new_player = Player(
                ..state.player,
                current_room_id: room_id,
              )
              
              // Check for win condition
              let won = room_id == 5  // Exit room ID
              
              GameState(..state, player: new_player, won: won)
            }
            False -> {
              io.println("You need the " <> key_name <> " to enter this room.")
              state
            }
          }
        }
        None -> {
          // No key required, move to the room
          let new_player = Player(
            ..state.player,
            current_room_id: room_id,
          )
          GameState(..state, player: new_player)
        }
      }
    }
    // No exit in that direction
    None -> {
      io.println("You cannot go that way.")
      state
    }
  }
}

pub fn pick_up_item(state: GameState, item_name: String) -> GameState {
  let current_room = get_current_room(state)
  
  // Convert item_name to lowercase once
  let lowercase_item_name = string.lowercase(item_name)
  
  // Find the item in the room
  let item_result = list.find(
    current_room.items, 
    fn(item) {
      // Convert item name to lowercase once
      let lowercase_name = string.lowercase(item.name)
      case item {
        Weapon(name, _) if lowercase_name == lowercase_item_name -> True
        Potion(name, _) if lowercase_name == lowercase_item_name -> True
        Key(name) if lowercase_name == lowercase_item_name -> True
        _ -> False
      }
    },
  )
  
  case item_result {
    Some(item) -> {
      // Add item to inventory
      let new_inventory = [item, ..state.player.inventory]
      
      // Remove item from room
      let new_items = list.filter(
        current_room.items,
        fn(i) {
          case i, item {
            Weapon(a, _), Weapon(b, _) if a == b -> False
            Potion(a, _), Potion(b, _) if a == b -> False
            Key(a), Key(b) if a == b -> False
            _, _ -> True
          }
        },
      )
      
      let new_room = Room(..current_room, items: new_items)
      let new_rooms = map.insert(state.rooms, current_room.id, new_room)
      let new_player = Player(..state.player, inventory: new_inventory)
      
      GameState(..state, player: new_player, rooms: new_rooms)
    }
    None -> {
      io.println("There is no " <> item_name <> " here.")
      state
    }
  }
}

pub fn use_item(state: GameState, item_name: String) -> GameState {
  // Find the item in inventory
  let item_result = list.find(
    state.player.inventory,
    fn(item) {
      let lowercase_name = string.lowercase(item.name)
      case item {
        Weapon(name, _) if lowercase_name == lowercase_item_name -> True
        Potion(name, _) if lowercase_name == lowercase_item_name -> True
        _ -> False
      }
    },
  )
  
  case item_result {
    Some(item) -> {
      case item {
        Weapon(name, damage) -> {
          io.println("You equip the " <> name <> " (Damage: " <> int.to_string(damage) <> ")")
          let new_player = Player(..state.player, current_weapon: Some(item))
          GameState(..state, player: new_player)
        }
        Potion(name, health) -> {
          io.println("You drink the " <> name <> " and restore " <> int.to_string(health) <> " health.")
          
          // Remove potion from inventory
          let new_inventory = list.filter(
            state.player.inventory,
            fn(i) {
              case i {
                Potion(n, _) if n == name -> False
                _ -> True
              }
            },
          )
          
          // Restore health (up to max)
          let new_health = int.min(state.player.health + health, state.player.max_health)
          let new_player = Player(
            ..state.player,
            health: new_health,
            inventory: new_inventory,
          )
          
          GameState(..state, player: new_player)
        }
        _ -> {
          io.println("You can't use that item right now.")
          state
        }
      }
    }
    None -> {
      io.println("You don't have a " <> item_name <> " in your inventory.")
      state
    }
  }
}

pub fn attack(state: GameState) -> GameState {
  let current_room = get_current_room(state)
  
  case current_room.enemy {
    Some(enemy) -> {
      // Calculate damage
      let weapon_damage = case state.player.current_weapon {
        Some(Weapon(_, damage)) -> damage
        _ -> 2  // Unarmed damage
      }
      
      io.println("You attack the " <> enemy.name <> " with " <> int.to_string(weapon_damage) <> " damage!")
      
      let new_enemy_health = enemy.health - weapon_damage
      
      case new_enemy_health <= 0 {
        True -> {
          // Enemy defeated
          io.println("You defeated the " <> enemy.name <> "!")
          
          let new_room = Room(..current_room, enemy: None)
          let new_rooms = map.insert(state.rooms, current_room.id, new_room)
          
          GameState(..state, rooms: new_rooms)
        }
        False -> {
          // Enemy still alive, counter-attacks
          let new_enemy = Enemy(..enemy, health: new_enemy_health)
          io.println(
            "The " <> enemy.name <> " has " <> int.to_string(new_enemy_health) <> 
            " health left and attacks you for " <> int.to_string(enemy.damage) <> " damage!"
          )
          
          let new_player_health = state.player.health - enemy.damage
          
          // Update room with wounded enemy
          let new_room = Room(..current_room, enemy: Some(new_enemy))
          let new_rooms = map.insert(state.rooms, current_room.id, new_room)
          
          // Check if player died
          case new_player_health <= 0 {
            True -> {
              io.println("You have been defeated!")
              let new_player = Player(..state.player, health: 0)
              GameState(..state, player: new_player, rooms: new_rooms, game_over: True)
            }
            False -> {
              let new_player = Player(..state.player, health: new_player_health)
              GameState(..state, player: new_player, rooms: new_rooms)
            }
          }
        }
      }
    }
    None -> {
      io.println("There's nothing to attack here.")
      state
    }
  }
}

// Display functions
pub fn display_room(room: Room) -> Nil {
  io.println("\n" <> room.name)
  io.println(string.repeat("-", string.length(room.name)))
  io.println(room.description)
  
  // Display items
  case room.items {
    [] -> Nil
    items -> {
      io.println("\nItems in this room:")
      list.each(
        items,
        fn(item) {
          case item {
            Weapon(name, damage) -> io.println("- " <> name <> " (Damage: " <> int.to_string(damage) <> ")")
            Potion(name, health) -> io.println("- " <> name <> " (Heals: " <> int.to_string(health) <> ")")
            Key(name) -> io.println("- " <> name)
          }
        },
      )
    }
  }
  
  // Display enemy
  case room.enemy {
    Some(enemy) -> {
      io.println("\nEnemy:")
      io.println(
        "- " <> enemy.name <> " (Health: " <> int.to_string(enemy.health) <> 
        ", Damage: " <> int.to_string(enemy.damage) <> ")"
      )
    }
    None -> Nil
  }
  
  // Display exits
  io.println("\nExits:")
  map.fold(
    room.exits,
    Nil,
    fn(_, direction, _) {
      case direction {
        North -> io.println("- North")
        South -> io.println("- South")
        East -> io.println("- East")
        West -> io.println("- West")
      }
    },
  )
}

pub fn display_player(player: Player) -> Nil {
  io.println("\nPlayer Status:")
  io.println("Name: " <> player.name)
  io.println("Health: " <> int.to_string(player.health) <> "/" <> int.to_string(player.max_health))
  
  // Display weapon
  case player.current_weapon {
    Some(Weapon(name, damage)) -> io.println("Weapon: " <> name <> " (Damage: " <> int.to_string(damage) <> ")")
    _ -> io.println("Weapon: Unarmed (Damage: 2)")
  }
  
  // Display inventory
  case player.inventory {
    [] -> io.println("Inventory: Empty")
    items -> {
      io.println("Inventory:")
      list.each(
        items,
        fn(item) {
          case item {
            Weapon(name, damage) -> io.println("- " <> name <> " (Damage: " <> int.to_string(damage) <> ")")
            Potion(name, health) -> io.println("- " <> name <> " (Heals: " <> int.to_string(health) <> ")")
            Key(name) -> io.println("- " <> name)
          }
        },
      )
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

// Main game loop
pub fn process_command(state: GameState, command: String) -> GameState {
  let lowercase_command = string.lowercase(command)
  
  case lowercase_command {
    "look" -> {
      display_room(get_current_room(state))
      state
    }
    "north" -> move_player(state, North)
    "south" -> move_player(state, South)
    "east" -> move_player(state, East)
    "west" -> move_player(state, West)
    "inventory" | "inv" | "i" -> {
      display_player(state.player)
      state
    }
    "status" | "stat" | "st" -> {
      display_player(state.player)
      state
    }
    "attack" | "fight" -> attack(state)
    "help" -> {
      display_help()
      state
    }
    _ -> {
      // Handle commands with arguments
      case string.split(command, " ") {
        ["take", item_name] -> pick_up_item(state, item_name)
        ["get", item_name] -> pick_up_item(state, item_name)
        ["pickup", item_name] -> pick_up_item(state, item_name)
        ["use", item_name] -> use_item(state, item_name)
        ["equip", item_name] -> use_item(state, item_name)
        ["drink", item_name] -> use_item(state, item_name)
        _ -> {
          io.println("I don't understand that command. Type 'help' for a list of commands.")
          state
        }
      }
    }
  }
}

pub fn main() -> Nil {
  io.println("Welcome to the Dungeon Crawler!")
  io.println("What is your name, brave adventurer?")
  
  let player_name = io.get_line()
  |> string.trim
  
  let initial_state = create_game(player_name)
  
  io.println("\nWelcome, " <> player_name <> "! Your adventure begins...")
  io.println("Type 'help' for a list of commands.")
  
  display_room(get_current_room(initial_state))
  
  // A recursive game loop function that takes and returns the current state
  fn game_loop(state: GameState) -> Nil {
    io.print("\n> ")
    let command = io.get_line()
    |> string.trim
    
    case string.lowercase(command) {
      "quit" | "exit" -> {
        io.println("Thanks for playing!")
        Nil
      }
      _ -> {
        let new_state = process_command(state, command)
        
        // Check game over conditions
        case new_state.game_over {
          True -> {
            io.println("\nGame Over!")
            Nil
          }
          False -> {
            case new_state.won {
              True -> {
                io.println("\nCongratulations! You've escaped the dungeon!")
                Nil
              }
              False -> game_loop(new_state)
            }
          }
        }
      }
    }
  }
  
  // Start the game loop with the initial state
  game_loop(initial_state)
}