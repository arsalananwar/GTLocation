//
//  GTGoogleGeocoder.m
//  GTLocation
//
//  Created by Gianluca Tranchedone http://gtranchedone.com
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013 Gianluca Tranchedone
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "GTGoogleGeocoder.h"

@implementation GTGoogleGeocoder

#pragma mark - Public APIs -
#pragma mark Google Place APIs

+ (void)searchLocationsMatchingAddress:(NSString *)address apiKey:(NSString *)apiKey completionBlock:(void (^)(NSArray *results, NSError *error))completionBlock
{
	NSString *geocodingBaseUrl = @"https://maps.googleapis.com/maps/api/place/textsearch/json?";
	NSString *stringURL = [NSString stringWithFormat:@"%@query=%@&language=en&sensor=true&key=%@", geocodingBaseUrl, address, apiKey];

	stringURL = [stringURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	[self performQueryWithURL:[NSURL URLWithString:stringURL] address:address completionBlock:completionBlock];
}

+ (void)searchLocationsMatchingAddress:(NSString *)address nearLocation:(CLLocation *)location apiKey:(NSString *)apiKey completionBlock:(void (^)(NSArray *results, NSError *error))completionBlock
{
    if (!location) {
        [self searchLocationsMatchingAddress:address apiKey:apiKey completionBlock:completionBlock];
    }
    else {
        CLLocationCoordinate2D coordinate = location.coordinate;
        NSString *geocodingBaseUrl = @"https://maps.googleapis.com/maps/api/place/nearbysearch/json?";
        NSString *stringURL = [NSString stringWithFormat:@"%@keyword=%@&language=en&sensor=true&key=%@", geocodingBaseUrl, address, apiKey];
        stringURL = [stringURL stringByAppendingFormat:@"&location=%f,%f&radius=50000", coordinate.latitude, coordinate.longitude];
        stringURL = [stringURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [self performQueryWithURL:[NSURL URLWithString:stringURL] address:address completionBlock:^(NSArray *results, NSError *error) {
            if (!error && !results.count) {
                NSError *err = nil;
                NSDataDetector *addressDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeAddress error:&err];
                
                if (!err && [addressDetector numberOfMatchesInString:address options:NSMatchingReportCompletion range:NSMakeRange(0, address.length)]) {
                    [self geocodeAddress:address withCompletionBlock:^(CLLocation *theLocation, NSError *theError) {
                        if (completionBlock) {
                            NSArray *theResults = theLocation ? @[theLocation] : @[];
                            completionBlock(theResults, theError);
                        }
                    }];
                }
	            else if (completionBlock) {
	                completionBlock(nil, nil);
                }
            }
            else if (completionBlock) {
                completionBlock(results, error);
            }
        }];
    }
}

#pragma mark Google Maps APIs

+ (void)geocodeAddress:(NSString *)address withCompletionBlock:(void (^)(CLLocation *, NSError *))completionBlock
{
    NSString *geocodingBaseUrl = @"http://maps.googleapis.com/maps/api/geocode/json?";
    NSString *stringURL = [NSString stringWithFormat:@"%@address=%@&sensor=true", geocodingBaseUrl, address];
    stringURL = [stringURL stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    
    [self resumeDataTaskWithURL:[NSURL URLWithString:stringURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        CLLocation *location = nil;
        if (data && !error) {
            NSError *jsonError = nil;
            NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                           options:NSJSONReadingAllowFragments
	                                                                         error:&jsonError];
            
            if (jsonDictionary && !jsonError) {
                location = [self locationFromResponseDictionary:jsonDictionary];
            }
            else {
                error = jsonError;
            }
        }

	    if (completionBlock) {
		    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
			    completionBlock(location, error);
		    }];
	    }
    }];
}

