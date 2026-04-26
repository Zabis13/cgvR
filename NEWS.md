# cgvR 0.1.2

- `cgv_layout_fr()` — Fruchterman-Reingold layout in 2D/3D (pure R).
- `cgv_layout_fr_bh()` — Barnes-Hut FR (O(n log n)) in C for large graphs.
- `cgv_camera_mode()` — switch camera mode (fly / orbit / arcball).
- `cgv_fly_path()` — animate camera along waypoints (Catmull-Rom spline).
- `cgv_record_start()` / `cgv_record_stop()` — video recording via ffmpeg pipe.
- `cgv_is_stub_build()` — TRUE when the package was installed without
  Vulkan / GLFW (stub build). Native APIs raise a clear error in that case.
- New `configure` flags `--with-vulkan` / `--without-vulkan` to force or
  skip the native rendering build (mirrors ggmlR's flag style).
- macOS support: `configure` auto-detects Darwin, sets `OS_MACOS=1`,
  picks Vulkan from `VULKAN_SDK/macOS/`, `VULKAN_SDK/`, or Homebrew
  (`/opt/homebrew/lib`, `/usr/local/lib`), and applies
  `-mmacosx-version-min=12.0`.

# cgvR 0.1.1

- `cgv_viewer()` gains `offscreen` argument for headless mode.

# cgvR 0.1.0

Initial development release.

- `cgv_viewer()`, `cgv_close()` — viewer creation and destruction.
- `cgv_camera()`, `cgv_fly_to()` — camera positioning and animation.
- `cgv_set_graph()` — load nodes, edges and 3D positions.
- `cgv_set_visibility()` — BFS visibility-zone control.
- `cgv_highlight_path()`, `cgv_clear_path()` — path highlighting.
- `cgv_background()` — background color.
- `cgv_run()` — render loop.
