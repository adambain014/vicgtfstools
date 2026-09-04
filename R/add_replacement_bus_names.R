#' Append Line Suffixes to Melbourne Metro Train Rail Replacement Bus Route Names
#'
#' @description
#' Appends a bracketed line-name suffix (e.g. "(Lilydale)", "(Glen Waverley)")
#' to the existing "Replacement Bus" `route_short_name` for Metro Melbourne train routes, based
#' on a line code embedded in `route_id`.
#'
#' @param metro_train_gtfs A GTFS object containing at minimum a `routes`
#'   table with `route_id` and `route_short_name` columns. Typically created
#'   by reading GTFS data with `vicgtfstools` or similar.
#'
#' @return A modified GTFS object with the same structure as the input, where
#'   `routes$route_short_name` has had a line suffix appended for recognised
#'   metro line codes:
#'   \describe{
#'     \item{ALM}{Alamein}
#'     \item{BEG}{Belgrave}
#'     \item{CBE}{Cranbourne}
#'     \item{CCL}{City Circle}
#'     \item{CGB}{Cragieburn}
#'     \item{FKN}{Frankston}
#'     \item{GWY}{Glen Waverley}
#'     \item{HBE}{Hurstbridge}
#'     \item{LIL}{Lilydale}
#'     \item{MDD}{Mernda}
#'     \item{PKM}{Pakenham}
#'     \item{RCE}{Flemington Racecourse}
#'     \item{SHM}{Sandringham}
#'     \item{STY}{Stony Point}
#'     \item{SUY}{Sunbury}
#'     \item{UFD}{Upfield}
#'     \item{WER}{Werribee}
#'     \item{WIL}{Williamstown}
#'   }
#'   Unmatched routes keep their existing `route_short_name` with no suffix
#'   added.
#'
#' @details
#' The function splits `route_id` on `"-"` (fixed, not regex) and takes the
#' third element as the `route_code`. If a `mode_number` column is present,
#' the split is only applied to rows where `mode_number == 2`, leaving other
#' modes untouched; otherwise it is applied to all rows. The resulting
#' `route_code` is matched against a lookup table of known replacement bus metro line codes,
#' and matching rows have their `route_short_name` updated in place to
#' `"Replacement Bus (<line suffix>)"` via a data.table join. Unlike
#' \code{add_coach_names}, this does not replace the existing
#' name - it appends to it. The
#' temporary `route_code` column is dropped before the GTFS object is
#' returned.
#'
#' @section Performance:
#' Uses `data.table` internally (including a join-based update of
#' `route_short_name`) for efficient processing of large GTFS feeds.
#'
#' @examples
#' \dontrun{
#' metro_train_gtfs <- vicgtfstools::open_vic_gtfs("path/to/gtfs", "Metro_Train")
#'
#' metro_train_gtfs_named <- add_replacement_bus_names(metro_train_gtfs)
#'
#' library(data.table)
#' routes <- as.data.table(metro_train_gtfs_named$routes)
#' routes[, .(route_id, route_short_name)]
#' }
#'
#' @import data.table
#' @export
add_replacement_bus_names <- function(metro_train_gtfs){

  routes <- copy(data.table::as.data.table(metro_train_gtfs$routes))

  # Split route_id safely
  if("mode_number" %chin% names(routes)){
    routes[mode_number == 2, route_code1 :=
             data.table::tstrsplit(route_id, "-", fixed = TRUE, fill = NA)[3]]
  } else {
    routes[, route_code1 :=
             data.table::tstrsplit(route_id, "-", fixed = TRUE, fill = NA)[3]]
  }

  rr_map <- data.table(
    route_code1 = c("ALM", "BEG", "CBE",
                   "CCL", "CGB", "FKN",
                   "GWY", "HBE", "LIL",
                   "MDD", "PKM", "RCE",
                   "SHM", "STY", "SUY",
                   "UFD", "WER", "WIL"),
    route_suffix = c("Alamein", "Belgrave", "Cranbourne",
                     "City Circle", "Cragieburn", "Frankston",
                     "Glen Waverley", "Hurstbridge","Lilydale",
                     "Mernda", "Pakenham", "Flemington Racecourse",
                     "Sandringham", "Stony Point", "Sunbury",
                     "Upfield", "Werribee", "Williamstown")
  )

  # Join suffixes
  routes[rr_map, on = "route_code1",
         route_short_name := paste0(route_short_name, " (", route_suffix, ")")]

  # Drop temporary split columns
  routes[, route_code1 := NULL]

  # Return updated GTFS object
  metro_train_gtfs$routes <- routes
  metro_train_gtfs
}





