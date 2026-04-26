## Initial submission (0.1.1)

This is the first CRAN submission of cgvR — an R package for interactive
3D visualization of large Cayley graphs via Vulkan. It wraps the bundled
Datoviz C library (statically compiled from sources, with ImGui and
GLFW3 system library) for GPU-accelerated rendering.

## R CMD check results

0 errors | 0 warnings | a few notes (see below)

* **installed package size**: The package bundles the full Datoviz
  rendering library (Vulkan visuals, scene graph, ImGui integration)
  compiled from sources. The size is inherent to the C/C++ codebase
  required for hardware-accelerated 3D rendering.

* **GNU make is a SystemRequirements**: GNU make is listed in
  SystemRequirements and is needed for the build.

* **non-standard compilation flag (-mpclmul)**: SIMD acceleration for the
  bundled fpng PNG encoder is *disabled by default* (CRAN-portable
  scalar fallback via -DFPNG_NO_SSE=1). End users may opt in with
  `install.packages("cgvR", configure.args = "--with-simd")`, which
  detects -msse4.1 / -mpclmul at configure time.

## Stdout / stderr / exit handling

The bundled third-party C/C++ code (Datoviz, ImGui, fpng, b64) has been
audited for direct uses of stdio and exit:

* All Datoviz C sources are compiled with `-include cgv_r_compat.h`,
  which redirects `printf`, `fprintf`, `fputs`, `stdout`, `stderr`,
  `exit`, and `abort` to R-safe wrappers (`Rprintf`, `REprintf`,
  `Rf_error`).
* ImGui sources are compiled with `IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS`,
  `IMGUI_DISABLE_FILE_FUNCTIONS`, `IMGUI_DEBUG_PRINTF` defined to a no-op,
  and `IM_ASSERT` defined to a no-op, so that the linked object contains
  no references to `printf`, `stdout`, `stderr`, `exit`, or `__assert_fail`.
* `nm -u cgvR.so` confirms that no forbidden libc symbols are imported
  from the bundled code.

## Tests on CRAN

The test suite uses an opt-in heavy/light split via the `NOT_CRAN`
environment variable (same pattern used by ggmlR). On CRAN, only light
tests run — those that do not require a working display or a Vulkan
device. Heavy tests (window creation, camera, graph upload, background
gradients) are skipped on CRAN since CRAN build machines are headless
and lack a usable Vulkan ICD. They are exercised locally and on CI with
Xvfb + Vulkan.

## Test environments

* Local: Linux 6.17 (Ubuntu 24.04), R 4.3.3, GCC 13.3.0
* GitHub Actions (planned): Ubuntu Latest with Xvfb + Mesa Vulkan drivers

## Downstream dependencies

There are currently no downstream dependencies on CRAN.
