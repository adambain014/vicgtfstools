#' Rename V/Line Coach Routes To Their Corridor or Destination Name
#'
#' @description
#' Replaces the `route_short_name` for V/Line coach routes with a
#' human-readable corridor or destination name (e.g. "Bendigo (Coach)",
#' "Mildura - Ballarat"), based on a route code embedded in `route_id`.
#' Routes that do not match a known coach code are left with their original
#' `route_short_name`.
#'
#' @param vline_coach_gtfs A GTFS object containing at minimum a `routes`
#'   table with `route_id` and `route_short_name` columns. Typically created
#'   by reading GTFS data with `vicgtfstools` or similar.
#'
#' @return A modified GTFS object with the same structure as the input, where
#'   `routes$route_short_name` has been updated for recognised V/Line coach
#'   route codes (over 50 corridors, spanning direct-substitute routes for
#'   regional destinations, e.g. `"BDE"` → "Bairnsdale (Coach)", and
#'   cross-regional coach-only corridors, e.g. `"V22"` → "Mildura - Ballarat").
#'   See the function body for the full code-to-name mapping. All other
#'   routes retain their existing `route_short_name`.
#'
#' @details
#' The function splits `route_id` on `"-"` (fixed, not regex) and takes the
#' third element as the `route_code`. If a `mode_number` column is present,
#' the split is only applied to rows where `mode_number == 5`, leaving other
#' modes untouched; otherwise it is applied to all rows. Any colon
#' characters (`:`) in the resulting `route_code` are stripped before
#' matching. The cleaned `route_code` is matched against a lookup table of
#' known V/Line coach route codes, and matching rows have their
#' `route_short_name` fully overwritten with the mapped name via a
#' data.table join. The temporary `route_code` column is dropped before the
#' GTFS object is returned.
#'
#' The join is case-sensitive and the lookup table mixes upper- and
#' lower-case codes (e.g. `"ABY"` vs `"mjp"`, `"als"`, `"mtb"`, `"pay"`) as
#' they appear in the source `route_id` data, so a code must match the case
#' used in `coach_map` exactly. The code `"mjp"` is listed twice in the
#' lookup table, both mapping to `"The Overland (Coach)"`; this is
#' redundant but not conflicting, so it does not affect the join result.
#'
#' @section Performance:
#' Uses `data.table` internally (including a join-based update of
#' `route_short_name`) for efficient processing of large GTFS feeds.
#'
#' @examples
#' \dontrun{
#' vline_coach_gtfs <- vicgtfstools::open_vic_gtfs("path/to/gtfs", "Regional_Coach")
#'
#' vline_coach_gtfs_named <- add_coach_names(vline_coach_gtfs)
#'
#' library(data.table)
#' routes <- as.data.table(vline_coach_gtfs_named$routes)
#' routes[, .(route_id, route_short_name)]
#' }
#'
#' @import data.table
#' @export
add_coach_names <- function(vline_coach_gtfs){

  routes <- data.table::as.data.table(vline_coach_gtfs$routes)

  # Split route_id safely
  if("mode_number" %chin% names(routes)){
    routes[mode_number == 5, route_code1 :=
             data.table::tstrsplit(route_id, "-", fixed = TRUE, fill = NA)[3]]
  } else {
    routes[, route_code1 :=
             data.table::tstrsplit(route_id, "-", fixed = TRUE, fill = NA)[3]]
  }

  routes[, route_code1 := gsub("\\:", "", route_code1)]

  coach_map <- data.table(
    route_code1 = c(
      "mjp",
      "995",
      "ABY",
      "als",
      "ART",
      "BAT",
      "BDE",
      "BGO",
      "EC2",
      "ECH",
      "GEL",
      "mtb",
      "pay",
      "SER",
      "SNH",
      "SWL",
      "TRN",
      "V02",
      "V03",
      "V06",
      "V07",
      "V09",
      "V10",
      "V11",
      "V13",
      "V14",
      "V15",
      "V16",
      "V17",
      "V18",
      "V19",
      "V20",
      "V22",
      "V24",
      "V25",
      "V27",
      "V28",
      "V29",
      "V30",
      "V31",
      "V32",
      "V34",
      "V35",
      "V36",
      "V37",
      "V38",
      "V39",
      "V41",
      "V43",
      "V47",
      "V50",
      "V52",
      "WBL"
    ),
    route_short_name = c(
      "The Overland (Coach)",
      "Warrnambool - Ararat",
      "Albury (Coach)",
      "Alexandria - Seymour",
      "Ararat (Coach)",
      "Ballarat (Coach)",
      "Bairnsdale (Coach)",
      "Bendigo (Coach)",
      "Echuca - Murchison East/Shepparton",
      "Echuca (Coach)",
      "Geelong (Coach)",
      "Bright/Mount Beauty - Wangaratta",
      "Paynesville - Bairnsdale",
      "Seymour (Coach)",
      "Shepparton (Coach)",
      "Swan Hill (Coach)",
      "Traralgon (Coach)",
      "Geelong - Adelaide",
      "Adelaide (Daylink)",
      "Warrnambool - Ballarat",
      "Barmah",
      "Bairnsdale - Batesman's Bay",
      "Barham",
      "Albury - Bendigo",
      "Canberra - Bairnsdale/Traralgon",
      "Canberra - Wodonga",
      "Cowes/Inverloch",
      "Portland/Casterton - Warrnambool",
      "Corowa - Wangaratta",
      "Daylesford - Woodend",
      "Donald - Bendigo",
      "Deniliguin",
      "Bendigo - Geelong",
      "Halls Gap - Stawell",
      "Marlo - Bairnsdale/Traralgon",
      "Maryborough - Castlemaine",
      "Mansfield",
      "Mount Gambier - Ballarat",
      "Mount Gambier - Warrnambool",
      "Mildura - Albury",
      "Mildura - Ballarat",
      "Donald - Ballarat / Mildura - Melbourne",
      "Mildura - Swan Hill/Bendigo",
      "Mulwala - Benalla",
      "Nhill - Ararat/Ballarat",
      "Ouyen - Ararat/Ballarat",
      "Sea Lake - Bendigo",
      "Griffith - Shepparton/Seymour",
      "Sale - Traralgon via Maffra",
      "Adelaide - Albury (Speedlink)",
      "Warrnambool - Geelong (Great Ocean Road)",
      "Yarram/Leongatha",
      "Warrnambool (Coach)"
    )
  )

  # Join new names
  routes[coach_map, on = "route_code1",
         route_short_name := i.route_short_name]

  # Drop temporary split columns
  routes[, route_code1 := NULL]

  # Return updated GTFS object
  vline_coach_gtfs$routes <- routes
  vline_coach_gtfs
}


