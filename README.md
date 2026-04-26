# cgvR

[![R-hub check on the R Consortium cluster](https://github.com/r-hub2/separate-jaguar-cgvR/actions/workflows/rhub-rc.yaml/badge.svg)](https://github.com/r-hub2/separate-jaguar-cgvR/actions/workflows/rhub-rc.yaml)

Interactive 3D visualization of large Cayley and state-space graphs via Vulkan.

https://github.com/Zabis13/cgvR/releases/download/0.1.2/cgvr_cycles.mp4


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

Supported operating systems (matches Datoviz upstream):

* **Linux x86_64** — Ubuntu 22.04 or later (glibc 2.34+).
* **macOS 12 or later** — x86_64 and arm64 (Apple silicon M1–M4).
* **Windows 10 or later** — x86_64.

Vulkan support is **auto-detected** at install time. If the dependencies are
missing, the package falls back to a stub build (see below).

**Ubuntu / Debian** — to enable full rendering:
```bash
sudo apt install libvulkan-dev libglfw3-dev pkg-config build-essential \
                 mesa-vulkan-drivers
# Optional, only for cgv_record_*:
sudo apt install ffmpeg
```

Shaders and `cglm` headers are bundled — no need for `glslc` or `cmake`.
Tested on Ubuntu 22.04+ (matches upstream Datoviz: glibc 2.34+).

**Windows** — install [Rtools](https://cran.r-project.org/bin/windows/Rtools/)
and the [LunarG Vulkan SDK](https://vulkan.lunarg.com/sdk/home#windows).
Make sure the `VULKAN_SDK` environment variable is set before `R CMD INSTALL`.
Internet access during install is required — `configure.win` downloads the
prebuilt `datoviz.dll` from GitHub releases (cached in `inst/lib/` afterwards).
Optional: `ffmpeg.exe` on `PATH` for `cgv_record_*`.

**macOS 12 or later (x86_64 and arm64)** — install dependencies via Homebrew
plus the LunarG Vulkan SDK (which ships MoltenVK):
```bash
brew install glfw pkg-config
# Then install LunarG Vulkan SDK from
#   https://vulkan.lunarg.com/sdk/home#mac
# and 'export VULKAN_SDK=...' before R CMD INSTALL.
```
configure auto-detects `Darwin` (sets `OS_MACOS=1`, links against the
system MoltenVK loader, applies `-mmacosx-version-min=12.0`). GLFW pulls
the required Cocoa / IOKit / CoreFoundation frameworks via its own
`pkg-config --libs glfw3`.

A working **Vulkan GPU driver** is required at runtime regardless of platform
(Mesa / NVIDIA / AMD on Linux, vendor driver on Windows, MoltenVK on macOS).

### Build options

Force or skip the native build:
```r
install.packages("cgvR", configure.args = "--with-vulkan")     # require Vulkan; error if missing
install.packages("cgvR", configure.args = "--without-vulkan")  # always stub build
```

Enable SIMD acceleration for `fpng` PNG screenshots (SSE4.1 + PCLMUL on x86):
```r
install.packages("cgvR", configure.args = "--with-simd")
```

Combine flags as needed:
```r
install.packages("cgvR", configure.args = "--with-vulkan --with-simd")
```

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

### Stub build (no Vulkan)

If Vulkan or GLFW are missing at install time (or you pass `--without-vulkan`),
cgvR falls back to a **stub build**: only a tiny C file is compiled, the
package installs cleanly, and all rendering APIs (`cgv_viewer`, `cgv_run`, …)
raise an informative error when called. Pure-R helpers like `cgv_layout_fr()`
keep working. Use `cgv_is_stub_build()` to detect this mode at runtime.

## License

MIT
