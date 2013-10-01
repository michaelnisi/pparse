//
//  AtomTests.m
//  pparse
//
//  Created by Michael Nisi on 01.10.13.
//  Copyright (c) 2013 Michael Nisi. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MNFeedParser.h"
#import "FeedParserTestDelegate.h"

@interface AtomTests : XCTestCase

@end

@implementation AtomTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testFeedTitle {
    FeedParserTestDelegate *delegate = [FeedParserTestDelegate new];
    MNFeedParser *parser = [MNFeedParser parserWith:delegate dateFormatter:nil];
    
    NSString *a = @"<feed>";
    NSString *b = @"<title>The Talk Show With John Gruber</title>";
    NSString *c = @"</feed>";
    
    NSString *xml = [NSString stringWithFormat:@"%@%@%@", a, b, c];
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertTrue([parser parse:data]);
    XCTAssertNil(delegate.parseError);
    XCTAssertTrue(delegate.started);
    XCTAssertFalse(delegate.ended);
    XCTAssertTrue([parser parse:nil]);
    XCTAssertTrue(delegate.ended);
    
    MNFeed *feed = delegate.show;
    NSString *title = @"The Talk Show With John Gruber";
    XCTAssertTrue([feed.title isEqualToString:title]);
}

- (void)testStream {
    FeedParserTestDelegate *delegate = [FeedParserTestDelegate new];
    NSDateFormatter *dateFormatter = nil;
    MNFeedParser *parser = [MNFeedParser parserWith:delegate
                                      dateFormatter:dateFormatter];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"atom" ofType:@"xml"];
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    
    [parser parseStream:stream withMaxLength:1 << arc4random() % 10];
    
    XCTAssertTrue(delegate.started);
    XCTAssertNil(delegate.parseError);
    XCTAssertTrue(delegate.ended);
    
    MNFeed *feed = delegate.show;
    NSString *title = @"Example Feed";
    XCTAssertTrue([feed.title isEqualToString:title]);
}

@end
