#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

int error_die (NSString *message)
{
    printf("%s", [message cStringUsingEncoding:NSUTF8StringEncoding]);

    return 1;
}

int main (int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSMutableArray *args = [NSMutableArray array];
    
    NSError *error;

    NSArray *allowedFormats = [NSArray arrayWithObjects:@"png", @"jpg", nil];
    
    // parse args into objc
    //
    if (argc > 1)
    {
        for (NSUInteger i = 1; i < argc; i++)
            [args addObject:[NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding]];
    }

    // check for overwrite
    //
    BOOL forceOverwrite = [args containsObject:@"-f"];
    
    if (forceOverwrite)
        [args removeObject:@"-f"];
    
    // check for format
    //
    NSString *format = nil;
    
    for (NSString *allowedFormat in allowedFormats)
        if ([args containsObject:[NSString stringWithFormat:@"--format=%@", allowedFormat]])
            format = allowedFormat;
    
    [args filterUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF BEGINSWITH %@", @"--format="]];

    // check for number of args
    //
    if ([args count] < 2 || ! format)
    {
        NSString *usageString = [NSString stringWithFormat:@"Usage: %@ [-f] --format=(%@) <tile source directory> <destination SQLite file>\n", [NSString stringWithCString:argv[0] encoding:NSUTF8StringEncoding], [allowedFormats componentsJoinedByString:@","]];
        
        return error_die(usageString);
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *source      = [args objectAtIndex:0];
    NSString *destination = [args objectAtIndex:1];
    
    // check for source file
    //
    BOOL isDirectory = NO;
    
    if ( ! [fileManager fileExistsAtPath:source isDirectory:&isDirectory] || ! isDirectory)
        return error_die([NSString stringWithFormat:@"Source directory not found at %@\n", source]);
    
    // check for destination file
    //
    if ([fileManager fileExistsAtPath:destination] && ! forceOverwrite)
        return error_die([NSString stringWithFormat:@"Destination file exists at %@ (-f to force overwrite)\n", destination]);
    
    // remove destination if necessary
    //
    if ([fileManager fileExistsAtPath:destination] && forceOverwrite)
    {
        [fileManager removeItemAtPath:destination error:&error];
        
        if (error)
            return error_die([NSString stringWithFormat:@"Unable to remove destination file at %@\n", destination]);
    }
    
    // open & create database
    //
    FMDatabase *db = [FMDatabase databaseWithPath:destination];
    
    if ([db open])
    {
        [db executeUpdate:@"create table tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob)"];
        [db executeUpdate:@"create unique index tile_index on tiles (zoom_level, tile_column, tile_row)"];
        
        NSUInteger count = 0;
        
        NSArray *zooms = [fileManager contentsOfDirectoryAtPath:source error:NULL];
        
        // iterate zoom folders
        //
        for (NSString *zoom in zooms)
        {
            NSArray *columns = [fileManager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/%@", source, zoom] error:NULL];

            // iterate column folders
            //
            for (NSString *column in columns)
            {
                [db beginTransaction];                

                NSAutoreleasePool *columnPool = [[NSAutoreleasePool alloc] init];
                
                NSArray *rows = [fileManager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/%@/%@", source, zoom, column] error:NULL];

                // iterate row files
                //
                for (NSString *row in rows)
                {
                    if (format && [row hasSuffix:format])
                    {
                        NSString *filePath = [NSString stringWithFormat:@"%@/%@/%@/%@", source, zoom, column, row];
                        
                        NSData *data = [NSData dataWithContentsOfFile:filePath];
                        
                        if ( ! data)
                            return error_die([NSString stringWithFormat:@"Unable to read source file at %@\n", filePath]);
                        
                        row = [row stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@", format] withString:@""];
                        
                        [db executeUpdate:@"insert into tiles (zoom_level, tile_column, tile_row, tile_data) values (?, ?, ?, ?)", [NSNumber numberWithInt:[zoom integerValue]],
                                                                                                                                   [NSNumber numberWithInt:[column integerValue]],
                                                                                                                                   [NSNumber numberWithInt:[row integerValue]],
                                                                                                                                   data];
                        
                        if ([db hadError])
                            return error_die([NSString stringWithFormat:@"Problem inserting record %i,%i,%i into destination database: %@\n", [zoom integerValue], [column integerValue], [row integerValue], [db lastErrorMessage]]);

                        else
                            count++;
                    }
                }
                
                [db commit];
                
                [columnPool drain];
            }
        }
                     
        [db close];
        
        printf("%s", [[NSString stringWithFormat:@"Successfully inserted %qlu records at %@\n", count, destination] cStringUsingEncoding:NSUTF8StringEncoding]);
    }

    else
        return error_die([NSString stringWithFormat:@"Unable to open destination database at %@\n", destination]);
    
    [pool drain];
    
    return 0;
}