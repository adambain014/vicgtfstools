#' Join Two Victorian GTFS Feeds with Mode Metadata
#'
#' @description
#' Combines two Victorian GTFS objects into a single GTFS structure while
#' preserving mode metadata. The function propagates each feed's
#' `mode$number` and `mode$name` values into every data-frame subtable as
#' `mode_number` and `mode_name` columns. Empty tables are handled safely
#' by adding zero-length columns of the appropriate type. After
#' propagation, the original `mode` list is removed from each GTFS object.
#'
#' @param gtfs1
#' A GTFS object (as returned by \code{gtfstools::read_gtfs()}) containing
#' a \code{$mode} list with elements \code{$number} and \code{$name}.
#'
#' @param gtfs2
#' A second GTFS object structured in the same way as \code{gtfs1}.
#'
#' @return
#' A single GTFS object where:
#' \itemize{
#'   \item all matching tables from \code{gtfs1} and \code{gtfs2} are
#'         row-bound,
#'   \item each table includes \code{mode_number} and \code{mode_name}
#'         columns identifying its source feed,
#'   \item non-data-frame elements are carried forward from the first
#'         non-\code{NULL} input,
#'   \item the original \code{$mode} lists have been removed.
#' }
#'
#' @details
#' This function is designed for workflows where Victorian GTFS feeds are
#' downloaded and opened separately by mode (e.g., Metro Train, Tram,
#' Bus) and later combined into a unified dataset. Because GTFS feeds may
#' contain empty tables (e.g., \code{frequencies}, \code{pathways}),
#' the function ensures that mode metadata is added consistently even when
#' a table has zero rows.
#'
#' Tables present in only one of the two GTFS objects are included
#' unchanged. When both feeds contain the same table, the tables are
#' merged using \code{dplyr::bind_rows()}.
#'
#' @examples
#' \dontrun{
#' train <- open_vic_gtfs("gtfs", "Metro_Train")
#' tram  <- open_vic_gtfs("gtfs", "Metro_Tram")
#'
#' combined <- join_vic_gtfs(train, tram)
#'
#' # Inspect combined routes
#' head(combined$routes)
#' }
#'
#' @export
  # Helper to add mode columns to all subcolumns
join_vic_gtfs <- function(gtfs1, gtfs2){
  # Helper to add mode columns to all subcolumns
  add_mode_cols <- function(gtfs) {
    mode_number <- gtfs$mode$number
    mode_name   <- gtfs$mode$name
    for (tbl in names(gtfs)) {
      if (is.data.frame(gtfs[[tbl]])) {
        n <- nrow(gtfs[[tbl]])
        if (n > 0) {
          # Normal case: add scalar values recycled to n rows
          gtfs[[tbl]]$mode_number <- rep(mode_number, n)
          gtfs[[tbl]]$mode_name   <- rep(mode_name, n)
        } else {
          # Empty table: add 0-length columns of correct type
          gtfs[[tbl]]$mode_number <- numeric(0)
          gtfs[[tbl]]$mode_name   <- character(0)
        }
      }
    }
    # Remove the mode list
    gtfs$mode <- NULL
    gtfs
  }
  gtfs1 <- add_mode_cols(gtfs1)
  gtfs2 <- add_mode_cols(gtfs2)
  out <- list()
  all_tables <- union(names(gtfs1), names(gtfs2))
  for (tbl in all_tables) {
    t1 <- gtfs1[[tbl]]
    t2 <- gtfs2[[tbl]]
    if (is.data.frame(t1) && is.data.frame(t2)) {
      out[[tbl]] <- dplyr::bind_rows(t1, t2)
    } else if (is.data.frame(t1)) {
      out[[tbl]] <- t1
    } else if (is.data.frame(t2)) {
      out[[tbl]] <- t2
    } else {
      # Non-data-frame elements: keep the first non-null
      out[[tbl]] <- t1 %||% t2
    }
  }
  out
}
