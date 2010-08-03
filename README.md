# MapDBImporter

MapDBImporter is a simple command-line tool to take a folder of MapBox tiles and put them in an *mbtiles* (SQLite database) file. 

---

## Usage

`MapDBImporter -f (png,jpg) [-m<key1> <value1> [-m<key2> <value2>] ... ] [-M <metadata file>] -s <source directory> -d <destination file>`

---

### Arguments

`-f (png,jpg)`

Choose which type of file to use in case both are found in the tile folders.

---

`-m<key1> <value1>`

Add metadata to the tile set. Use quotes for terms with spaces.

        -mName "World Light" -mDescription "A simple, light grey world map"

---

`-M <metadata file>`

Pass an `.ini`-style file of key/value pairs for metadata. Do not use quotes around terms with spaces.

        Name = World Light
        Description = A simple, light grey world map

---

`-s <source directory>`

The path to the folder containing the *zoom* folders, which contain *y* folders, which contain *x* files.

---

`-d <destination file>`

The desired output file. It is recommended to use the format `World_Light_1.0.mbtiles` for the *World Light* tile set version *1.0*.