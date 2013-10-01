//
//  ITunesTests.m
//  podparse
//
//  Created by Michael Nisi on 1/12/13.
//  Copyright (c) 2013 Michael Nisi. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MNFeedParser.h"
#import "FeedParserTestDelegate.h"

@interface ITunesTests : XCTestCase <MNFeedParserDelegate>
@property (nonatomic) NSArray *episodes;
@end

@interface ITunesTests ()
@property (nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic) NSLocale *locale;
@end

@implementation ITunesTests

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [NSDateFormatter new];        
        [_dateFormatter setLocale:self.locale];
        [_dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    }
    
    return _dateFormatter;
}

- (NSLocale *)locale {
    if (!_locale) {
        _locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    }
    
    return _locale;
}

- (NSDate *)dateWithYear:(NSInteger)year
                   month:(NSInteger)month
                     day:(NSInteger)day
                    hour:(NSInteger)hour {
    return [self dateWithYear:year month:month day:day hour:hour minute:0 second:0];
}

- (NSDate *)dateWithYear:(NSInteger)year
                   month:(NSInteger)month
                     day:(NSInteger)day
                    hour:(NSInteger)hour
                  minute:(NSInteger)minute
                  second:(NSInteger)second {
    
    NSDateComponents *comps = [NSDateComponents new];
    
    [comps setDay:day];
    [comps setMonth:month];
    [comps setYear:year];
    [comps setHour:hour];
    [comps setMinute:minute];
    [comps setSecond:second];
    
    [comps setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    
    NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:comps];
    
    return date;
}

- (NSArray *)episodes {
    if (!_episodes) {
        _episodes = @[[self episodeWithTitle:@"Shake Shake Shake Your Spices"
                                      author:@"John Doe"
                                    subtitle:@"A short primer on table spices"
                                     summary:@"This week we talk about salt and pepper shakers, comparing and contrasting pour rates, construction materials, and overall aesthetics. Come and join the party!"
                                         url:@"http://example.com/podcasts/everything/AllAboutEverythingEpisode3.m4a"
                                        guid:@"http://example.com/podcasts/archive/aae20050615.m4a"
                                     pubDate:[self dateWithYear:2005 month:06 day:15 hour:19]],
                      [self episodeWithTitle:@"Socket Wrench Shootout"
                                      author:@"Jane Doe"
                                    subtitle:@"Comparing socket wrenches is fun!"
                                     summary:@"This week we talk about metric vs. old english socket wrenches. Which one is better? Do you really need both? Get all of your answers here."
                                         url:@"http://example.com/podcasts/everything/AllAboutEverythingEpisode2.mp3"
                                        guid:@"http://example.com/podcasts/archive/aae20050608.mp3"
                                     pubDate:[self dateWithYear:2005 month:06 day:8 hour:19]],
                      [self episodeWithTitle:@"Red, Whine, & Blue"
                                      author:@"Various"
                                    subtitle:@"Red + Blue != Purple"
                                     summary:@"This week we talk about surviving in a Red state if you are a Blue person. Or vice versa."
                                         url:@"http://example.com/podcasts/everything/AllAboutEverythingEpisode1.mp3"
                                        guid:@"http://example.com/podcasts/archive/aae20050601.mp3"
                                     pubDate:[self dateWithYear:2005 month:06 day:01 hour:19]]
                      ];
    }
    
    return _episodes;
}

- (MNFeedEntry *)episodeWithTitle:(NSString *)title
                                        author:(NSString *)author
                                      subtitle:(NSString *)subtitle
                                       summary:(NSString *)summary
                                           url:(NSString *)url
                                          guid:(NSString *)guid
                                       pubDate:(NSDate *)pubDate {
    
    MNFeedEntry *entry = [MNFeedEntry new];
    entry.title = title;
    entry.author = author;
    entry.subtitle = subtitle;
    entry.summary = summary;
    entry.url = url;
    entry.guid = guid;
    entry.pubDate = pubDate;
    return entry;
}
            

- (MNFeedEntry *)getEpisode:(NSUInteger)index {
    return [self.episodes objectAtIndex:index];
}

- (void)measureParsingTime {
    FeedParserTestDelegate *delegate = [FeedParserTestDelegate new];
    NSDateFormatter *dateFormatter = [self dateFormatter];
    MNFeedParser *parser = [MNFeedParser parserWith:delegate dateFormatter:dateFormatter];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"itunes" ofType:@"xml"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    
    NSDate *start = [NSDate date];
    [parser parse:data];
    NSDate *end = [NSDate date];
    NSTimeInterval time = [end timeIntervalSinceDate:start];
    NSLog(@"took %f", time);
}

