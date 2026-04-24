#' Set Graph Data for Rendering
#'
#' Provide the full graph (or a subgraph) as adjacency data with optional
#' node colors, sizes, and colormap.
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param nodes Integer vector of node IDs.
#' @param edges Two-column integer matrix (from, to), 1-based.
#' @param positions Nx3 numeric matrix of 3D coordinates (optional; linear if NULL).
#' @param node_values Numeric vector of length N for automatic coloring via colormap
#'   (e.g. BFS depth, group id). Ignored if \code{node_colors} is provided.
#' @param node_colors Nx4 integer matrix (RGBA 0-255) for explicit node colors.
#'   Takes priority over \code{node_values}.
#' @param node_sizes Numeric vector of length N for point sizes (default 10).
#' @param cmap Integer colormap id (default 6 = viridis). Common values:
#'   5 = plasma, 6 = viridis, 7 = inferno, 8 = magma.
#' @return Invisible \code{NULL}.
#' @export
cgv_set_graph <- function(viewer, nodes, edges, positions = NULL,
                          node_values = NULL, node_colors = NULL,
                          node_sizes = NULL, cmap = 6L) {
  nodes <- as.integer(nodes)
  edges <- as.integer(edges)
  if (!is.null(positions)) positions <- as.double(positions)
  if (!is.null(node_values)) node_values <- as.double(node_values)
  if (!is.null(node_colors)) node_colors <- as.integer(node_colors)
  if (!is.null(node_sizes)) node_sizes <- as.double(node_sizes)
  cmap <- as.integer(cmap)

  invisible(.Call(C_cgv_set_graph, viewer, nodes, edges, positions,
                  node_values, node_colors, node_sizes, cmap))
}

#' Highlight a Path
#'
#' Draw a highlighted path between nodes. Path nodes get a distinct color
#' and enlarged size; path edges are drawn as thick colored segments on top
#' of existing edges.
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param path Integer vector of node IDs forming the path (1-based).
#' @param color Color as hex string \code{"#RRGGBB"} or \code{"#RRGGBBAA"}.
#' @param node_scale Numeric: size multiplier for highlighted nodes (default 2.0).
#' @param edge_width Numeric: line width for path edges (default 5.0).
#' @return Invisible \code{NULL}.
#' @export
cgv_highlight_path <- function(viewer, path, color = "#FF0000",
                               node_scale = 2.0, edge_width = 5.0) {
  invisible(.Call(C_cgv_highlight_path, viewer,
                  as.integer(path), as.character(color),
                  as.double(node_scale), as.double(edge_width)))
}

#' Clear Path Highlight
#'
#' Remove path highlight and restore original node colors and sizes.
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @return Invisible \code{NULL}.
#' @export
cgv_clear_path <- function(viewer) {
  invisible(.Call(C_cgv_clear_path, viewer))
}
