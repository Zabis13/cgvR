# cgvR

Interactive 3D visualization of large Cayley and state-space graphs via Vulkan.

## Overview

Cayley graphs of permutation puzzles (TopSpin, Rubik's cube, etc.) and game
state graphs can have millions of nodes — far too many to render at once.
**cgvR** provides GPU-accelerated 3D rendering on top of the
[Datoviz](https://datoviz.org) Vulkan engine, plus force-directed layout and
camera/path animation utilities for exploring such graphs interactively.

### Key features

- **Vulkan rendering** of nodes (points) and edges (segments), driven by Datoviz.
- **Layout algorithms**: Fruchterman-Reingold in pure R (`cgv_layout_fr`) and
  a Barnes-Hut O(n log n) version in C (`cgv_layout_fr_bh`) for large graphs.
- **Camera control**: fly (WASD + mouse), orbit, arcball; `cgv_fly_to` to a
  node and `cgv_fly_path` along a Catmull-Rom spline of waypoints.
- **Path highlighting** with custom colors, node scale and edge width.
- **Video recording** via ffmpeg pipe (`cgv_record_start` / `cgv_record_stop`).
- **Headless mode** (`cgv_viewer(..., offscreen = TRUE)`) for tests and
  scripted offline rendering.

## Dependencies

| Package | Role |
|---------|------|
| [cayleyR](https://github.com/Zabis13/cayleyR) | Optional — Cayley graph construction, BFS, pathfinding |

### System requirements

- Vulkan SDK (`libvulkan-dev` + `glslc` on Linux)
- GLFW3 (`libglfw3-dev` on Linux)
- C17 compiler, `pkg-config`, GNU make
- `ffmpeg` on `PATH` (only for `cgv_record_*`)

## Installation

```r
# install.packages("remotes")
remotes::install_github("Zabis13/cgvR")

# Optional: enable SIMD acceleration for fpng (PNG screenshots).
# Disabled by default for portability. Requires SSE4.1 + PCLMUL.
remotes::install_github("Zabis13/cgvR", configure.args = "--with-simd")
```

## Quick start

```r
library(cgvR)

# Build a small graph
n <- 100L
edges <- cbind(sample.int(n, 200, replace = TRUE),
               sample.int(n, 200, replace = TRUE))

# Force-directed 3D layout
pos <- cgv_layout_fr(n, edges, n_iter = 200L, seed = 1L)

# Open a viewer and upload the graph
v <- cgv_viewer(1280, 720, "cgvR demo")
cgv_background(v, "black")
cgv_set_graph(v, 1:n, edges,
              positions   = pos,
              node_values = as.double(seq_len(n)),
              node_sizes  = rep(8, n))

# Highlight a path
cgv_highlight_path(v, c(1, 5, 17, 42), color = "#FF2200",
                   node_scale = 1.6, edge_width = 3.0)

# Camera + run loop (right-click drag = rotate, scroll = zoom)
cgv_camera(v, position = c(20, 16, 24), target = c(0, 0, 0))
cgv_run(v)
```

More examples in `inst/examples/`:

- `demo_small_graph.R` — random 100-node graph with FR layout.
- `demo_cycles_bh.R` — TopSpin cycles, Barnes-Hut FR layout.
- `demo_tictactoe.R` — Tic-Tac-Toe game graph, color = move number.
- `demo_record.R`, `demo_cycles_bh_record.R` — video recording.

## Architecture

```
R API  →  .Call  →  C layer  →  Datoviz (Vulkan visuals)
                                  ↕
                              cayleyR (optional graph ops)
```

Datoviz, cglm and GLFW are compiled from sources bundled in `src/` and linked
statically into `cgvR.so`. The only external runtime dependency is
`libvulkan.so`.

### configure flags

- `--with-simd` — enable SSE4.1 + PCLMUL for `fpng` (faster PNG screenshots).
  Pass via `R CMD INSTALL --configure-args="--with-simd" .` or
  `install.packages(..., configure.args = "--with-simd")`.

## License

MIT
