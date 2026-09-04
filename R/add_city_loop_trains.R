#' Add City Loop Stations to Runs Past Flinders Street Station
#'
#' @description
#' Merges paired Metro Melbourne train trips that travel through the City
#' Loop, joining a direction 0 trip and its corresponding direction 1 trip
#' (linked via a shared `block_id`) into a single continuous trip pattern in
#' `stop_times`, rather than leaving the loop portion split across two
#' separate trips.
#'
#' @param metro_trains_gtfs A GTFS object containing at minimum `trips`,
#'   `stop_times`, and `stops` tables. Typically created by reading GTFS data
#'   with `vicgtfstools` or similar.
#'
#' @return A modified GTFS object with the same structure as the input,
#'   where `metro_trains_gtfs$stop_times` has been rewritten so that City
#'   Loop trip pairs are represented as continuous journeys: the City Loop
#'   portion of one direction's trip is appended as a "tail" onto its paired
#'   trip, and the City Loop portion of the other direction is prepended as
#'   a "head", with `stop_sequence` and `shape_dist_traveled` renumbered to
#'   fit the extended trip. Duplicate arrival/departure records at shared
#'   City Loop stations are reconciled to a single row per stop.
#'
#' @details
#' The function identifies City Loop stations by name (Flinders Street,
#' Southern Cross, Flagstaff, Melbourne Central, Parliament) and filters
#' `trips` to those with a non-empty `block_id` (and, where a `mode_number`
#' column is present, a `mode_number` of 2, i.e. metro trains). Trips whose
#' `trip_headsign` contains "City Loop" are grouped by `block_id` to build a
#' correspondence table pairing each direction 0 trip with its direction 1
#' counterpart on the same block.
#'
#' For each pair, the direction 1 trip's City Loop stop_times are extracted,
#' renumbered from 1, and re-based to start at `shape_dist_traveled = 0`, then
#' relabelled under the direction 0 `trip_id` as a "head" segment (an
#' `added` flag marks these synthesized rows). Symmetrically, the direction
#' 0 trip's City Loop stop_times are extracted as a "tail" segment,
#' renumbered to continue on from the end of the direction 1 trip's stop
#' count and distance, and relabelled under the direction 1 `trip_id`.
#'
#' The original `stop_times` are offset to make room for the newly prepended
#' head segments, then all three pieces (adjusted original, heads, tails)
#' are combined with `rbind(..., fill = TRUE)` and reordered by `trip_id`
#' and `stop_sequence`. Rows that end up duplicated at a shared City Loop
#' stop (arising from the same physical stop appearing once in the original
#' trip and once in a synthesized head/tail) are reconciled by taking the
#' latest `departure_time` and earliest `arrival_time`.
#'
#' @section Performance:
#' Uses `data.table` throughout (joins, grouped assignment, and `rbind`)
#' for efficient processing of large GTFS feeds.
#'
#' @examples
#' \dontrun{
#' metro_trains_gtfs <- vicgtfstools::open_vic_gtfs("path/to/gtfs", "Metro_Train")
#'
#' metro_trains_gtfs_looped <- add_city_loop_trains(metro_trains_gtfs)
#' }
#'
#' @import data.table
#' @export
add_city_loop_trains <- function(metro_trains_gtfs){

  trips <- copy(metro_trains_gtfs$trips)
  stop_times <- copy(metro_trains_gtfs$stop_times)
  city_loop_stop_ids <- metro_trains_gtfs$stops[stop_name %chin% c("Flinders Street Station",
                                                                   "Southern Cross Station",
                                                                   "Flagstaff Station",
                                                                   "Melbourne Central Station",
                                                                   "Parliament Station")]$stop_id

  # Filter trips to list with valid blocks
  if("mode_number" %chin% names(trips)) {
    blocks <- trips[mode_number == 2 & block_id != ""]
  } else {
    blocks <- trips[block_id != ""]
  }

  # Count trips per block/direction
  blocks_test <- blocks[, .(n = .N), by = .(block_id, direction_id)]

  # Identify bad blocks (>1 trip in any direction)
  bad_blocks <- unique(blocks_test[n > 1, block_id])

  # Remove bad blocks
  blocks <- blocks[!block_id %in% bad_blocks]

  # Get block_ids that contain "city loop" in the trip headsign
  city_loop_block_ids <- unique(blocks[grep("City Loop", trip_headsign)]$block_id)

  # Filter down to city loop block pairs
  city_loop_blocks <- blocks[block_id %chin% city_loop_block_ids]

  # Split in two based on direction_id
  city_loop_trips_0 <- city_loop_blocks[direction_id == 0]
  city_loop_trips_1 <- city_loop_blocks[direction_id == 1]

  # Build a correspondence table
  blocks_correspondence_table <- city_loop_trips_0[,.(trip_id_0 = trip_id, block_id)
  ][city_loop_trips_1[,.(trip_id_1 = trip_id, block_id)],
    on = "block_id"]

  # Get trip_lengths
  trip_lengths_m <- stop_times[, .(length = max(shape_dist_traveled, na.rm = TRUE)), by = trip_id]

  # Get number of stops per trip
  trip_lengths_stations <- stop_times[, .(n_stops = .N), by = trip_id]

  # Create heads for direction_0
  head_1 <- stop_times[trip_id %chin% city_loop_trips_1$trip_id &
                         stop_id %chin% city_loop_stop_ids]
  # Remove single entry trips
  head_1 <- head_1[, N := .N, by = "trip_id"][N > 1, -"N"]

  # Add new stop_sequence, counting up from 1
  head_1[order(trip_id, stop_sequence), stop_sequence := seq_len(.N), by = "trip_id"]

  # Reset shape_dist_travelled
  head_1 <- head_1[order(trip_id, stop_sequence), first_sdt := shape_dist_traveled[1], by = "trip_id"
  ][, shape_dist_traveled := shape_dist_traveled - first_sdt
  ][, -"first_sdt"]

  # Add new_trip_id
  head_1[, added := TRUE]
  head_1 <- blocks_correspondence_table[
    head_1,
    on = .(trip_id_1 = trip_id)
  ]
  head_1[, trip_id := trip_id_0]
  head_1[, c("trip_id_0", "trip_id_1") := NULL]


  # Create tails for direction_1
  tail_0 <- stop_times[trip_id %chin% city_loop_trips_0$trip_id &
                         stop_id %chin% city_loop_stop_ids]
  # Remove single entry trips
  tail_0 <- tail_0[, N := .N, by = "trip_id"][N > 1, -"N"]

  # Add new_trip_id
  tail_0[, added := TRUE]
  tail_0 <- blocks_correspondence_table[
    tail_0,
    on = .(trip_id_0 = trip_id)
  ]
  tail_0[, trip_id := trip_id_1]
  tail_0[, c("trip_id_0", "trip_id_1") := NULL]

  # Add new stop_sequence, counting up from the max of the body
  tail_0 <- trip_lengths_stations[tail_0, on = "trip_id"
  ][, stop_sequence := n_stops + stop_sequence - 1
  ][, -"n_stops"]

  # Reset shape_dist_travelled in the same way
  tail_0 <- trip_lengths_m[tail_0, on = "trip_id"
  ][, shape_dist_traveled := length + shape_dist_traveled
  ][, -"length"]

  # Edit the body of direction_1 to reflect the new stop_sequence and shape_dist_traveled
  edits_1 <- head_1[,.(length = max(shape_dist_traveled),
                       n_stops = max(stop_sequence)), by = "trip_id"]

  # Join edits to stop_times
  stop_times <- edits_1[stop_times, on = "trip_id"]
  stop_times[!is.na(length), shape_dist_traveled := shape_dist_traveled + length]
  stop_times[!is.na(n_stops), stop_sequence := stop_sequence + n_stops - 1]
  stop_times <- stop_times[, -c("length", "n_stops")]

  # Merge heads and tails onto stop_times
  stop_times <- rbind(stop_times, head_1, tail_0, fill = TRUE)[order(trip_id, stop_sequence)]
  stop_times[is.na(added), added := FALSE]

  # Reconcile duplicate arrivals and departures from Flinders Street
  stop_times[, N := .N, by = .(trip_id, stop_id, stop_sequence)]
  stop_times[N == 2 , departure_time := max(departure_time), by = .(trip_id, stop_id, stop_sequence)]
  stop_times[N == 2 , arrival_time := min(arrival_time), by = .(trip_id, stop_id, stop_sequence)]
  stop_times <- stop_times[N == 1 | added != TRUE][, -c("N", "block_id")]

  # Add back to the file
  metro_trains_gtfs$stop_times <- stop_times
  metro_trains_gtfs
}
