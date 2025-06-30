# Game Project Overview

This is a card-based game project developed using the [Godot Engine](https://godotengine.org/), which includes complete scene construction, character control, card system, background management, as well as partial UI animations and transition effects.

## Project Structure Overview

- **Picture/**: Stores image resources required for the game, including backgrounds, characters, cards, and items.
- **Resource/Card/**: Card resource definition files (in `.tres` format).
- **Script/**: Game logic scripts, divided into modules such as `Class`, `Global`, and `Node`.
  - `Class/`: Core class definitions, such as Player, Card, Area, and System.
  - `Global/`: Global management scripts, such as Console, RPC Management, and UI Animation.
  - `Node/`: Scene node scripts used to control specific game interfaces and interactions.
- **tscn/**: Godot scene files (`.tscn`), including the main game interface, menus, card display, and more.
- **addons/godot-git-plugin/**: Git plugin support for version control integration.

## Key Functional Modules

- **Card System**: Supports basic card behaviors such as attack and laser, implemented via `Class_Card.gd` and related scenes.
- **Area Control**: Includes hand area, battle area, discard area, etc., managed by classes like `Class_AreaHand.gd` and `Class_AreaAttack.gd`.
- **Player and System**: Player status, system configuration, and global RPC management are implemented through `Class_Player.gd`, `Class_System.gd`, `global_rpcManager.gd`, and others.
- **UI and Animation**: Scene transitions and animation effects are handled by `global_uiAnimation.gd` and `Transition.gd`.
- **Background and Effects**: Background images and shaders (e.g., `shader_wave.gd`, `shader_lights.gd`) are used for visual enhancement.

## Development Environment and Dependencies

- **Godot Engine**: The project is developed using Godot 4.x; ensure you use a compatible version to open it.
- **Git Plugin**: The project integrates `godot-git-plugin` for version control.

## How to Run the Project

1. Install [Godot 4.x](https://godotengine.org/download/).
2. Clone this repository to your local machine.
3. Open the project directory in Godot and run it.

## Contribution Guidelines

Feel free to submit Issues and Pull Requests. Please follow the existing code style of the project and ensure that any new features pass basic tests.

## License

This project follows the MIT License. Please refer to the `LICENSE` file for detailed information.

For further details on the functionality or implementation of specific modules, please refer to the corresponding `.gd` scripts or `.tscn` scene files.