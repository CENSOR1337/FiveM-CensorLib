# censorlib for FiveM

`censorlib` is a comprehensive Lua library designed to streamline and enhance script development for FiveM, the multiplayer modification framework for Grand Theft Auto V. It provides a wide array of pre-built functions, classes, and utilities, targeting the FXServer environment and built specifically for **Lua 5.4**.

Whether you're developing complex game modes or simple utility scripts, `censorlib` aims to provide robust, reusable components to accelerate your development process and improve code quality.

## Features / Core Components

`censorlib` offers a rich set of modules to help with common scripting tasks. Here's a glimpse of what's included:

*   **Async:** Utilities for managing asynchronous operations.
*   **Callback:** System for remote callbacks between server and client.
*   **Color:** Tools for creating and converting color representations (RGB, RGBA, HEX).
*   **Colshape:** Classes for creating and managing various collision shapes (Circle, Sphere, Polygon).
*   **Common:** A collection of broadly applicable helper functions.
*   **Curve2D:** Functionality for creating and evaluating 2D curves (Linear, Bezier, Constant).
*   **Delegate:** A delegate system for event management and broadcasting.
*   **Entity:** Unified interface for creating and managing game entities (vehicles, peds, objects).
*   **Keybind (Client-only):** Management of client-side keybinds and event handling.
*   **Locale:** Localization and translation of strings using JSON dictionaries.
*   **Map:** An ordered map (dictionary) data structure where keys maintain insertion order.
*   **Math:** Extended mathematical utility functions (lerp, clamp, round, etc.).
*   **NUI (Client-only):** Interaction management with the NUI interface.
*   **Periodic:** Management of functions to be executed periodically.
*   **Print:** Leveled and formatted printing utility for the console, controllable via convar.
*   **Random:** Utilities for generating random strings and Version 4 UUIDs.
*   **RandSet (Chance Pool):** Create collections of items with associated chances for random selection.
*   **Resource:** Interaction with FiveM resources, including event handling scoped to specific resources.
*   **Set:** A Set data structure for managing unordered collections of unique items.
*   **Streaming (Client-only):** Client-side asset streaming management (models, animations, textures, etc.).
*   **Timer:** Creation and management of timers for delayed or repeated execution of functions.
*   **Validate:** Data validation utilities, primarily focused on type checking.

Detailed information on each component and its API can be found in the API Documentation.

## Requirements

*   **Lua 5.4:** Your FiveM server resource manifest files must be configured to use Lua 5.4.
    Example `fxmanifest.lua`:
    ```lua
    fx_version 'cerulean'
    game 'gta5'
    lua54 'yes' -- Ensure this line is present and set to 'yes'
    ```

## Installation

1.  **Download `censorlib`:** Obtain the latest version of `censorlib`. This usually involves cloning the repository or downloading a release.
2.  **Place in Resources:** Put the `censorlib` directory into your server's `resources` folder (e.g., alongside other script resources).
3.  **Add to Manifest:** To use `censorlib` in your FiveM resource, add the following line to your resource's manifest file (e.g., `fxmanifest.lua` or `__resource.lua`):

    ```lua
    shared_script "@censorlib/imports.lua"
    ```

    Ensure that `censorlib` is started before any resources that depend on it in your `server.cfg` file, or manage dependencies using the manifest's `dependency` directive if necessary. For example, in your `server.cfg`:
    ```cfg
    ensure censorlib
    ensure your_other_resource
    ```

## Basic Usage / Getting Started

Once installed, `censorlib` functions and components are accessible through the global `lib` table within any script that includes the `imports.lua`.

Here's a small example demonstrating how to use some of its features:

```lua
-- This code would typically be in a client_script or server_script of your resource.

-- Accessing a component (e.g., the math component)
local round = lib.math.round
local num = 3.14159
-- Using the custom print component to show the math result, which also prefixes with your resource name.
lib.print.info(string.format("Original: %f, Rounded to 2 places: %s", num, round(num, 2)))
-- Expected output (console): [your_resource_name] [INFO] Original: 3.141590, Rounded to 2 places: 3.14

-- Using another utility (e.g., print component directly)
lib.print.warn("This is a warning message from your_resource_name using censorlib!")
-- Expected output (console): [your_resource_name] [WARN] This is a warning message from your_resource_name using censorlib!

-- Example of creating a timer (client or server script)
local myTimer = lib.timer.new(function()
    lib.print.debug("Timer fired after 2 seconds!")
end, 2000, false) -- handler, delay_ms, is_looping (false for one-shot)

-- lib.print functions are safe to use; they respect the 'your_resource_name:print_level' convar.
-- Default print level is 'info'. To see debug or verbose messages, set the convar in your server console or server.cfg:
-- setr your_resource_name:print_level debug
-- (Replace 'your_resource_name' with the actual name of the resource using lib.print)
```

## API Documentation

`censorlib` uses LDoc to generate comprehensive API documentation from its source code comments.

To generate the documentation locally:

1.  Ensure you have Node.js and npm installed.
2.  Navigate to the `censorlib` root directory in your terminal.
3.  Run the command:
    ```bash
    npm run docs
    ```
4.  This will process the Lua files and generate HTML documentation. You can find the main page typically at `doc/index.html` (or `doc/docs.html` depending on LDoc's output configuration for the project). Check the `doc` folder after generation.

This documentation provides detailed information about each module, class, function, their parameters, return values, and usage examples.

## Community & Support

Join our community for discussions, support, and updates:

*   **Discord:** [https://discord.gg/GgZy5kRmFw](https://discord.gg/GgZy5kRmFw)

We welcome contributions and feedback to make `censorlib` even better!