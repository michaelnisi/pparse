//
//  PodcastParser.h
//  podparse
//
//  Created by Michael Nisi on 15.10.12.
//  Copyright (c) 2012 Michael Nisi. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - PodcastFeedParserShow

@interface PodcastFeedParserShow : NSObject
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *link;
@property (nonatomic) NSString *subtitle;
@property (nonatomic) NSString *author;
@property (nonatomic) NSString *summary;
@property (nonatomic) NSString *image;
@end

#pragma mark - PodcastFeedParserEpisode

@interface PodcastFeedParserEpisode : NSObject
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

+ (PodcastFeedParserEpisode*)episodeWithTitle:(NSString *)title
                      author:(NSString *)author
                    subtitle:(NSString *)subtitle
                     summary:(NSString *)summary
                         url:(NSString *)url
                        guid:(NSString *)guid
                     pubDate:(NSDate *)pubDate;
- (BOOL)isEqualToEpisode:(PodcastFeedParserEpisode *)episode;
@end

#pragma mark - PodcastParserDelegate

@class MNFeedParser;

@protocol PodcastParserDelegate <NSObject>
@optional
- (void)parserDidStart:(MNFeedParser *)parser;
- (void)parserDidEnd:(MNFeedParser *)parser;
- (void)parser:(MNFeedParser *)parser foundShow:(PodcastFeedParserShow *)show;
- (void)parser:(MNFeedParser *)parser foundEpisode:(PodcastFeedParserEpisode *)episode;
- (void)parser:(MNFeedParser *)parser parseErrorOccurred:(NSError *)parseError;
@end

#pragma mark - PodcastParser

@interface MNFeedParser : NSObject
@property (nonatomic, assign) id <PodcastParserDelegate> delegate;
- (BOOL)parse:(NSData *)data;
- (void)abortParsing;

- (id)initWith:(id <PodcastParserDelegate>)delegate
 dateFormatter:(NSDateFormatter *)dateFormatter;

+ (MNFeedParser *)parserWith:(id <PodcastParserDelegate>)delegate
                dateFormatter:(NSDateFormatter *)dateFormatter;

@end
