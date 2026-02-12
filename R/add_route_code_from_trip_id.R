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
add_route_code_from_trip_id <- function(df){

  if (!("trip_id" %in% names(df))) {
    stop("Function requires trip_id to be present, use with trips or stop_times")
  }

  df |>
    dplyr::mutate(
      line_code = as.characstringr::str_split_i(trip_id, "-", 2)
      )
}
