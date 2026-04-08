# Project: 2D Fighting Game Prototype (Godot 4)

## Architecture & Standards

### Physics & Timing
- **Engine:** Godot 4.x
- **Physics FPS:** 60 (Standard for fighting games)
- **Movement:** Delta-based logic using `move_and_slide()`
- **Scaling:** Never scale the root `CharacterBody2D`. Use a `Visuals` (Node2D) child for horizontal flipping to avoid physics jitter.

### Combat System (Frame Data)
Frame data logic is calculated based on a 60 FPS update cycle. 
- **Startup:** Frames before the hitbox is active.
- **Active:** Frames where the hitbox is active.
- **Recovery:** Frames where the player is vulnerable and cannot act.
- **Hitstun:** Fixed duration (18 frames) the victim remains in the `HIT` state.

### State Machine
Every player MUST adhere to the following states:
1. `IDLE`: Default standing state.
2. `WALK`: Horizontal movement.
3. `JUMP`: Ascending phase.
4. `FALL`: Descending phase.
5. `ATTACK`: Frame-data driven combat state.
6. `HIT`: Stunned state after taking damage.
7. `KNOCKDOWN`: Forced ground state before recovery.
8. `DEAD`: Terminal state (HP <= 0).
9. `RAGDOLL`: Physics-driven death simulation using `PhysicalBone2D`.

### Input Configuration
- **Player 1:** A (Left), D (Right), W (Jump), F (Attack).
- **Player 2:** Left Arrow, Right Arrow, Up Arrow, L (Attack).

## Implementation Details

### Ragdoll Transition
On death, the `CharacterBody2D` collision and logic are disabled. The `Skeleton2D` children (PhysicalBone2D) must have `simulate_physics` enabled to trigger the ragdoll effect.

### Camera Behavior
The `Camera2D` follows the midpoint between both players. Zoom levels must interpolate between `1.5` (close) and `0.8` (wide) based on the distance between players, clamped to arena bounds.

## Memory & Preferences
- Use `is_physical_key_pressed` for input to bypass project settings dependencies.
- Keep the `Hitbox` and `Hurtbox` on separate collision layers (Layer 1 for P1, Layer 2 for P2) to prevent players from hitting themselves.
