#' Open a Specific Victorian GTFS Feed
#'
#' @description
#' Selects and loads a specific Victorian GTFS feed based on the chosen
#' public transport mode. This function assumes that the GTFS archive has
#' already been downloaded and extracted into the standard Department of
#' Transport and Planning folder structure, where each mode is stored in
#' a numbered subdirectory.
#'
#' By default, the function adds \code{mode_number} and \code{mode_name}
#' columns to all data tables within the GTFS object, making it easy to
#' identify the transport mode when working with combined datasets.
#'
#' @param parent
#' A character string giving the path to the parent directory containing
#' the extracted GTFS mode folders.
#'
#' @param mode
#' A character string specifying the transport mode to open. Supported
#' values are:
#' `"Regional_Train"`, `"Metro_Train"`, `"Metro_Tram"`, `"Metro_Bus"`,
#' `"Regional_Coach"`, `"Regional_Bus"`, `"Interstate"`, `"SkyBus"`.
#'
#' @param tag_mode
#' Logical; if `TRUE` (default), adds `mode_number` and `mode_name` columns
#' to all data tables in the GTFS object. Set to `FALSE` to return the
#' raw GTFS object without mode tagging.
#'
#' @return
#' A GTFS object as returned by \code{gtfstools::read_gtfs()}.
#'
#' If \code{tag_mode = TRUE} (default), all data tables include:
#' \itemize{
#'   \item \code{mode_number}: the Department of Transport mode number
#'         (e.g., 2 for Metro Train)
#'   \item \code{mode_name}: the mode name as specified in the \code{mode}
#'         argument
#' }
#'
#' Empty tables are handled safely by adding zero-length columns of the
#' appropriate type.
#'
#' @details
#' The function maps human-readable mode names (and their numeric codes) to
#' the folder structure used in the Victorian GTFS distribution. Each mode
#' number accepts either an underscore-style or space-style name:
#'
#' \itemize{
#'   \item `1` = Regional Train (`"Regional_Train"` or `"Regional Train"`)
#'   \item `2` = Metro Train (`"Metro_Train"` or `"Metropolitan Train"`)
#'   \item `3` = Metro Tram (`"Metro_Tram"` or `"Metropolitan Tram"`)
#'   \item `4` = Myki Bus — Metro Bus and Regional Town Bus
#'         (`"Metro_Bus"` or `"Metro Bus"`)
#'   \item `5` = Regional Coach (`"Regional_Coach"` or `"Regional Coach"`)
#'   \item `6` = Regional Bus (`"Regional_Bus"` or `"Regional Bus"`)
#'   \item `10` = Interstate
#'   \item `11` = SkyBus
#' }
#'
#' Numeric codes (e.g. `2`, `"2"`) are also accepted directly for any mode.
#'
#' The function validates both the mode and the existence of the parent
#' directory before attempting to read the feed.
#'
#' Mode tagging is essential for workflows that combine multiple GTFS feeds,
#' as it preserves mode identity throughout join operations.
#'
#' @examples
#' \dontrun{
#' # Load the Metro Train GTFS feed with mode tagging
#' metro <- open_vic_gtfs("gtfs", "Metro_Train")
#'
#' # Check that mode columns are present
#' head(metro$trips[, c("trip_id", "mode_number", "mode_name")])
#'
#' # Load without mode tagging
#' metro_raw <- open_vic_gtfs("gtfs", "Metro_Train", tag_mode = FALSE)
#' }
#'
#' @export
open_vic_gtfs <- function(parent, mode, tag_mode = TRUE){

  # Lookup table
  mode_lookup <- c(
    "Regional_Train"        = 1,
    "Regional Train"        = 1,
    "Metro_Train"           = 2,
    "Metropolitan Train"    = 2,
    "Metro_Tram"            = 3,
    "Metropolitan Tram"     = 3,
    "Metro_Bus"             = 4,
    "Metro Bus"             = 4,
    "Regional_Coach"        = 5,
    "Regional Coach"        = 5,
    "Regional_Bus"          = 6,
    "Regional Bus"          = 6,
    "Interstate"            = 10,
    "SkyBus"                = 11,
    "Skybus"                = 11,
    "skybus"                = 11
  )

  if (is.character(mode)) {
    number <- unname(mode_lookup[mode])
  } else {
    number <- as.numeric(mode)
  }

  if (length(number) == 0 || is.na(number) || !number %in% c(1:6, 10:11)) {
    stop("`mode` must be one of the supported Victorian GTFS modes.")
  }

  if (!dir.exists(parent)) {
    stop(paste0(parent, " does not exist."))
  }

  target_gtfs_location <- paste0(parent, "/", number, "/google_transit.zip")
  gtfs <- gtfstools::read_gtfs(target_gtfs_location)

  if (tag_mode) {
    add_mode_cols <- function(gtfs) {
      mode_number <- number
      mode_name   <- mode
      for (tbl in names(gtfs)) {
        if (is.data.frame(gtfs[[tbl]])) {
          n <- nrow(gtfs[[tbl]])
          if (n > 0) {
            gtfs[[tbl]]$mode_number <- rep(mode_number, n)
            gtfs[[tbl]]$mode_name   <- rep(mode_name, n)
          } else {
            gtfs[[tbl]]$mode_number <- numeric(0)
            gtfs[[tbl]]$mode_name   <- character(0)
          }
        }
      }
      gtfs$mode <- NULL
      gtfs
    }
    gtfs <- add_mode_cols(gtfs)
  }

  gtfs
}
