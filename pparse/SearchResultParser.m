//
//  SearchResultParser.m
//  podparse
//
//  Created by Michael Nisi on 12/4/12.
//  Copyright (c) 2012 Michael Nisi. All rights reserved.
//

#import <yajl/yajl_parse.h>
#import "SearchResultParser.h"

@implementation PPSearchResultItem
@end

NSString * const SearchResultParserErrorDomain = @"SearchResultParserErrorDomain";

static yajl_callbacks callbacks;

@interface SearchResultParser ()
@property (nonatomic) yajl_handle handle;
@property (nonatomic) PPSearchResultItem *item;
@property (nonatomic) NSError *error;
@property (nonatomic) BOOL cancelled;
@property (nonatomic) NSDateFormatter *dateFormatter;

#pragma mark - Parser state

@property BOOL count;
@property BOOL results;
@property BOOL result;
@property BOOL title;
@property BOOL feedURL;
@property BOOL artworkURL30;
@property BOOL artworkURL60;
@property BOOL artworkURL100;
@property BOOL artworkURL600;
@property BOOL releaseDate;
@end

@implementation SearchResultParser

- (yajl_handle)handle {
    if (!_handle) {
      _handle = yajl_alloc(&callbacks, NULL, (__bridge void *)(self));  
    }
    
    return _handle;
}

- (BOOL)parse:(NSData *)data {
    if (!data) {
        if (_handle) {
            yajl_free(_handle);
        }
        
        [_delegate parserDidEnd:self];
        
        _handle = nil;
        return NO;
    }
    
    if (_cancelled || !_delegate) return NO;
    
    yajl_status stat;
    
    stat = yajl_parse(self.handle, data.bytes, data.length);
    if (stat != yajl_status_ok) {
        [self delegateError];
        return NO;
    }

    return YES;
}

- (NSError *)error {
    NSInteger code = SearchResultParserInternalError;
    
    if (_cancelled) {
        code = SearchResultParserDelegateAbortedParseError;
    }

    return [NSError errorWithDomain:SearchResultParserErrorDomain
                               code:code
                           userInfo:nil];
}

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    }
    
    return _dateFormatter;
}

- (void)abortParsing {
    _cancelled = YES;
    
    [self parse:nil];
    [self delegateError];
}

#pragma mark - Delegate

- (void)delegateResultCount:(NSUInteger)resultCount {
    if (_cancelled || ![_delegate respondsToSelector:@selector(parser: foundCount:)]) return;
    [_delegate parser:self foundCount:resultCount];
}

- (void)delegateError {
    if ([_delegate respondsToSelector:@selector(parser: parseErrorOccurred:)]) {
        [_delegate parser:self parseErrorOccurred:self.error];
    }
}

- (void)delegateItem {
    if (_cancelled || ![_delegate respondsToSelector:@selector(parser: foundItem:)]) return;
    [_delegate parser:self foundItem:self.item];
    _item = nil;
}

@end

#pragma mark - YAJL callbacks

#define PODPARSE_SEARCH_RESULT_PARSER(ctx) (__bridge SearchResultParser *)ctx
#define PODPARSE_STRNCMP(a, b, l) !strncmp(a, (const char *)b, l)
#define PODPARSE_STRNMAKE(v, l) [[NSString alloc] initWithBytes:v length:l encoding:NSUTF8StringEncoding];

static const char *resultCountKey = "resultCount";
static const char *resultsKey = "results";
static const char *titleKey = "trackName";
static const char *feedURLKey = "feedUrl";
static const char *artworkURL60Key = "artworkUrl60";
static const char *releaseDateKey = "releaseDate";

static int
stringCallback (void *ctx, const unsigned char *stringVal, size_t stringLen) {
    SearchResultParser *parser = PODPARSE_SEARCH_RESULT_PARSER(ctx);
    PPSearchResultItem *item = parser.item;
    
    if (parser.title) item.title = PODPARSE_STRNMAKE(stringVal, stringLen);
    if (parser.feedURL) item.feedURL = PODPARSE_STRNMAKE(stringVal, stringLen);
    if (parser.artworkURL60) item.artworkURL60 = PODPARSE_STRNMAKE(stringVal, stringLen);
    if (parser.releaseDate) {
        NSString *str = PODPARSE_STRNMAKE(stringVal, stringLen);
        item.releaseDate = [parser.dateFormatter dateFromString:str];
    }
    
    return YES;
}

static int integerCallback (void *ctx, long long integerVal) {
    SearchResultParser *parser = PODPARSE_SEARCH_RESULT_PARSER(ctx);
    
    if (parser.count) {
        [parser delegateResultCount:integerVal];
    }
    
    return YES;
}

static int startMapCallback(void *ctx) {
    SearchResultParser *parser = PODPARSE_SEARCH_RESULT_PARSER(ctx);
    
    if (parser.results) {
        parser.item = [PPSearchResultItem new];
        parser.result = YES;
    }
    
    return YES;
}

static int
mapKeyCallback (void * ctx, const unsigned char * stringVal, size_t stringLen) {
    SearchResultParser *parser = PODPARSE_SEARCH_RESULT_PARSER(ctx);

    parser.count = PODPARSE_STRNCMP(resultCountKey, stringVal, stringLen);
    parser.title = PODPARSE_STRNCMP(titleKey, stringVal, stringLen);
    parser.feedURL = PODPARSE_STRNCMP(feedURLKey, stringVal, stringLen);
    parser.artworkURL60 = PODPARSE_STRNCMP(artworkURL60Key, stringVal, stringLen);
    parser.releaseDate = PODPARSE_STRNCMP(releaseDateKey, stringVal, stringLen);
    
    if (PODPARSE_STRNCMP(resultsKey, stringVal, stringLen)) {
        parser.results = YES;
    }
    
    return YES;
}

static int endMapCallback(void *ctx) {
    SearchResultParser *parser = PODPARSE_SEARCH_RESULT_PARSER(ctx);
    
    if (parser.results && parser.result) {
        [parser delegateItem];
    }
    
    parser.result = NO;
    
    return YES;
}

static yajl_callbacks callbacks = {
    NULL,
    NULL,
    integerCallback,
    NULL,
    NULL,
    stringCallback,
    startMapCallback,
    mapKeyCallback,
    endMapCallback,
    NULL,
    NULL
};