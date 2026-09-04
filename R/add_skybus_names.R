#' Rename SkyBus Airport Routes to Their Marketed Express Names
#'
#' @description
#' Replaces the `route_short_name` for SkyBus airport shuttle routes with
#' their marketed express service name (e.g. "Melbourne City Express",
#' "Avalon City Express"), matched via the full `route_long_name`. Routes
#' whose `route_long_name` does not match a known SkyBus service are left
#' with their original `route_short_name`.
#'
#' @param skybus_gtfs A GTFS object containing at minimum a `routes` table
#'   with `route_long_name` and `route_short_name` columns. Typically created
#'   by reading GTFS data with `vicgtfstools` or similar.
#'
#' @return A modified GTFS object with the same structure as the input, where
#'   `routes$route_short_name` has been updated for recognised SkyBus
#'   long names:
#'   \describe{
#'     \item{Box Hill - Melbourne Airport}{Eastern Express}
#'     \item{Frankston - Melbourne Airport}{Peninsula Express}
#'     \item{Melbourne City - Avalon Airport}{Avalon City Express}
#'     \item{City - Melbourne Airport}{Melbourne City Express}
#'     \item{Sunshine Railway Station - Melbourne Airport}{Sunshine Express}
#'   }
#'   All other routes retain their existing `route_short_name`.
#'
#' @details
#' Unlike \code{split_vline_names} and \code{add_replacement_bus_names},
#' this function does not parse `route_id`. Instead it matches directly on the
#' full `route_long_name` string against a lookup table of known SkyBus
#' origin-destination pairs, and matching rows have their `route_short_name`
#' overwritten with the express service name via a data.table join.
#'
#' @section Performance:
#' Uses `data.table` internally (including a join-based update of
#' `route_short_name`) for efficient processing of GTFS feeds.
#'
#' @examples
#' \dontrun{
#' skybus_gtfs <- vicgtfstools::open_vic_gtfs("path/to/gtfs", "SkyBus")
#'
#' skybus_gtfs_named <- add_skybus_names(skybus_gtfs)
#'
#' library(data.table)
#' routes <- as.data.table(skybus_gtfs_named$routes)
#' routes[, .(route_long_name, route_short_name)]
#' }
#'
#' @import data.table
#' @export
  add_skybus_names <- function(skybus_gtfs){

    routes <- copy(data.table::as.data.table(skybus_gtfs$routes))

    if ("mode_number" %chin% names(routes)){
      sb_map <- data.table(
        route_long_name = c("Box Hill - Melbourne Airport",
                            "Frankston - Melbourne Airport",
                            "Melbourne City - Avalon Airport",
                            "City - Melbourne Airport",
                            "Sunshine Railway Station - Melbourne Airport"),
        route_short_name = c("Eastern Express",
                             "Peninsula Express",
                             "Avalon City Express",
                             "Melbourne City Express",
                             "Sunshine Express"),
        mode_number = c(11,11,11,11,11)
      )

      # Join new names
      routes[sb_map, on = .(mode_number, route_long_name),
             route_short_name := i.route_short_name]
    } else {
      sb_map <- data.table(
        route_long_name = c("Box Hill - Melbourne Airport",
                            "Frankston - Melbourne Airport",
                            "Melbourne City - Avalon Airport",
                            "City - Melbourne Airport",
                            "Sunshine Railway Station - Melbourne Airport"),
        route_short_name = c("Eastern Express",
                             "Peninsula Express",
                             "Avalon City Express",
                             "Melbourne City Express",
                             "Sunshine Express")
      )

      # Join new names
      routes[sb_map, on = "route_long_name",
             route_short_name := i.route_short_name]
    }


    # Return updated GTFS object
    skybus_gtfs$routes <- routes
    skybus_gtfs
  }
