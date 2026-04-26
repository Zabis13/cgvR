test_that("cgv_set_graph accepts nodes and edges", {
  v <- cgv_viewer(320, 240, "test-graph", offscreen = TRUE)

  nodes <- 1:5
  edges <- matrix(c(1L, 2L, 3L, 4L,
                     2L, 3L, 4L, 5L), ncol = 2)

  expect_no_error(cgv_set_graph(v, nodes, edges))
  cgv_close(v)
})

test_that("cgv_set_graph accepts positions", {
  v <- cgv_viewer(320, 240, "test-graph-pos", offscreen = TRUE)

  nodes <- 1:3
  edges <- matrix(c(1L, 2L, 2L, 3L), ncol = 2)
  pos <- matrix(c(0, 1, 2,   # x
                   0, 1, 0,   # y
                   0, 0, 0),  # z
                ncol = 3)

  expect_no_error(cgv_set_graph(v, nodes, edges, pos))
  cgv_close(v)
})

test_that("cgv_set_graph accepts node_values (colormap)", {
  v <- cgv_viewer(320, 240, "test-cmap", offscreen = TRUE)

  nodes <- 1:5
  edges <- matrix(c(1L, 2L, 2L, 3L), ncol = 2)
  depths <- c(0, 1, 2, 3, 4)

  expect_no_error(cgv_set_graph(v, nodes, edges, node_values = depths))
  expect_no_error(cgv_set_graph(v, nodes, edges, node_values = depths, cmap = 5L))
  cgv_close(v)
})

test_that("cgv_set_graph accepts node_colors (RGBA matrix)", {
  v <- cgv_viewer(320, 240, "test-rgba", offscreen = TRUE)

  nodes <- 1:3
  edges <- matrix(c(1L, 2L, 2L, 3L), ncol = 2)
  cols <- matrix(c(255L, 0L, 0L,    # R
                    0L, 255L, 0L,    # G
                    0L, 0L, 255L,    # B
                    255L, 255L, 255L), # A
                  ncol = 4)

  expect_no_error(cgv_set_graph(v, nodes, edges, node_colors = cols))
  cgv_close(v)
})

test_that("cgv_set_graph accepts node_sizes", {
  v <- cgv_viewer(320, 240, "test-sizes", offscreen = TRUE)

  nodes <- 1:3
  edges <- matrix(c(1L, 2L, 2L, 3L), ncol = 2)

  expect_no_error(cgv_set_graph(v, nodes, edges, node_sizes = c(5, 15, 25)))
  cgv_close(v)
})

test_that("cgv_highlight_path highlights nodes and edges", {
  v <- cgv_viewer(320, 240, "test-path", offscreen = TRUE)

  nodes <- 1:5
  edges <- matrix(c(1L, 2L, 3L, 4L,
                     2L, 3L, 4L, 5L), ncol = 2)
  cgv_set_graph(v, nodes, edges)

  expect_no_error(cgv_highlight_path(v, c(1L, 2L, 3L), "#FF0000"))
  expect_no_error(cgv_highlight_path(v, c(2L, 3L, 4L), "#00FF00",
                                     node_scale = 3.0, edge_width = 8.0))
  cgv_close(v)
})

test_that("cgv_clear_path restores original colors", {
  v <- cgv_viewer(320, 240, "test-clear", offscreen = TRUE)

  nodes <- 1:3
  edges <- matrix(c(1L, 2L, 2L, 3L), ncol = 2)
  cgv_set_graph(v, nodes, edges)
  cgv_highlight_path(v, c(1L, 2L, 3L), "#FF0000")

  expect_no_error(cgv_clear_path(v))
  cgv_close(v)
})

test_that("cgv_highlight_path warns without graph", {
  v <- cgv_viewer(320, 240, "test-path-nograph", offscreen = TRUE)
  expect_warning(cgv_highlight_path(v, c(1L, 2L), "#FF0000"),
                 "no graph loaded")
  cgv_close(v)
})

test_that("cgv_set_graph handles single-node graph (no edges)", {
  v <- cgv_viewer(320, 240, "test-1node", offscreen = TRUE)
  expect_no_error(cgv_set_graph(v, nodes = 1L, edges = matrix(integer(0), ncol = 2)))
  cgv_close(v)
})

test_that("cgv_set_graph accepts numeric input coerced to integer", {
  v <- cgv_viewer(320, 240, "test-numeric", offscreen = TRUE)
  expect_no_error(cgv_set_graph(v, nodes = c(1, 2, 3),
                                edges = matrix(c(1, 2, 2, 3), ncol = 2)))
  cgv_close(v)
})

test_that("cgv_clear_path works without prior highlight", {
  v <- cgv_viewer(320, 240, "test-clear-empty", offscreen = TRUE)
  cgv_set_graph(v, nodes = 1:3,
                edges = matrix(c(1L, 2L, 2L, 3L), ncol = 2))
  expect_no_error(cgv_clear_path(v))
  cgv_close(v)
})

test_that("cgv_set_graph accepts both colormap variants", {
  v <- cgv_viewer(320, 240, "test-cmaps", offscreen = TRUE)
  nodes <- 1:4
  edges <- matrix(c(1L, 2L, 3L, 2L, 3L, 4L), ncol = 2)
  vals  <- c(0, 1, 2, 3)
  for (cm in c(5L, 6L, 7L, 8L)) {
    expect_no_error(cgv_set_graph(v, nodes, edges, node_values = vals, cmap = cm))
  }
  cgv_close(v)
})
