//
//  SearchResultParser.h
//  podparse
//
//  Created by Michael Nisi on 12/4/12.
//  Copyright (c) 2012 Michael Nisi. All rights reserved.
//

#pragma mark - PPSearchResultItem

@interface PPSearchResultItem : NSObject
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *feedURL;
@property (nonatomic) NSDate *releaseDate;
@property (nonatomic) NSString *artworkURL60;
@end

#pragma mark - SearchResultParserDelegate

@class SearchResultParser;

@protocol SearchResultParserDelegate <NSObject>
@optional
- (void)parser:(SearchResultParser *)parser parseErrorOccurred:(NSError *)parseError;
- (void)parser:(SearchResultParser *)parser foundCount:(NSUInteger)resultCount;
- (void)parser:(SearchResultParser *)parser foundItem:(PPSearchResultItem *)item;
- (void)parserDidEnd:(SearchResultParser *)parser;
@end

#pragma mark - SearchResultParser

@interface SearchResultParser : NSObject
@property (nonatomic, assign) id <SearchResultParserDelegate> delegate;
- (BOOL)parse:(NSData *)data;
- (void)abortParsing;
@end

extern NSString * const SearchResultParserErrorDomain;

typedef NS_ENUM(NSInteger, SearchResultParserError) {
    SearchResultParserInternalError = 1,
    SearchResultParserDelegateAbortedParseError = 512
};
