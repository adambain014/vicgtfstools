#' Download the latest Victorian GTFS schedule
#'
#' @description
#' Downloads the most recent GTFS schedule from the Victorian Government
#' website and saves it to a folder for further extraction.
#'
#' @param to Directory where the GTFS files should be saved.
#'
#' @return The path to the folder where the GTFS files were extracted.
#'
#' @export
download_latest_vic_gtfs <- function(to = "gtfs") {

  # Ensure long  timeout for likely 200+ MB file (10min)
  options(timeout = max(600, getOption("timeout")))

  gtfs_url <- "https://opendata.transport.vic.gov.au/dataset/3f4e292e-7f8a-4ffe-831f-1953be0fe448/resource/fb152201-859f-4882-9206-b768060b50ad/download/gtfs.zip"

  # Create output directory if needed
  if (!dir.exists(to)) {
    dir.create(to, recursive = TRUE)
  }

  # Download destination
  zip_path <- file.path(to, "gtfs.zip")

  # Download the gtfs file
  download.file(
    url      = gtfs_url,
    destfile = zip_path,
    mode     = "wb"
  )

  # Unzip into the target directory
  unzip(zip_path, exdir = to)

  # Remove the ZIP file
  file.remove(paste0(to, ".zip"))

  invisible(to)
}
