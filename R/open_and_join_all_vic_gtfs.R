#' Open and Join All Available Victorian GTFS Feeds
#'
#' @description
#' Automatically detects, opens, and combines all Victorian GTFS feeds
#' present within a parent directory. The function identifies GTFS mode
#' folders by their numeric PTV identifiers (e.g., `1`, `2`, `3`, `10`),
#' maps them to human‑readable mode names, loads each feed, adds mode
#' metadata columns, and merges them into a single GTFS object.
#'
#' @param parent
#' A character string giving the path to the directory containing the
#' extracted Victorian GTFS mode folders (e.g., `1/`, `2/`, `3/`,
#' `10/`, `11/`).
#'
#' @return
#' A unified GTFS object where:
#' \itemize{
#'   \item all detected GTFS feeds have been opened,
#'   \item each table includes \code{mode_number} and \code{mode_name}
#'         columns identifying its source mode,
#'   \item tables shared across feeds are row‑bound,
#'   \item tables present in only one feed are included unchanged.
#' }
#'
#' @details
#' This function is designed for workflows where Victorian GTFS feeds are
#' downloaded and extracted into the standard PTV folder structure, where
#' each mode is stored in a numeric subdirectory. Only folders whose names
#' can be safely interpreted as integers are considered. These integers
#' are mapped to known Victorian transport modes:
#'
#' \itemize{
#'   \item `1` = Regional Train
#'   \item `2` = Metro Train
#'   \item `3` = Metro Tram
#'   \item `4` = Metro Bus
#'   \item `5` = Regional Coach
#'   \item `6` = Regional Bus
#'   \item `10` = Interstate
#'   \item `11` = SkyBus
#' }
#'
#' Any mode folder present in \code{parent} will be opened and included in
#' the final merged GTFS object. This makes the function robust to partial
#' or customised GTFS datasets.
#'
#' @examples
#' \dontrun{
#' # Load and combine all GTFS feeds in the "gtfs" directory
#' all_gtfs <- open_and_join_all_vic_gtfs("gtfs")
#'
#' # Inspect combined routes
#' head(all_gtfs$routes)
#' }
#'
#' @export
open_and_join_all_vic_gtfs <- function(parent) {
  # Detect numeric GTFS folders
  folders <- list.dirs(parent, full.names = FALSE, recursive = FALSE)
  numbers <- suppressWarnings(as.integer(folders))
  numbers <- numbers[!is.na(numbers)]

  if (length(numbers) == 0) {
    stop("No valid GTFS mode folders found in ", parent)
  }

  # Map numbers to mode names
  lookup <- c(
    `1` = "Regional_Train",
    `2` = "Metro_Train",
    `3` = "Metro_Tram",
    `4` = "Metro_Bus",
    `5` = "Regional_Coach",
    `6` = "Regional_Bus",
    `10` = "Interstate",
    `11` = "SkyBus"
  )

  # Load all GTFS feeds and tag with mode metadata
  all_tables <- list()

  for (num in numbers) {
    mode_name <- lookup[as.character(num)]
    if (is.na(mode_name)) {
      warning("Unknown mode folder: ", num, ". Skipping.")
      next
    }

    # Read GTFS
    gtfs_path <- file.path(parent, num, "google_transit.zip")
    gtfs <- gtfstools::read_gtfs(gtfs_path)

    # Add mode columns to each data frame
    for (tbl_name in names(gtfs)) {
      if (is.data.frame(gtfs[[tbl_name]])) {
        n <- nrow(gtfs[[tbl_name]])
        if (n > 0) {
          gtfs[[tbl_name]]$mode_number <- num
          gtfs[[tbl_name]]$mode_name <- mode_name
        } else {
          gtfs[[tbl_name]]$mode_number <- numeric(0)
          gtfs[[tbl_name]]$mode_name <- character(0)
        }

        # Accumulate tables
        if (is.null(all_tables[[tbl_name]])) {
          all_tables[[tbl_name]] <- list()
        }
        all_tables[[tbl_name]][[length(all_tables[[tbl_name]]) + 1]] <- gtfs[[tbl_name]]
      }
    }
  }

  # Combine all accumulated tables
  combined <- lapply(all_tables, function(tables) {
    dplyr::bind_rows(tables)
  })

  combined
}

