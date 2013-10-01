//
//  AFeedReader.h
//  pparse
//
//  Created by Michael Nisi on 01.10.13.
//  Copyright (c) 2013 Michael Nisi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MNFeedParser.h"

@interface FeedParserTestDelegate : NSObject <MNFeedParserDelegate>

@property (nonatomic) MNFeed *show;
@property (nonatomic) NSMutableArray *episodes;
@property (nonatomic) NSError *parseError;
@property (nonatomic) BOOL started;
@property (nonatomic) BOOL ended;

- (MNFeedEntry *)entryAtIndex:(NSUInteger)index;

@end
