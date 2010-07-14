# MapDBImporter

MapDBImporter is a simple command-line Objective-C tool to take a folder of MapBox tiles and put them in a SQLite database. 

It's a little rough right now; sorry about that.

## Usage

You will need to edit the two `#define` statements at the top to point to your desired destination SQLite file path and your tile directory source path.

You might want to replace the occurrences of `png` with `jpg` depending on your need.

The tool will output the MD5 hash of the PNG data from each zoom/column/row record. You can compare this to the original hash using something like `find /src/path -type f | xargs md5sum` to check import integrity.