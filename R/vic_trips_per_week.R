#' Calculate weekly trip frequency per service
#'
#' Selects a representative "typical" week from a GTFS feed's calendar and
#' calculates, for each trip, the number of times it runs during that week,
#' accounting for calendar_dates.txt exceptions. The result is attached to
#' \code{gtfs$trips} as a new \code{trips_per_week} column, and rows whose
#' service has no active days in the selected week are dropped.
#'
#' The representative week is chosen as the first full Monday-to-Sunday
#' week starting after the second Monday following the earliest
#' \code{start_date} in \code{gtfs$calendar} (i.e. the first Monday that is
#' more than 7 days after the calendar's overall start date). This is
#' intended to skip any partial or atypical opening week of the feed.
#'
#' Trip counts are built by expanding \code{gtfs$calendar} into one row per
#' service (and mode, if present) per day of the selected week, using the
#' day-of-week boolean columns (\code{monday}, \code{tuesday}, etc.).
#' \code{calendar_dates.txt} exceptions falling within the selected week are
#' then applied on top: \code{exception_type == 1} (service added) forces
#' the day to active, and \code{exception_type == 2} (service removed)
#' forces the day to inactive. This exception handling is idempotent, so a
#' redundant exception row (e.g. an added-service exception on a day the
#' base calendar already marks active) will not cause double-counting.
#'
#' The count of active service days is used directly as \code{trips_per_week}
#' rather than being joined per-trip and summed, because each \code{trip_id}
#' in GTFS runs at most once per service day. This means the number of
#' active days for a service is exactly equal to the number of times each
#' of its trips operates during the week, so no separate aggregation over
#' individual trip departures is required.
#'
#' Whether services are matched by \code{service_id} alone or by
#' \code{service_id} and \code{mode_number} together is determined
#' automatically based on whether \code{mode_number} exists in
#' \code{gtfs$trips}. This allows the function to work on both single-mode
#' and multi-modal (e.g. combined train/tram/bus) GTFS feeds without
#' modification.
#'
#' @param gtfs A GTFS list object (as used by \code{vicgtfstools}/
#'   \code{gtfstools}) containing at minimum \code{calendar},
#'   \code{calendar_dates}, and \code{trips} tables. If \code{trips}
#'   contains a \code{mode_number} column, services are matched by
#'   \code{(service_id, mode_number)}; otherwise by \code{service_id} alone.
#'
#' @return The input \code{gtfs} object with two modifications:
#'   \itemize{
#'     \item \code{gtfs$trips} gains a \code{trips_per_week} column giving
#'       the number of times each trip runs during the selected week (0-7).
#'       Trips whose service has zero active days in the selected week are
#'       dropped via an inner join (\code{nomatch = 0L}).
#'     \item \code{gtfs$calendar_window} is set to a list with
#'       \code{first_date} and \code{last_date}, giving the Monday and
#'       Sunday bounds of the week used for the calculation.
#'   }
#'
#' @import data.table
#' @export
vic_trips_per_week <- function(gtfs){
  days <- c("monday","tuesday","wednesday","thursday","friday","saturday","sunday")
  day_map <- setNames(0:6, days)
  cal <- gtfs$calendar
  trips <- gtfs$trips

  if ("mode_number" %chin% names(trips)) {
    keys <- c("service_id", "mode_number")
  } else {
    keys <- "service_id"
  }

  first_date <- min(cal[weekdays(start_date) == "Monday" &
                          start_date > min(cal$start_date) + 7]$start_date)
  last_date <- first_date + 6
  cal_week <- cal[start_date <= last_date & end_date >= first_date]

  cal_long <- melt(cal_week, id.vars = keys, measure.vars = days,
                   variable.name = "day", value.name = "bool")
  cal_long[, day_number := day_map[as.character(day)]]
  cal_long[, date := first_date + day_number]

  cd_week <- gtfs$calendar_dates[date %between% c(first_date, last_date)]

  setkeyv(cd_week, c("date", keys))
  setkeyv(cal_long, c("date", keys))
  cal_long[cd_week, exception_type := i.exception_type]
  cal_long[exception_type == 2, bool := 0L]
  cal_long[exception_type == 1, bool := 1L]

  calendar_refined <- cal_long[bool == 1, .(trips_per_week = .N), by = keys]

  trips <- trips[calendar_refined, on = keys, nomatch = 0L]

  gtfs$trips <- trips
  gtfs$calendar_window <- list(first_date = first_date, last_date = last_date)
  gtfs
}
