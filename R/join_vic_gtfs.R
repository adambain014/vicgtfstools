#' Join Two Victorian GTFS Feeds with Mode Metadata
#'
#' @description
#' Combines two Victorian GTFS objects into a single GTFS structure while
#' preserving mode metadata. The function requires that both GTFS objects
#' have been opened with mode tagging enabled (\code{tag_mode = TRUE}),
#' ensuring that \code{mode_number} and \code{mode_name} columns are
#' present in all tables.
#'
#' This function is designed to safely merge GTFS feeds from different
#' transport modes while maintaining data integrity and mode identity.
#'
#' @param gtfs1
#' A GTFS object (as returned by \code{open_vic_gtfs()} with
#' \code{tag_mode = TRUE}) containing \code{mode_number} and
#' \code{mode_name} columns in all data tables.
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
#'   \item the result is converted to a \code{dt_gtfs} object using
#'         \code{gtfstools::as_dt_gtfs()}.
#' }
#'
#' @details
#' This function is designed for workflows where Victorian GTFS feeds are
#' downloaded and opened separately by mode (e.g., Metro Train, Tram,
#' Bus) and later combined into a unified dataset.
#'
#' **Mode Tagging Requirement:**
#' Both input GTFS objects must have been opened with \code{tag_mode = TRUE}.
#' The function validates this requirement by checking for the presence of
#' \code{mode_name} in the \code{trips} table. If mode columns are missing,
#' an error is raised with guidance to re-extract the feeds with tagging
#' enabled.
#'
#' **Handling Empty Tables:**
#' Because GTFS feeds may contain empty tables (e.g., \code{frequencies},
#' \code{pathways}), the function ensures that mode metadata is preserved
#' consistently even when a table has zero rows.
#'
#' **Table Merging:**
#' Tables present in only one of the two GTFS objects are included
#' unchanged. When both feeds contain the same table, the tables are
#' merged using \code{dplyr::bind_rows()}, which handles column
#' differences gracefully.
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
#'
#' # Check mode distribution
#' table(combined$routes$mode_name)
#' }
#'
#' @export
join_vic_gtfs <- function(gtfs1, gtfs2){
  if (!("mode_name" %in% names(gtfs1$trips))) {
    stop("No mode columns found in gtfs1. Make sure to extract GTFS files using open_vic_gtfs(tag_mode = TRUE).")
  }
  if (!("mode_name" %in% names(gtfs2$trips))) {
    stop("No mode columns found in gtfs2. Make sure to extract GTFS files using open_vic_gtfs(tag_mode = TRUE).")
  }
  out <- list()
  all_tables <- union(names(gtfs1), names(gtfs2))
  for (tbl in all_tables) {
    t1 <- gtfs1[[tbl]]
    t2 <- gtfs2[[tbl]]
    if (is.data.frame(t1) && is.data.frame(t2)) {
      out[[tbl]] <- data.table::rbindlist(list(t1, t2), fill = TRUE)
    } else if (is.data.frame(t1)) {
      out[[tbl]] <- t1
    } else if (is.data.frame(t2)) {
      out[[tbl]] <- t2
    } else {
      # Non-data-frame elements: keep the first non-null
      out[[tbl]] <- t1 %||% t2
    }
  }
  out |> gtfstools::as_dt_gtfs()
}
