# cgvR

Interactive 3D visualization of very large Cayley graphs via Vulkan.

## Overview

Cayley graphs of permutation puzzles (like TopSpin) can have millions of nodes — far too many to render at once. **cgvR** solves this by rendering only the visible neighborhood on the fly: starting from a focus node, it expands up to N hops (default 10) and draws only that subgraph in 3D using GPU-accelerated Vulkan rendering.

### Key features

- **Fly-through navigation** — move a 3D camera over the graph in real time
- **Dynamic visibility zone** — only nodes within N hops of the camera focus are rendered
- **Path highlighting** — visualize paths between nodes (e.g. puzzle solutions)
- **Pure Vulkan rendering** — all graphics via Datoviz, no OpenGL dependency
- **GPU compute** — layout calculations and graph operations on Vulkan via ggmlR

## Dependencies

| Package | Role |
|---------|------|
| [cayleyR](https://github.com/Zabis13/cayleyR) | Cayley graph construction, BFS, pathfinding |
| [ggmlR](https://github.com/Zabis13/ggmlR) | Vulkan GPU backend (device init, compute) |
| [Datoviz](https://datoviz.org) | Vulkan-based scientific visualization (vendored C sources) |

### System requirements

- Vulkan SDK (`libvulkan-dev` + `glslc` on Linux)
- GLFW3 (`libglfw3-dev` on Linux)
- C17 compiler

## Installation

```r
# Install dependencies first
# install.packages("remotes")
remotes::install_github("Zabis13/cayleyR")
remotes::install_github("Zabis13/ggmlR")

# Install cgvR
remotes::install_github("Zabis13/cgvR")
```

## Quick start

```r
library(cgvR)

# Check GPU
cgv_gpu_status()

# Create viewer
v <- cgv_viewer(1280, 720, "TopSpin Cayley Graph")

# Load graph from cayleyR
library(cayleyR)
# ... build graph ...

# Set graph data (nodes, edges, optional 3D positions)
cgv_set_graph(v, nodes, edges)

# Configure visibility depth
cgv_set_visibility(v, depth = 10)

# Set camera
cgv_camera(v, position = c(0, 5, 20), target = c(0, 0, 0))

# Highlight a solution path
cgv_highlight_path(v, path = c(1, 42, 137, 500), color = "#FF0000")

# Fly to a specific node
cgv_fly_to(v, node_id = 42, duration = 1.5)

# Run event loop (blocks until window closed)
cgv_run(v)
```

## Architecture

```
R API  →  .Call  →  C layer  →  Datoviz (Vulkan visuals)
  ↕                    ↕
cayleyR (graph ops)   ggmlR (Vulkan device, GPU compute)
```

## Сборка и линковка

Datoviz линкуется **статически** (`libdatoviz.a`) — весь код Datoviz, cglm и GLFW
встраивается прямо в `cgvR.so`. Это означает:

- Не нужна системная установка Datoviz
- `devtools::test()` и `devtools::load_all()` работают без проблем
- Единственная внешняя runtime-зависимость — `libvulkan.so` (Vulkan SDK)

### Как собирается libdatoviz.a

```bash
# 1. Клонировать datoviz с submodules (data, imgui)
git clone --recursive https://github.com/datoviz/datoviz.git datoviz-git
cd datoviz-git

# Если submodule data не скачался (SSH → HTTPS):
git config submodule.data.url https://github.com/datoviz/data.git
git submodule update --init --recursive

# 2. Собрать с cmake (Release, PIC обязателен для .a → .so)
mkdir build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DDATOVIZ_WITH_CLI=OFF \
  -DDATOVIZ_WITH_MSDF=OFF \
  -DDATOVIZ_WITH_ZLIB=OFF \
  -DDATOVIZ_WITH_QT=OFF \
  -DDATOVIZ_WITH_SHADERC=OFF
make -j$(nproc)

# 3. Собрать статический архив из всех объектных файлов
find CMakeFiles/datoviz_core.dir \
     CMakeFiles/datoviz_requests.dir \
     CMakeFiles/datoviz_app.dir \
     CMakeFiles/datoviz_scene.dir \
     CMakeFiles/datoviz_resources.dir \
     CMakeFiles/external_sources.dir \
     -name "*.o" > objects.txt
ar rcs libdatoviz.a $(cat objects.txt)

# 4. Скопировать в cgvR
cp libdatoviz.a                        /path/to/cgvR/inst/lib/
cp _deps/cglm-build/libcglm.a         /path/to/cgvR/inst/lib/
cp _deps/glfw-build/src/libglfw3.a    /path/to/cgvR/inst/lib/
```

### Схема линковки

```
cgvR.so
  ├── init.o, cgv_viewer.o, cgv_graph.o, cgv_camera.o, visibility.o  (наш код)
  ├── libdatoviz.a  (--whole-archive: core + scene + app + resources + imgui)
  ├── libcglm.a     (математика: vec3, mat4, ...)
  ├── libglfw3.a    (окно + ввод)
  └── -lvulkan      (системная, единственная runtime-зависимость)
```

### configure

Скрипт `configure` (запускается автоматически при `R CMD INSTALL`):
- Проверяет наличие `libdatoviz.a`, `libcglm.a`, `libglfw3.a` в `inst/lib/`
- Определяет Vulkan через `pkg-config`
- Генерирует `src/Makevars` из `src/Makevars.in`

## License

MIT
