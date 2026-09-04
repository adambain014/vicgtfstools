#' Tag Myki Bus Routes with Regional Classifications
#'
#' @description
#' Adds regional classification tags to bus routes in a GTFS feed based on route codes.
#' Routes are classified into Melbourne metropolitan area or various regional Victoria
#' locations (Bendigo, Ballarat, Geelong, etc.) based on route_id patterns.
#'
#' @param metro_bus_gtfs A GTFS object containing at minimum a `routes` table.
#'   Typically created by reading GTFS data with `vicgtfstools` or similar.
#'
#' @return A modified GTFS object with the same structure as the input, where the
#'   `routes` table has been extended with a `region` column containing one of:
#'   \describe{
#'     \item{Melbourne}{Metropolitan Melbourne bus routes (default)}
#'     \item{Bendigo}{Routes with codes starting with "B"}
#'     \item{Ballarat}{Routes with codes ending with "B"}
#'     \item{Geelong}{Routes with codes starting with "G"}
#'     \item{Warragul}{Routes with codes starting with "W", "v", or "V"}
#'     \item{Latrobe Valley}{Routes with codes starting with "L" or route 855}
#'     \item{Wallan}{Routes with codes starting with "WN" or route W12}
#'     \item{Ballan}{Routes with codes ending with "x" or "y"}
#'     \item{Bacchus Marsh}{Routes with codes starting with "BM"}
#'     \item{Seymour}{Routes with codes starting with "SY"}
#'     \item{Kilmore}{Routes with codes starting with "KM"}
#'   }
#'
#' @details
#' The function parses the `route_id` field (which typically follows the pattern
#' "trip_code-route_code-country_code-additional_number") and classifies routes
#' based on the route_code component. Routes that don't match any regional pattern
#' are classified as "Melbourne" by default.
#'
#' The classification is based on Public Transport Victoria's route numbering
#' conventions, where specific prefixes and suffixes indicate regional services.
#'
#' Before splitting, any `route_id` containing the literal substring
#' `"695-F"` has it collapsed to `"695F"`, correcting a known formatting
#' inconsistency for route 695 where an extra hyphen would otherwise split
#' its code across two segments. The `route_id` is then split on `"-"`
#' (fixed, not regex), and the second element is taken as `route_code`.
#'
#' @section Performance:
#' This function uses `data.table` internally for efficient processing of large
#' GTFS feeds. All operations are performed in-place where possible to minimize
#' memory usage.
#'
#' @examples
#' \dontrun{
#' # Read bus GTFS data
#' bus_gtfs <- vicgtfstools::open_vic_gtfs("path/to/gtfs", "Metro_Bus")
#'
#' # Add regional classifications
#' bus_gtfs_tagged <- tag_myki_bus(bus_gtfs)
#'
#' # Check regional distribution
#' library(data.table)
#' routes <- as.data.table(bus_gtfs_tagged$routes)
#' routes[, .N, by = region]
#' }
#'
#' @import data.table
#' @export
tag_myki_bus <- function(metro_bus_gtfs){

  routes <- copy(data.table::as.data.table(metro_bus_gtfs$routes))
  # Fix 695F
  routes[, route_id := gsub("695-F", "695F", route_id)]

  # Split route_id safely
  if("mode_number" %chin% names(routes)){
    routes[mode_number == 4, route_code1 :=
             data.table::tstrsplit(route_id, "-", fixed = TRUE, fill = NA)[2]]
  } else {
    routes[, route_code1 :=
           data.table::tstrsplit(route_id, "-", fixed = TRUE, fill = NA)[2]]
    }


  routes[, region :=
           data.table::fcase(
             grepl("^BM", route_code1),                     "Bacchus Marsh",
             grepl("^(WN|W12$)", route_code1),              "Wallan",
             grepl("^B",  route_code1),                     "Bendigo",
             grepl("B$",  route_code1),                     "Ballarat",
             grepl("^G",  route_code1),                     "Geelong",
             grepl("^(W|v|V)", route_code1),                "Warragul",
             grepl("^L|855$", route_code1),                 "Latrobe Valley",
             grepl("x$|y$", route_code1),                   "Ballan",
             grepl("^SY", route_code1),                     "Seymour",
             grepl("^KM", route_code1),                     "Kilmore",
             default = "Melbourne"
           )
  ]

  # Drop temporary split columns
  routes[, route_code1 := NULL]

  # Return updated GTFS object
  metro_bus_gtfs$routes <- routes
  metro_bus_gtfs
}


