#' Add Virtual Through-Run Stops to GTFS
#'
#' @description
#' Extends GTFS stop_times to include virtual stops for through-running train services.
#' When trains continue in the opposite direction after reaching their terminus (blocking),
#' this function adds the continuation stops as "virtual" stops to represent the complete
#' journey passengers can take without changing trains.
#'
#' @param metro_train_gtfs A GTFS object containing at minimum `trips`, `stops`, and
#'   `stop_times` tables. Typically created by reading GTFS data with `gtfstools` or similar.
#' @param keep_overlap Logical. If `TRUE` (default), duplicate stops at the reversal point
#'   are kept for both the original and virtual portions. If `FALSE`, duplicates are
#'   collapsed into a single stop, with the arrival time taken from the first occurrence
#'   (the original trip's terminus becomes the through-run's starting point).
#'
#' @return A modified GTFS object with the same structure as the input, where `stop_times`
#'   has been extended with virtual stops. The returned `stop_times` includes:
#'   \describe{
#'     \item{virtual}{Logical column indicating whether a stop is virtual (`TRUE`) or
#'       from the original GTFS (`FALSE`/`NA`)}
#'     \item{trip_type}{Character column classifying trips as:
#'       \itemize{
#'         \item "Simple" - No through-running or city loop
#'         \item "Through Run" - Standard through-run with one overlap point
#'         \item "City Loop" - Trips traversing Melbourne's city loop stations
#'       }}
#'     \item{source_trip_id}{For virtual stops, the trip_id from which the stop was mirrored}
#'   }
#'
#' @details
#' The function identifies valid through-running blocks by:
#' \enumerate{
#'   \item Finding trips with matching `block_id` values
#'   \item Filtering to blocks with exactly one trip per direction (0 and 1)
#'   \item Excluding blocks with multiple trips per direction (e.g., city circle services)
#' }
#'
#' For valid blocks, stops from one direction are "mirrored" to the opposite direction:
#' \itemize{
#'   \item Direction 0 trips receive virtual stops from their paired direction 1 trip
#'   \item Direction 1 trips receive virtual stops from their paired direction 0 trip
#'   \item `stop_sequence` and `shape_dist_traveled` are adjusted to maintain continuity
#' }
#'
#' Trip classification logic:
#' \itemize{
#'   \item "City Loop" - Contains all five Melbourne city loop stations (Flagstaff,
#'     Melbourne Central, Parliament, Southern Cross, Flinders Street). Virtual stops
#'     are filtered to only include city loop stations.
#'   \item "Through Run" - Has exactly one duplicate stop (the reversal point). All
#'     virtual stops are retained.
#'   \item "Simple" - No virtual stops or trips that don't fit the above patterns
#' }
#'
#' @section Performance:
#' This function uses `data.table` internally for efficient processing of large GTFS feeds.
#' All operations are performed in-place where possible to minimize memory usage.
#'
#' @examples
#' \dontrun{
#' # Read GTFS data
#' gtfs <- gtfstools::read_gtfs("path/to/gtfs.zip")
#'
#' # Add virtual through-run stops, keeping overlap points
#' gtfs_extended <- add_virtual_through_run(gtfs, keep_overlap = TRUE)
#'
#' # Add virtual stops and collapse duplicates at reversal points
#' gtfs_collapsed <- add_virtual_through_run(gtfs, keep_overlap = FALSE)
#'
#' # Check virtual stops for a specific trip
#' library(data.table)
#' stop_times <- as.data.table(gtfs_extended$stop_times)
#' stop_times[trip_id == "example_trip_id", .(stop_id, virtual, trip_type)]
#' }
#'
#' @export
add_virtual_through_run <- function(metro_train_gtfs, keep_overlap = TRUE){

  # Convert to data.table if needed
  trips      <- data.table::as.data.table(metro_train_gtfs$trips)
  stops      <- data.table::as.data.table(metro_train_gtfs$stops)
  stops_minimal <- stops[, c("stop_id", "stop_name")]
  stop_times <- data.table::as.data.table(metro_train_gtfs$stop_times)

  # Pre-join stop_name to stop_times once
  stop_times_with_names <- stops_minimal[stop_times, on = "stop_id", nomatch = NULL]
  stop_times_with_names$virtual <- FALSE

  # Get blocks
  blocks <- trips[block_id != ""]

  # Count trips per block/direction
  blocks_test <- blocks[, .(n = .N), by = .(block_id, direction_id)]

  # Identify bad blocks (>1 trip in any direction)
  bad_blocks <- unique(blocks_test[n > 1, block_id])

  # Remove bad blocks
  good_blocks <- blocks[!block_id %in% bad_blocks]

  # Pivot to wide format
  blocks_wide <- data.table::dcast(
    good_blocks[, .(block_id, direction_id, trip_id)],
    block_id ~ direction_id,
    value.var = "trip_id"
  )
  data.table::setnames(blocks_wide, c("0", "1"), c("dir0", "dir1"))

  # Get trip_lengths
  trip_lengths_m <- stop_times[, .(length = max(shape_dist_traveled, na.rm = TRUE)), by = trip_id]

  # Get number of stops per trip
  trip_lengths_stations <- stop_times[, .(n_stops = .N), by = trip_id]

  # Mirror to direction 0
  mirror_to_dir_0 <- stop_times_with_names[trip_id %in% blocks_wide$dir1]
  mirror_to_dir_0 <- trip_lengths_m[mirror_to_dir_0, on = "trip_id"]
  mirror_to_dir_0 <- trip_lengths_stations[mirror_to_dir_0, on = "trip_id"]
  data.table::setnames(mirror_to_dir_0, "trip_id", "source_trip_id")
  mirror_to_dir_0 <- blocks_wide[, .(source_trip_id = dir1, trip_id = dir0)][
    mirror_to_dir_0,
    on = "source_trip_id"
  ]
  mirror_to_dir_0[, `:=`(
    shape_dist_traveled = shape_dist_traveled - length,
    stop_sequence = stop_sequence - n_stops,
    virtual = TRUE,
    direction_id = 0L
  )]
  mirror_to_dir_0[, c("length", "n_stops") := NULL]

  # Mirror to direction 1
  mirror_to_dir_1 <- stop_times_with_names[trip_id %in% blocks_wide$dir0]
  data.table::setnames(mirror_to_dir_1, "trip_id", "source_trip_id")
  mirror_to_dir_1 <- blocks_wide[, .(source_trip_id = dir0, trip_id = dir1)][
    mirror_to_dir_1,
    on = "source_trip_id"
  ]
  mirror_to_dir_1 <- trip_lengths_m[mirror_to_dir_1, on = "trip_id"]
  mirror_to_dir_1 <- trip_lengths_stations[mirror_to_dir_1, on = "trip_id"]
  mirror_to_dir_1[, `:=`(
    shape_dist_traveled = shape_dist_traveled + length,
    stop_sequence = stop_sequence + n_stops,
    virtual = TRUE,
    direction_id = 1L
  )]
  mirror_to_dir_1[, c("length", "n_stops") := NULL]

  # City loop stations
  city_loop_stations <- c(
    "Flagstaff Station",
    "Melbourne Central Station",
    "Parliament Station",
    "Southern Cross Station",
    "Flinders Street Station"
  )

  # Combine all stop_times
  combined_list <- data.table::rbindlist(
    list(stop_times_with_names, mirror_to_dir_0, mirror_to_dir_1),
    fill = TRUE
  )

  combined_list <- combined_list[, "direction_id" := NULL]

  # Classify trips
  combined_list[, has_virtual := any(!is.na(virtual) & virtual == TRUE), by = trip_id]
  combined_list[has_virtual == TRUE,
                has_city_loop := all(city_loop_stations %in% stop_name),
                by = trip_id]
  combined_list[has_virtual == TRUE,
                n_duplicates := sum(duplicated(stop_name)),
                by = trip_id]

  # Fill NAs for non-virtual trips
  combined_list[is.na(has_city_loop), has_city_loop := FALSE]
  combined_list[is.na(n_duplicates), n_duplicates := 0L]

  # Create trip_type
  combined_list[, trip_type := data.table::fcase(
    !has_virtual, "Simple",
    has_city_loop, "City Loop",
    n_duplicates == 1, "Through Run",
    default = "Simple"
  )]

  # Filter rows
  combined_list <- combined_list[
    is.na(virtual) | !virtual |
      (trip_type == "City Loop" & stop_name %in% city_loop_stations) |
      (trip_type == "Through Run")
  ]

  # Handle duplicate stops at reversal points
  if(keep_overlap == FALSE){

    # Identify duplicates once
    combined_list[, n_occur := .N, by = .(trip_id, stop_id)]

    # Only process rows that are duplicates
    if (combined_list[n_occur > 1, .N] > 0) {
      # Add occurrence only for duplicates
      combined_list[n_occur > 1, occurrence := seq_len(.N), by = .(trip_id, stop_id)]

      # Get first arrival time (from virtual stop, which appears first)
      combined_list[n_occur > 1 & occurrence == 1, first_arrival := arrival_time]
      combined_list[, first_arrival := first_arrival[1], by = .(trip_id, stop_id)]

      # Transfer arrival time to second occurrence (the real stop)
      combined_list[occurrence == 2, arrival_time := first_arrival]

      # Remove first occurrences (virtual duplicates)
      combined_list <- combined_list[is.na(occurrence) | occurrence != 1]

      # Mark retained stops as non-virtual and clear source
      combined_list[occurrence == 2, virtual := FALSE]
      combined_list[occurrence == 2, source_trip_id := NA]

      # Clean up
      combined_list[, c("n_occur", "occurrence", "first_arrival") := NULL]
    } else {
      combined_list[, n_occur := NULL]
    }
  }

  # Clean up and sort
  combined_list[, c("has_virtual", "has_city_loop", "n_duplicates", "stop_name") := NULL]
  data.table::setorder(combined_list, trip_id, stop_sequence)

  # Return modified GTFS object
  out <- metro_train_gtfs
  out$stop_times <- combined_list

  return(out)
}
