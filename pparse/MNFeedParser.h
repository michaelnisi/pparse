//
//  PodcastParser.h
//  podparse
//
//  Created by Michael Nisi on 15.10.12.
//  Copyright (c) 2012 Michael Nisi. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - MNFeed

@interface MNFeed : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *link;
@property (nonatomic) NSString *subtitle;
@property (nonatomic) NSString *author;
@property (nonatomic) NSString *summary;
@property (nonatomic) NSString *image;

@end

#pragma mark - MNFeedEntry

@interface MNFeedEntry : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *author;
@property (nonatomic) NSString *subtitle;
@property (nonatomic) NSString *summary;
@property (nonatomic) NSString *url;
@property (nonatomic) NSString *guid;
@property (nonatomic) NSDate *pubDate;

- (id)initWithTitle:(NSString *)title
             author:(NSString *)author
           subtitle:(NSString *)subtitle
            summary:(NSString *)summary
                url:(NSString *)url
               guid:(NSString *)guid
            pubDate:(NSDate *)pubDate;

+ (MNFeedEntry*)entryWithTitle:(NSString *)title
                        author:(NSString *)author
                      subtitle:(NSString *)subtitle
                       summary:(NSString *)summary
                           url:(NSString *)url
                          guid:(NSString *)guid
                       pubDate:(NSDate *)pubDate;

- (BOOL)isEqualToEntry:(MNFeedEntry *)entry;

@end

#pragma mark - MNFeedParserDelegate

@class MNFeedParser;

@protocol MNFeedParserDelegate <NSObject>

@optional
- (void)parserDidStart:(MNFeedParser *)parser;
- (void)parserDidEnd:(MNFeedParser *)parser;
- (void)parser:(MNFeedParser *)parser foundShow:(MNFeed *)show;
- (void)parser:(MNFeedParser *)parser foundEpisode:(MNFeedEntry *)episode;
- (void)parser:(MNFeedParser *)parser parseErrorOccurred:(NSError *)parseError;

@end

#pragma mark - MNFeedParser

@interface MNFeedParser : NSObject

@property (nonatomic, assign) id <MNFeedParserDelegate> delegate;

- (BOOL)parse:(NSData *)data;
- (void)abortParsing;
- (id)initWith:(id <MNFeedParserDelegate>)delegate
 dateFormatter:(NSDateFormatter *)dateFormatter;

+ (MNFeedParser *)parserWith:(id <MNFeedParserDelegate>)delegate
                dateFormatter:(NSDateFormatter *)dateFormatter;

@end
