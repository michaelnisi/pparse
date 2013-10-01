//
//  RSSTests.m
//  pparse
//
//  Created by Michael Nisi on 01.10.13.
//  Copyright (c) 2013 Michael Nisi. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MNFeedParser.h"
#import "FeedParserTestDelegate.h"

@interface RSSTests : XCTestCase
@end

@implementation RSSTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testFeedTitle {
    FeedParserTestDelegate *delegate = [FeedParserTestDelegate new];
    MNFeedParser *parser = [MNFeedParser parserWith:delegate dateFormatter:nil];
    
    NSString *a = @"<rss><channel>";
    NSString *b = @"<title>Logbuch:Netzpolitik</title>";
    NSString *c = @"</channel></rss>";
    
    NSString *xml = [NSString stringWithFormat:@"%@%@%@", a, b, c];
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertTrue([parser parse:data]);
    XCTAssertNil(delegate.parseError);
    XCTAssertTrue(delegate.started);
    XCTAssertFalse(delegate.ended);
    XCTAssertTrue([parser parse:nil]);
    XCTAssertTrue(delegate.ended);
    
    MNFeed *feed = delegate.show;
    NSString *title = @"Logbuch:Netzpolitik";
    XCTAssertTrue([feed.title isEqualToString:title]);
}

- (void)testStream {
    FeedParserTestDelegate *delegate = [FeedParserTestDelegate new];
    NSDateFormatter *dateFormatter = nil;
    MNFeedParser *parser = [MNFeedParser parserWith:delegate
                                      dateFormatter:dateFormatter];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"rss2" ofType:@"xml"];
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    
    [parser parseStream:stream withMaxLength:1 << arc4random() % 10];
    
    XCTAssertTrue(delegate.started);
    XCTAssertNil(delegate.parseError);
    XCTAssertTrue(delegate.ended);
    
    MNFeed *feed = delegate.show;
    NSString *title = @"Liftoff News";
    XCTAssertTrue([feed.title isEqualToString:title]);
}

@end
