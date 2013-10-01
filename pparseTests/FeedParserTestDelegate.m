//
//  AFeedReader.m
//  pparse
//
//  Created by Michael Nisi on 01.10.13.
//  Copyright (c) 2013 Michael Nisi. All rights reserved.
//

#import "FeedParserTestDelegate.h"

@implementation FeedParserTestDelegate

- (void)parser:(MNFeedParser *)parser foundEpisode:(MNFeedEntry *)episode {
    if (!_episodes) {
        _episodes = [NSMutableArray new];
    }
    
    [_episodes addObject:episode];
}

- (void)parser:(MNFeedParser *)parser foundShow:(MNFeed *)show {
    _show = show;
}

- (void)parser:(MNFeedParser *)parser parseErrorOccurred:(NSError *)parseError {
    _parseError = parseError;
}

- (void)parserDidStart:(MNFeedParser *)parser {
    _started = YES;
}

- (void)parserDidEnd:(MNFeedParser *)parser {
    _ended = YES;
}

- (MNFeedEntry *)entryAtIndex:(NSUInteger)index {
    return (MNFeedEntry *)[_episodes objectAtIndex:index];
}

@end
