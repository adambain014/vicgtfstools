#' Fix and standardise route short names across multiple modes
#'
#' Applies mode-specific route short name corrections across a
#' multi-modal Victorian GTFS feed, dispatching to the relevant
#' \code{vicgtfstools} naming helper for each mode present in
#' \code{gtfs$calendar$mode_number}. Modes not present in the data are
#' silently skipped, so this function is safe to call on feeds containing
#' any subset of the supported modes.
#'
#' Processing proceeds in a fixed order regardless of which modes are
#' present:
#' \enumerate{
#'   \item \strong{Mode 1 (V/Line):} calls \code{\link{split_vline_names}}
#'     to split combined/corridor V/Line route names into their
#'     constituent parts.
#'   \item \strong{Mode 2 (Replacement bus):} calls
#'     \code{\link{add_replacement_bus_names}} to derive short names for
#'     rail replacement bus routes.
#'   \item \strong{Mode 6:} blanks out \code{route_short_name} for all
#'     mode 6 routes (set to \code{""}), so that they fall through to the
#'     generic \code{route_id}-derived fallback below.
#'   \item \strong{All modes (fallback):} for any route still left with an
#'     empty \code{route_short_name} after the above steps, derives a
#'     short name from the second hyphen-delimited segment of
#'     \code{route_id} (via \code{tstrsplit(route_id, "-", keep = 2)}).
#'     This is a catch-all and is not gated on a specific mode being
#'     present.
#'   \item \strong{Mode 4 (Myki bus):} calls
#'     \code{\link{tag_myki_bus}} to attach a \code{region} column, then
#'     appends \code{" (region)"} to \code{route_short_name} for any route
#'     outside the \code{"Melbourne"} region, before dropping the
#'     temporary \code{region} column.
#'   \item \strong{Mode 5 (Coach):} calls \code{\link{add_coach_names}}
#'     to derive short names for coach routes.
#'   \item \strong{Mode 11 (SkyBus):} calls
#'     \code{\link{add_skybus_names}} to derive short names for SkyBus
#'     routes.
#' }
#'
#' Because the generic \code{route_id}-based fallback (step 4) runs
#' unconditionally after the mode 1/2/6 steps but before modes 4, 5, and
#' 11 are handled, routes for modes 4, 5, and 11 must arrive with a
#' non-empty \code{route_short_name} already, or otherwise be populated
#' entirely by their dedicated helper function — the fallback step will
#' not run again after them.
#'
#' @param gtfs A GTFS list object containing at least \code{calendar}
#'   (with a \code{mode_number} column) and \code{routes} (with
#'   \code{route_id}, \code{route_short_name}, and \code{mode_number}
#'   columns). Not modified in place; a copy is made internally.
#'
#' @return A modified copy of \code{gtfs}, with \code{gtfs$routes}
#'   updated so that \code{route_short_name} is populated appropriately
#'   for every mode present in the feed. Other tables are only changed if
#'   the mode-specific helper functions modify them.
#'
#' @details
#' \code{modes} is derived from \code{gtfs$calendar$mode_number} rather
#' than \code{gtfs$routes$mode_number}; if a mode's routes are present
#' but its services are absent from \code{calendar} (e.g. after upstream
#' filtering), that mode's naming step will be skipped even though
#' matching rows exist in \code{routes}.
#'
#' @seealso \code{\link{split_vline_names}},
#'   \code{\link{add_replacement_bus_names}}, \code{\link{tag_myki_bus}},
#'   \code{\link{add_coach_names}}, \code{\link{add_skybus_names}}
#'
#' @import data.table
#' @export
vic_route_short_name_multifix <- function(gtfs){

  stopifnot("mode_number" %in% names(gtfs$calendar))
  modes <- unique(gtfs$calendar$mode_number)

  out <- copy(gtfs)

  if (1 %in% modes) {
    out <- vicgtfstools::split_vline_names(out)
  }
  if (2 %in% modes) {
    out <- vicgtfstools::add_replacement_bus_names(out)
  }

  if (6 %in% modes) {
    out$routes <- out$routes[mode_number == 6, route_short_name := ""]
  }

  out$routes <- out$routes[route_short_name == "", route_short_name := tstrsplit(route_id, "-", keep = 2)]


  if (4 %in% modes) {
    out <- vicgtfstools::tag_myki_bus(out)
    out$routes <- out$routes[region != "Melbourne",
                             route_short_name := paste0(route_short_name, " (", region, ")")][
                               , region := NULL]
  }
  if (5 %in% modes) {
    out <- vicgtfstools::add_coach_names(out)
  }


  if (11 %in% modes) {
    out <- vicgtfstools::add_skybus_names(out)
  }

  out
}
