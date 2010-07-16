# MapDBImporter

MapDBImporter is a simple command-line Objective-C tool to take a folder of MapBox tiles and put them in a SQLite database. 

## Usage

`MapDBImporter [-f] --format=(png,jpg) <tile source directory> <destination SQLite file>`

### Arguments

`-f`

Force removal of destination file if it already exists.

`--format=(png,jpg)`

Choose which type of file to use if both are found in the tile folders.

`<tile source directory>`

The path to the folder containing the `zoom` folders, which contain `y` folders, which contain `x` files.

`<destination SQLite file>`

The desired output file. It's recommended to use `filename.mbtiles`.