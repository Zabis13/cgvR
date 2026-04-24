# cgvR 0.1.0

Initial development release.

## Features

- Project structure with R/.Call/C architecture
- Viewer creation/destruction with finalizer (`cgv_viewer`, `cgv_close`)
- Camera positioning and fly-to animation API (`cgv_camera`, `cgv_fly_to`)
- Graph data loading with optional 3D positions (`cgv_set_graph`)
- Visibility depth control (`cgv_set_visibility`)
- Path highlighting (`cgv_highlight_path`)
- GPU initialization via ggmlR Vulkan backend (`cgv_gpu_init`, `cgv_gpu_status`)
- Event loop stub (`cgv_run`)

## Notes

- All C functions are stubs printing to console; Datoviz integration pending
- Depends on cayleyR for graph operations, ggmlR for Vulkan device management
