#' Add Route Code from Trip ID
#'
#' @description
#' Extracts a route/line code embedded in a GTFS `trip_id` and adds it as a
#' new `route_code` column. Assumes the Victorian GTFS convention where the
#' route or line code sits in the second hyphen-delimited segment of the
#' `trip_id` (e.g. `"1234-ABC-5678"` -> `"ABC"`).
#'
#' @param df
#' A data frame or data.table containing a `trip_id` column — typically
#' the `trips` or `stop_times` table from a GTFS object.
#'
#' @return
#' The input data frame with an added `route_code` character column.
#'
#' @details
#' Before splitting, any `trip_id` containing the literal substring
#' `"695-F"` has it collapsed to `"695F"`, correcting a known formatting
#' inconsistency for route 695 where an extra hyphen would otherwise split
#' its code across two segments. The `trip_id` is then split on `"-"`
#' (fixed, not regex), and the second element is taken as `route_code`.
#'
#' @examples
#' \dontrun{
#' trips_with_code <- add_route_code_from_trip_id(gtfs$trips)
#' head(trips_with_code[, c("trip_id", "route_code")])
#' }
#'
#' @export
add_route_code_from_trip_id <- function(trips){
  if (!("trip_id" %in% names(trips))) {
    stop("Function requires trip_id to be present, use with trips or stop_times")
  }

  trips <- data.table::as.data.table(trips)
  # Fix 695F
  trips[, trip_id := gsub("695-F", "695F", trip_id)]

  # Split route_id safely
  trips[, route_code :=
           data.table::tstrsplit(trip_id, "-", fixed = TRUE, fill = NA)[2]]

}

