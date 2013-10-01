//
//  RSSTests.m
//  pparse
//
//  Created by Michael Nisi on 01.10.13.
//  Copyright (c) 2013 Michael Nisi. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MNFeedParser.h"
#import "AFeedReader.h"

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
    AFeedReader *delegate = [AFeedReader new];
    MNFeedParser *parser = [MNFeedParser parserWith:delegate dateFormatter:nil];
    
    NSString *a = @"<rss><channel>";
    NSString *b = @"<title>The Talk Show With John Gruber</title>";
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
    NSString *title = @"The Talk Show With John Gruber";
    XCTAssertTrue([feed.title isEqualToString:title]);
}

@end
