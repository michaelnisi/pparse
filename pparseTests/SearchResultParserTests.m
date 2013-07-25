//
//  SearchResultParserTests.m
//  podparse
//
//  Created by Michael Nisi on 1/9/13.
//  Copyright (c) 2013 Michael Nisi. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "pparse.h"

@interface SearchResultParserTests : XCTestCase
- (void)pipe:(NSInputStream *)stream parser:(SearchResultParser *)parser;
@end

#define MAKE_URL(obj,key) [NSURL URLWithString:[obj objectForKey:key]]

@interface PartialSearchResultDelegate : NSObject <SearchResultParserDelegate>

@end

@implementation PartialSearchResultDelegate
@end

# pragma mark - SearchResultConsumer

@interface SearchResultConsumer : NSObject <SearchResultParserDelegate>
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) NSError *parseError;
@property NSUInteger resultCount;
@property (nonatomic) BOOL ended;
- (NSArray *)flush;
- (PPSearchResultItem *)getItemAtIndex:(NSUInteger)index;
@end

@implementation SearchResultConsumer

- (NSMutableArray *)items {
    if (!_items) {
        _items = [NSMutableArray new];
    }
    
    return _items;
}

- (NSArray *)flush {
    NSArray *items = [NSArray arrayWithArray:_items];
    [_items removeAllObjects];
    return items;
}

- (PPSearchResultItem *)getItemAtIndex:(NSUInteger)index {
    return [_items objectAtIndex:index];
}

# pragma mark - SearchResultParserDelegate

- (void)parser:(SearchResultParser *)parser parseErrorOccurred:(NSError *)parseError {
    _parseError = parseError;
}

- (void)parser:(SearchResultParser *)parser foundCount:(NSUInteger)resultCount {
    _resultCount = resultCount;
}

- (void)parser:(SearchResultParser *)parser foundItem:(PPSearchResultItem *)item {
    [self.items addObject:item];
}

- (void)parserDidEnd:(SearchResultParser *)parser {
    _ended = YES;
}

@end

# pragma mark - SearchResultParserTests

@interface SearchResultParserTests ()
@property (nonatomic) SearchResultParser *parser;
@property (nonatomic) SearchResultConsumer *consumer;
@property (nonatomic) NSDateFormatter *dateFormatter;
@end

@implementation SearchResultParserTests

- (void)setUp {
    [super setUp];
    
    _consumer = [SearchResultConsumer new];
    _parser = [SearchResultParser new];
    _parser.delegate = _consumer;
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
}

- (void)tearDown {
    _parser.delegate = nil;
    _parser = nil;
    _consumer = nil;
    _dateFormatter = nil;
    
    [super tearDown];
}

- (void)testParseError {
    NSData *data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertNil(_consumer.parseError, @"");
    
    [_parser parse:data];
    
    NSError *error = _consumer.parseError;
    
    XCTAssertNotNil(error, @"");
    XCTAssertEquals(error.code, SearchResultParserInternalError, @"");
}

- (void)testPartialDelegate {
    PartialSearchResultDelegate *delegate = [PartialSearchResultDelegate new];
    _parser.delegate = delegate;
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"mobilemacs" ofType:@"json"];
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    
    @try {
        [self pipe:stream parser:_parser];
    }
    @catch (NSException *exception) {
        XCTAssertTrue(NO, @"should not throw");
    }
    @finally {
        XCTAssertTrue(YES, @"yes yes");
    }    
}

- (void)testReleaseDate {
    NSString *a = @"2012-11-28T02:32:00Z";
    NSDate *date = [_dateFormatter dateFromString:a];
    NSString *b = [_dateFormatter stringFromDate:date];
    
    XCTAssertTrue([a isEqualToString:b], @"");
}

- (void)testRepeatedAbort {    
    int count = 8;
    while (count--) [_parser abortParsing];
    
    [_parser parse:nil];
}

- (void)testNil {
    XCTAssertFalse(_consumer.ended, @"");
    [_parser parse:nil];
    XCTAssertTrue(_consumer.ended, @"");
}

- (void)testAbort {    
    NSDictionary *input = @{ @"results":@[ @{ @"title":@"Beep" } ] };
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:input
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    
    [_parser parse:json];
    
    int code = SearchResultParserInternalError;
    
    int count = 8;
    while (count--) {
        [_parser parse:json];
        if (rand() % 2) {
            [_parser abortParsing];
            code = SearchResultParserDelegateAbortedParseError;
        }
    }
    
    XCTAssertTrue([_consumer.parseError.domain isEqualToString:SearchResultParserErrorDomain], @"should be equal");
    XCTAssertEquals(_consumer.parseError.code, code, @"should be equal");
}

- (void)testReuse {
    // Initially the parser was not designed to be reusable,
    // but it slowly seems to be getting there.
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    
    NSString *a = [bundle pathForResource:@"mobilemacs" ofType:@"json"];
    NSInputStream *streamA = [NSInputStream inputStreamWithFileAtPath:a];
    
    [self pipe:streamA parser:_parser];
    XCTAssertFalse([_parser parse:nil], @"");
    XCTAssertEquals(_consumer.resultCount, 8U, @"");
    
    XCTAssertEquals([_consumer flush].count, 8U, @"");
    XCTAssertEquals(_consumer.items.count, 0U, @"");
    
    NSString *b = [bundle pathForResource:@"5by5" ofType:@"json"];
    NSInputStream *streamB = [NSInputStream inputStreamWithFileAtPath:b];
    [self pipe:streamB parser:_parser];
    XCTAssertFalse([_parser parse:nil], @"");
    XCTAssertEquals(_consumer.resultCount, 50U, @"");
}

- (void)testParse {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"mobilemacs" ofType:@"json"];
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];

    [self pipe:stream parser:_parser];
    
    XCTAssertFalse(_consumer.ended, @"");
    [_parser parse:nil];
    XCTAssertTrue(_consumer.ended, @"");
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data
                                                         options:kNilOptions
                                                           error:nil];
    
    NSArray *expected = [json objectForKey:@"results"];
    
    [expected enumerateObjectsUsingBlock:^(NSDictionary *expectedItem, NSUInteger i, BOOL *stop) {
        PPSearchResultItem *item = [_consumer getItemAtIndex:i];
        
        XCTAssertTrue([item.title isEqual:expectedItem[@"trackName"]], @"");
        XCTAssertTrue([item.feedURL isEqual:expectedItem[@"feedUrl"]], @"");
        XCTAssertTrue([item.artworkURL60 isEqual:expectedItem[@"artworkUrl60"]], @"");
        
        NSString *dateString = expectedItem[@"releaseDate"];
        NSDate *expectedDate = [_dateFormatter dateFromString:dateString];
        NSDate *date = item.releaseDate;
        
        // TODO: Evaluate usefulness of release date.
        if (expectedDate && date) { 
            XCTAssertTrue([date isEqualToDate:expectedDate], @"");
        }
    }];
    
    XCTAssertNil(_consumer.parseError, @"should not error");
}

- (void)pipe:(NSInputStream *)stream parser:(SearchResultParser *)parser {
    [stream open];
    
    NSInteger maxLength = 1 << arc4random() % 10;
    NSInteger result;
    uint8_t buffer[maxLength];
    
    while((result = [stream read:buffer maxLength:maxLength]) != 0) {
        if (result > 0) {
            [parser parse:[NSData dataWithBytesNoCopy:buffer
                                               length:result
                                         freeWhenDone:NO]];
        } else {
            break;
        }
    }
    
    [stream close];
}

@end