+ (void)reverseGeocodeLocationWithCoordinate:(CLLocationCoordinate2D)coordinate completionBlock:(void (^)(GTPlacemark *, NSError *))completionBlock
{
    NSString *geocodingBaseUrl = @"http://maps.googleapis.com/maps/api/geocode/json?";
    NSString *formattedCoordinateString = [NSString stringWithFormat:@"%f,%f", coordinate.latitude, coordinate.longitude];
    NSString *stringURL = [NSString stringWithFormat:@"%@latlng=%@&sensor=true", geocodingBaseUrl, formattedCoordinateString];
    stringURL = [stringURL stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    
    [self resumeDataTaskWithURL:[NSURL URLWithString:stringURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        GTPlacemark *placemark = nil;
        if (data && !error) {
            NSError *jsonError = nil;
            NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
            
            if (jsonDictionary && !jsonError) {
                placemark = [self placemarkFromPlaceResponseDictionary:jsonDictionary];
            }
            else {
                error = jsonError;
            }
        }

	    if (completionBlock) {
		    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
			    completionBlock(placemark, error);
		    }];
	    }
    }];
}

#pragma mark - Private APIs -

+ (NSURLSessionDataTask *)resumeDataTaskWithURL:(NSURL *)queryURL completionHandler:(void (^)(NSData *responseData, NSURLResponse *response, NSError *networkError))block
{
    NSURLRequest *request = [NSURLRequest requestWithURL:queryURL cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:10];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:block];
    
    [task resume];
    
    return task;
}

+ (void)performQueryWithURL:(NSURL *)queryURL address:(NSString *)address completionBlock:(void (^)(NSArray *results, NSError *error))completionBlock
{
    address = [address lowercaseString];
    [self resumeDataTaskWithURL:queryURL completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *networkError) {
        NSError *error = nil;
        NSMutableArray *results = [NSMutableArray array];
        
        if (responseData && !networkError) {
            NSError *jsonError = nil;
            NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:responseData
                                                                           options:NSJSONReadingAllowFragments
	                                                                         error:&jsonError];
            
            if (jsonDictionary && !jsonError) {
                NSString *status = [jsonDictionary objectForKey:@"status"];
                if (![status isEqualToString:@"OK"] && ![status isEqualToString:@"ZERO_RESULTS"]) {
                    error = [NSError errorWithDomain:GTGoogleGeocoderErrorDomain code:1 userInfo:jsonDictionary];
                }
                else {
                    NSArray *googleResults = [jsonDictionary objectForKey:@"results"];
                    [googleResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        __block NSInteger numberOfWords = 0;
                        __block NSInteger numberOfMatches = 0;
                        NSString *name = [[obj objectForKey:@"name"] lowercaseString];
                        
                        [name enumerateSubstringsInRange:NSMakeRange(0, name.length) options:NSStringEnumerationByWords usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *shouldStop) {
                            numberOfWords++;
                            if ([address rangeOfString:substring].location != NSNotFound) {
                                numberOfMatches++;
                            }
                        }];
                        
                        if ((numberOfWords == numberOfMatches) || numberOfMatches >= (NSInteger)floorf(numberOfWords / 2.0f)) {
                            [results addObject:[self locationFromResponseDictionary:obj]];
                        }
                    }];
                }
            }
            else {
                error = jsonError;
            }
        }
        else {
            error = networkError;
        }

	    if (completionBlock) {
		    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
			    completionBlock(results, error);
		    }];
	    }
    }];
}

+ (GTPlacemark *)placemarkFromPlaceResponseDictionary:(NSDictionary *)dictionary
{
    // TODO: missing implementation
    return nil;
}

+ (CLLocation *)locationFromResponseDictionary:(NSDictionary *)dictionary
{
    NSArray *results = [dictionary objectForKey:@"results"];
    if (results.count) {
        dictionary = [results objectAtIndex:0];
    }
    
    if (dictionary) {
        NSDictionary *geometry = [dictionary objectForKey:@"geometry"];
        NSDictionary *location = [geometry objectForKey:@"location"];
        NSNumber *lat = [location objectForKey:@"lat"];
        NSNumber *lng = [location objectForKey:@"lng"];
        
        if (lat && lng) {
            return [[CLLocation alloc] initWithLatitude:lat.doubleValue longitude:lng.doubleValue];
        }
        else {
            return nil;
        }
    }
    else {
        return nil;
    }
}

@end

NSString * const GTGoogleGeocoderErrorDomain = @"com.gtranchedone.GTGoogleGeocoder";
