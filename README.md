# vicgtfstools

<!-- badges: start -->
<!-- badges: end -->

Tools for downloading, opening, and processing General Transit Feed Specification (GTFS) data from Public Transport Victoria (PTV).

## Installation

You can install the development version of vicgtfstools from GitHub:
```r
# install.packages("devtools")
devtools::install_github("adambain014/vicgtfstools")
```

## Overview

`vicgtfstools` provides a streamlined workflow for working with Victorian public transport data:

- **Download** the latest GTFS schedule from the PTV open data portal
- **Open** individual transport mode feeds (trains, trams, buses, etc.)
- **Join** multiple feeds while preserving mode metadata
- **Combine** all available modes into a single unified dataset

All GTFS feeds are automatically tagged with `mode_number` and `mode_name` columns for easy filtering and analysis.

## Quick Start

### Download the latest Victorian GTFS data
```r
library(vicgtfstools)

# Download and extract all GTFS feeds
download_latest_vic_gtfs("gtfs")
```

This creates a directory structure like:
```
gtfs/
├── 1/google_transit.zip    # Regional Train
├── 2/google_transit.zip    # Metro Train
├── 3/google_transit.zip    # Metro Tram
├── 4/google_transit.zip    # Metro Bus
├── 5/google_transit.zip    # Regional Coach
├── 6/google_transit.zip    # Regional Bus
├── 10/google_transit.zip   # Interstate
└── 11/google_transit.zip   # SkyBus
```

### Open a specific transport mode
```r
# Load Metro Train GTFS feed
metro_train <- open_vic_gtfs("gtfs", "Metro_Train")

# Explore the data
head(metro_train$routes)
head(metro_train$stops)
```

### Join two modes
```r
# Load and combine Metro Train and Tram
train <- open_vic_gtfs("gtfs", "Metro_Train")
tram  <- open_vic_gtfs("gtfs", "Metro_Tram")

combined <- join_vic_gtfs(train, tram)

# Filter by mode
train_routes <- combined$routes[combined$routes$mode_name == "Metro_Train", ]
tram_routes  <- combined$routes[combined$routes$mode_name == "Metro_Tram", ]
```

### Open all modes at once
```r
# Load and combine all available GTFS feeds
all_gtfs <- open_and_join_all_vic_gtfs("gtfs")

# All tables now include mode_number and mode_name columns
head(all_gtfs$routes)
table(all_gtfs$routes$mode_name)
```

## Supported Transport Modes

| Mode Number | Mode Name         | Description           |
|-------------|-------------------|-----------------------|
| 1           | Regional_Train    | Regional train services |
| 2           | Metro_Train       | Melbourne metro trains |
| 3           | Metro_Tram        | Melbourne trams |
| 4           | Metro_Bus         | Melbourne metro buses |
| 5           | Regional_Coach    | Regional coach services |
| 6           | Regional_Bus      | Regional bus services |
| 10          | Interstate        | Interstate services |
| 11          | SkyBus            | SkyBus airport services |

## Functions

- `download_latest_vic_gtfs()` - Download and extract the latest Victorian GTFS data
- `open_vic_gtfs()` - Open a specific transport mode's GTFS feed
- `join_vic_gtfs()` - Join two GTFS feeds with mode metadata
- `open_and_join_all_vic_gtfs()` - Open and combine all available feeds

## Data Source

GTFS data is sourced from the [Public Transport Victoria Open Data Portal](https://opendata.transport.vic.gov.au/). The data is updated regularly by PTV and includes schedules, routes, stops, and service information for all Victorian public transport modes.

## Requirements

- R >= 4.0.0
- Internet connection (for downloading GTFS data)
- ~500 MB disk space (for extracted GTFS files)

## Dependencies

- `gtfstools` - For reading GTFS feeds
- `dplyr` - For data manipulation
- `rlang` - For utilities
- `utils` - For downloading and extracting files

## License

MIT License - see [LICENSE](LICENSE) file for details

## Contributing

Please feel free to submit a PR

## Issues

Found a bug or have a feature request? Please open an issue on [GitHub](https://github.com/yourusername/vicgtfstools/issues).

## Acknowledgments

- Data provided by Public Transport Victoria (PTV)
- Built using the [`gtfstools`](https://ipeagit.github.io/gtfstools/) package