- (void)testOptionalDelegate {
    NSDateFormatter *dateFormatter = [self dateFormatter];
    MNFeedParser *parser = [MNFeedParser parserWith:self dateFormatter:dateFormatter];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"itunes" ofType:@"xml"];
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    
    @try {
        [parser parseStream:stream withMaxLength:1 << arc4random() % 10];
    }
    @catch (NSException *exception) {
        XCTAssertTrue(NO, @"should not throw");
    }
    @finally {
        XCTAssertTrue(YES, @"yes yes");
    }
}

- (void)testDate {
    FeedParserTestDelegate *delegate = [FeedParserTestDelegate new];
    NSDateFormatter *dateFormatter = [self dateFormatter];
    MNFeedParser *parser = [MNFeedParser parserWith:delegate dateFormatter:dateFormatter];
    
    NSString *a = @"<xml><rss><channel>";
    NSString *b = @"<item><pubDate>Wed, 15 Jun 2005 19:00:00 GMT</pubDate></item>";
    NSString *c = @"<item><pubDate>Fri, 25 Jan 2013 19:53:21 +0000</pubDate></item>";
    NSString *d = @"<item><pubDate>Fri, 15 Mar 2013 02:43:26 -0400</pubDate></item>";
    NSString *e = @"</channel></rss>";
    
    NSString *xml = [NSString stringWithFormat:@"%@%@%@%@%@", a, b, c, d, e];
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];

    [parser parse:data];
    
    NSArray *expectedDates = @[[self dateWithYear:2005 month:06 day:15 hour:19]
                             , [self dateWithYear:2013 month:01 day:25 hour:19 minute:53 second:21]
                             , [self dateWithYear:2013 month:03 day:15 hour:6 minute:43 second:26]];
    
    XCTAssertEqual(delegate.episodes.count, expectedDates.count, @"should match");
    
    [expectedDates enumerateObjectsUsingBlock:^(NSDate *expectedDate, NSUInteger i, BOOL *stop) {
        MNFeedEntry *episode = [delegate entryAtIndex:i];
        NSDate *date = episode.pubDate;
        XCTAssertTrue([date isEqualToDate:expectedDate], @"should be expected date");
    }];
}

- (void)testAppleReferenceFeed {
    FeedParserTestDelegate *delegate = [FeedParserTestDelegate new];
    NSDateFormatter *dateFormatter = [self dateFormatter];
    MNFeedParser *parser = [MNFeedParser parserWith:delegate dateFormatter:dateFormatter];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"itunes" ofType:@"xml"];
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];

    [parser parseStream:stream withMaxLength:1 << arc4random() % 10];

    NSArray *expected = @[
        [self getEpisode:0],
        [self getEpisode:1],
        [self getEpisode:2]
    ];
    
    [expected enumerateObjectsUsingBlock:^(MNFeedEntry *a, NSUInteger i, BOOL *stop) {
        MNFeedEntry *b = [delegate entryAtIndex:i];
        XCTAssertNotNil(a, @"should not be nil");
        XCTAssertNotNil(b, @"should not be nil");
        XCTAssertTrue([a.title isEqualToString:b.title]);
        XCTAssertTrue([a.subtitle isEqualToString:b.subtitle]);
        XCTAssertTrue([a.summary isEqualToString:b.summary]);
    }];
    
    XCTAssertTrue(delegate.started, @"should be started");
    XCTAssertTrue(delegate.ended, @"should be ended");
    XCTAssertNil(delegate.parseError, @"should not error");
    
    MNFeed *show = delegate.show;
    
    XCTAssertNotNil(show, @"should be set");
    XCTAssertTrue([show.title isEqualToString:@"All About Everything"], @"should be equal");
    
    XCTAssertTrue([show.link isEqualToString:@"http://www.example.com/podcasts/everything/index.html"], @"should be equal");
    
    XCTAssertTrue([show.subtitle isEqualToString:@"A show about everything"], @"should be equal");
    
    XCTAssertTrue([show.author isEqualToString:@"John Doe"], @"should be equal");
    
    XCTAssertTrue([show.summary isEqualToString:@"All About Everything is a show about everything. Each week we dive into any subject known to man and talk about it as much as we can. Look for our Podcast in the iTunes Store"], @"should be equal");

    XCTAssertTrue([show.image isEqualToString:@"http://example.com/podcasts/everything/AllAboutEverything.jpg"], @"should be equal");
}

@end
