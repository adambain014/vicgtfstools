#' Open a Specific Victorian GTFS Feed
#'
#' @description
#' Selects and loads a specific Victorian GTFS feed based on the chosen
#' public transport mode. This function assumes that the GTFS archive has
#' already been downloaded and extracted into the standard PTV folder
#' structure, where each mode is stored in a numbered subdirectory.
#'
#' The returned GTFS object includes a \code{$mode} list with elements
#' \code{$number} (the PTV mode number) and \code{$name} (the mode name),
#' which can be used for subsequent filtering or joining operations.
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
#' @return
#' A GTFS object as returned by \code{gtfstools::read_gtfs()}, with an
#' additional \code{$mode} list element containing:
#' \itemize{
#'   \item \code{$number}: the PTV mode number (e.g., 2 for Metro Train)
#'   \item \code{$name}: the mode name as specified in the \code{mode} argument
#' }
#'
#' @details
#' The function maps human‑readable mode names to the numeric folder
#' structure used in the Victorian GTFS distribution. It validates both
#' the mode and the existence of the parent directory before attempting
#' to read the feed.
#'
#' @examples
#' \dontrun{
#' # Load the Metro Train GTFS feed
#' metro <- open_vic_gtfs("gtfs", "Metro_Train")
#'
#' # Check mode metadata
#' metro$mode  # list(number = 2, name = "Metro_Train")
#' }
#'
#' @export
open_vic_gtfs <- function(parent, mode){
  number <- dplyr::case_when(
    mode == "Regional_Train" ~ 1,
    mode == "Metro_Train"    ~ 2,
    mode == "Metro_Tram"     ~ 3,
    mode == "Metro_Bus"      ~ 4,
    mode == "Regional_Coach" ~ 5,
    mode == "Regional_Bus"   ~ 6,
    mode == "Interstate"     ~ 10,
    mode == "SkyBus"         ~ 11,
    .default = NA_real_
  )
  if (!number %in% c(1:6, 10:11)) {
    stop("`mode` must be one of the supported Victorian GTFS modes.")
  }
  if (!dir.exists(parent)) {
    stop(paste0(parent, " does not exist."))
  }
  target_gtfs_location <- paste0(parent, "/", number, "/google_transit.zip")
  gtfs <- gtfstools::read_gtfs(target_gtfs_location)
  # Add mode metadata
  gtfs$mode <- list(
    number = number,
    name   = mode
  )
  gtfs
}
