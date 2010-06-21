#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#include <openssl/md5.h>

#define DS_DB_PATH    (@"/Users/incanus/Documents/Projects/Development Seed/Mapping/stuff to not backup/world-light.sql")
#define DS_TILES_PATH (@"/Volumes/MAPSONSTICK/tiles/1.0.0/world-light")

int main (int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    //[fileManager removeItemAtPath:DS_DB_PATH error:NULL];
    
    FMDatabase *db = [FMDatabase databaseWithPath:DS_DB_PATH];
    
    if ([db open])
    {
        FMResultSet *select = [db executeQuery:@"select zoom_level, tile_column, tile_row, tile_data from tiles"];
        
        if ([db hadError])
            NSLog(@"error selecting: %@", [db lastErrorMessage]);
        
        while ([select next])
        {
            NSData *data = [select dataForColumn:@"tile_data"];

            unsigned char *result = MD5([data bytes], [data length], NULL);
            
            NSString *hash = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                    result[0],  result[1],  result[2],  result[3], 
                    result[4],  result[5],  result[6],  result[7],
                    result[8],  result[9],  result[10], result[11],
                    result[12], result[13], result[14], result[15]];
            
            NSLog(@"MD5 (./%qlu/%qlu/%qlu.png) = %@", [select intForColumn:@"zoom_level"], [select intForColumn:@"tile_column"], [select intForColumn:@"tile_row"], hash);
        }
        
        [select close];
        
        [db close];
        
        [pool drain];
        
        return 0;
        
        [db executeUpdate:@"create table tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob)"];
        [db executeUpdate:@"create unique index tile_index on tiles (zoom_level, tile_column, tile_row)"];
        
        NSUInteger count = 0;
        
        NSArray *zooms = [fileManager contentsOfDirectoryAtPath:DS_TILES_PATH error:NULL];
        
        //NSLog(@"there are %qlu zooms total", [zooms count]);
        
        for (NSString *zoom in zooms)
        {
            NSArray *columns = [fileManager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/%@", DS_TILES_PATH, zoom] error:NULL];

            //NSLog(@"there are %qlu columns in zoom %@", [columns count], zoom);

            for (NSString *column in columns)
            {
                [db beginTransaction];                

                NSAutoreleasePool *columnPool = [[NSAutoreleasePool alloc] init];
                
                NSArray *rows = [fileManager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/%@/%@", DS_TILES_PATH, zoom, column] error:NULL];

                //NSLog(@"there are %qlu rows in column %@ of zoom %@", [rows count], column, zoom);

                for (NSString *row in rows)
                {
                    if ([row hasSuffix:@".png"])
                    {
                        NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/%@/%@", DS_TILES_PATH, zoom, column, row]];
                        
                        row = [row stringByReplacingOccurrencesOfString:@".png" withString:@""];
                        
                        //NSLog(@"z:%@ c:%@ r:%@ d:%qlu", zoom, column, row, [data length]);
                        
                        [db executeUpdate:@"insert into tiles (zoom_level, tile_column, tile_row, tile_data) values (?, ?, ?, ?)", [NSNumber numberWithInt:[zoom integerValue]],
                                                                                                                                   [NSNumber numberWithInt:[column integerValue]],
                                                                                                                                   [NSNumber numberWithInt:[row integerValue]],
                                                                                                                                   data];
                        
                        if ([db hadError])
                            NSLog(@"error with entry %qlu: %@", count, [db lastErrorMessage]);
                        
                        else
                            count++;
                    }
                }
                
                [db commit];
                
                NSLog(@"completed column %@ for zoom %@", column, zoom);
                
                [columnPool drain];
            }
        }
                     
        [db close];
        
        NSLog(@"inserted %qlu records", count);
    }

    else
        NSLog(@"can't open db");
    
    [pool drain];
    
    return 0;
}