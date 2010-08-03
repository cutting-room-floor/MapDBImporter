#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

int error_die (NSString *message)
{
    printf("%s", [[@"\n" stringByAppendingString:message] cStringUsingEncoding:NSUTF8StringEncoding]);

    return 1;
}

int main (int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSDictionary *args = [[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain];
    
    NSError *error;

    NSArray *allowedFormats = [NSArray arrayWithObjects:@"png", @"jpg", nil];
    
    // check for required args
    //
    if ( ! [args objectForKey:@"f"] || ! [allowedFormats containsObject:[args objectForKey:@"f"]] || ! [args objectForKey:@"s"] || ! [args objectForKey:@"d"])
    {
        NSString *usageString = [NSString stringWithFormat:@"Usage: %@ -f (%@) [-m<key1> <value1> [-m<key2> <value2>] ... ] [-M <metadata file>] -s <tile source directory> -d <destination mbtiles file>\n", [NSString stringWithCString:argv[0] encoding:NSUTF8StringEncoding], [allowedFormats componentsJoinedByString:@","]];
        
        return error_die(usageString);
    }
    
    // check for metadata args
    //
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    
    for (NSString *key in [args allKeys])
        if ([key hasPrefix:@"m"])
            [metadata setObject:[args objectForKey:key] forKey:[key substringWithRange:NSMakeRange(1, [key length] - 1)]];
    
    if ([[metadata allKeys] count] == 0)
        printf("%s", [@"WARNING: No metadata provided!" cStringUsingEncoding:NSUTF8StringEncoding]);

    // read in metadata file
    //
    if ([args objectForKey:@"M"])
    {
        NSString *metadataFile = [NSString stringWithContentsOfFile:[args objectForKey:@"M"] encoding:NSUTF8StringEncoding error:&error];
        
        if (error)
            return error_die([NSString stringWithFormat:@"Unable to read metadata file %@\n", [args objectForKey:@"M"]]);
        
        for (NSString *pair in [metadataFile componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
        {
            if ([[pair componentsSeparatedByString:@" = "] count] >= 2)
            {
                NSArray *parts = [pair componentsSeparatedByString:@" = "];
                
                [metadata setObject:[parts objectAtIndex:1] forKey:[parts objectAtIndex:0]];
            }
        }
    }
    
    NSString *source      = [args objectForKey:@"s"];
    NSString *destination = [args objectForKey:@"d"];
    NSString *format      = [args objectForKey:@"f"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // check for source file
    //
    BOOL isDirectory = NO;
    
    if ( ! [fileManager fileExistsAtPath:source isDirectory:&isDirectory] || ! isDirectory)
        return error_die([NSString stringWithFormat:@"Source directory not found at %@\n", source]);
    
    // check for destination file
    //
    if ([fileManager fileExistsAtPath:destination])
        return error_die([NSString stringWithFormat:@"Destination file exists at %@\n", destination]);
    
    // open & create database
    //
    FMDatabase *db = [FMDatabase databaseWithPath:destination];
    
    if ([db open])
    {
        // main tile records
        //
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
        
        // metadata records
        //
        [db executeUpdate:@"create table metadata (name text, value text)"];
        [db executeUpdate:@"create unique index name on metadata (name)"];

        for (NSString *key in [metadata allKeys])
            [db executeUpdate:@"insert into metadata (name, value) values (?, ?)", key, [metadata objectForKey:key]];
                
        [db close];
        
        printf("%s", [[NSString stringWithFormat:@"\nSuccessfully inserted %qlu records with %i metadata pairs at %@\n", count, [[metadata allKeys] count], destination] cStringUsingEncoding:NSUTF8StringEncoding]);
    }

    else
        return error_die([NSString stringWithFormat:@"Unable to open destination database at %@\n", destination]);
    
    [pool drain];
    
    return 0;
}