#' Download the Latest Victorian GTFS Schedule
#'
#' @description
#' Downloads the most recent Victorian GTFS schedule from the Victorian
#' Department of Transport and Planning's open data portal and extracts it
#' into a local directory. The download includes all public transport modes
#' (trains, trams, buses, coaches) organized into numbered subdirectories
#' corresponding to the department's mode classification system.
#'
#' The dataset is published in standardized GTFS (General Transit Feed
#' Specification) format and is updated weekly or as needed. The data
#' contains a rolling 30-day window from the date of export.
#'
#' @param to
#' A character string specifying the directory where GTFS files should be
#' saved and extracted. Defaults to `"gtfs"`. The directory will be
#' created if it does not exist.
#'
#' @return
#' Invisibly returns the path to the directory containing the extracted
#' GTFS feeds (same as the \code{to} argument). The extracted structure
#' contains numbered subdirectories (e.g., `1/`, `2/`, `3/`) where each
#' subdirectory represents a transport mode and contains a
#' `google_transit.zip` file.
#'
#' @details
#' This function performs the following steps:
#' \enumerate{
#'   \item Sets a 10-minute download timeout to accommodate the large file
#'         size (typically 200+ MB)
#'   \item Creates the target directory if it doesn't exist
#'   \item Downloads the GTFS archive from the Department of Transport and
#'         Planning open data portal
#'   \item Extracts all contents into the specified directory
#'   \item Removes the downloaded ZIP file to save disk space
#' }
#'
#' The extracted GTFS feeds are organized by transport mode number:
#' \itemize{
#'   \item `1/` = Regional Train
#'   \item `2/` = Metro Train
#'   \item `3/` = Metro Tram
#'   \item `4/` = Myki Bus (Metro Bus and Regional Town Bus)
#'   \item `5/` = Regional Coach
#'   \item `6/` = Regional Bus
#'   \item `10/` = Interstate
#'   \item `11/` = SkyBus
#' }
#'
#' Each numbered subdirectory contains a `google_transit.zip` file with
#' the GTFS data for that mode.
#'
#' **Data Features:**
#' The Victorian GTFS dataset includes enhanced features beyond the basic
#' GTFS specification:
#' \itemize{
#'   \item **Transfers**: Transfer information in `transfers.txt`
#'   \item **Wheelchair accessibility**: Accessibility data for trips and stops
#'   \item **Pathways**: Detailed path links within stations
#'   \item **Platform information**: Platform numbers and locations for metro trains
#'   \item **Bus replacement services**: Dedicated stops and trip information
#'   \item **Station levels**: Multi-level station information
#' }
#'
#' **Data Currency and Coverage:**
#' \itemize{
#'   \item Updated weekly or as needed
#'   \item Contains rolling 30 days of data from export date
#'   \item Some route information may be incomplete for the full period if
#'         service details are not yet available
#'   \item Path information generated using automatic algorithms and manual
#'         pathing (may contain inaccuracies)
#' }
#'
#' @note
#' This function requires an active internet connection and sufficient
#' disk space (approximately 400-500 MB after extraction). The download
#' may take several minutes depending on connection speed.
#'
#' The data is published under Creative Commons Attribution 4.0
#' International License.
#'
#' @source
#' \url{https://opendata.transport.vic.gov.au/dataset/gtfs-schedule}
#'
#' @examples
#' \dontrun{
#' # Download to default "gtfs" directory
#' download_latest_vic_gtfs()
#'
#' # Download to a custom location
#' download_latest_vic_gtfs("data/vic_gtfs")
#'
#' # Then open specific feeds
#' metro <- open_vic_gtfs("gtfs", "Metro_Train")
#'
#' # Or open all feeds at once
#' all_modes <- open_and_join_all_vic_gtfs("gtfs")
#' }
#'
#' @export
download_latest_vic_gtfs <- function(to = "gtfs") {
  # Ensure long timeout for likely 200+ MB file (10min)
  options(timeout = max(600, getOption("timeout")))
  gtfs_url <- "https://opendata.transport.vic.gov.au/dataset/3f4e292e-7f8a-4ffe-831f-1953be0fe448/resource/fb152201-859f-4882-9206-b768060b50ad/download/gtfs.zip"
  # Create output directory if needed
  if (!dir.exists(to)) {
    dir.create(to, recursive = TRUE)
  }
  # Download destination
  zip_path <- file.path(to, "gtfs.zip")
  # Download the GTFS file
  download.file(
    url      = gtfs_url,
    destfile = zip_path,
    mode     = "wb"
  )
  # Unzip into the target directory
  unzip(zip_path, exdir = to)
  # Remove the ZIP file
  file.remove(zip_path)
  invisible(to)
}
