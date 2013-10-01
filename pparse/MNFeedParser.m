//
//  MNFeedParser.m
//  podparse
//
//  Created by Michael Nisi on 15.10.12.
//  Copyright (c) 2012 Michael Nisi. All rights reserved.
//

#import <libxml/tree.h>
#import "MNFeedParser.h"

#pragma mark - MNFeed

@implementation MNFeed
@end

#pragma mark - MNFeedEntry

@implementation MNFeedEntry

- (BOOL)isEqualToEntry:(MNFeedEntry *)entry {
    BOOL title = [self.title isEqualToString:entry.title];
    BOOL subtitle = [self.subtitle isEqualToString:entry.subtitle];
    BOOL summary = [self.summary isEqualToString:entry.summary];
    
    return title && subtitle && summary;
}

- (id)initWithTitle:(NSString *)title
             author:(NSString *)author
           subtitle:(NSString *)subtitle
            summary:(NSString *)summary
                url:(NSString *)url
               guid:(NSString *)guid
            pubDate:(NSDate *)pubDate {
    
    self = [super init];
    
    if (self) {
        _title = title;
        _author = author;
        _subtitle = subtitle;
        _summary = summary;
        _url = url;
        _guid = guid;
        _pubDate = pubDate;
    }
    
    return self;
}

+ (MNFeedEntry *)entryWithTitle:(NSString *)title
                         author:(NSString *)author
                       subtitle:(NSString *)subtitle
                        summary:(NSString *)summary
                            url:(NSString *)url
                           guid:(NSString *)guid
                        pubDate:(NSDate *)pubDate {
    
    return [[MNFeedEntry alloc] initWithTitle:title
                                       author:author
                                     subtitle:subtitle
                                      summary:summary
                                          url:url
                                         guid:guid
                                      pubDate:pubDate];
}

@end

#pragma mark - SAX callbacks (forward declaration)

static void startElementSAX(void *ctx,
                            const xmlChar *localname,
                            const xmlChar *prefix,
                            const xmlChar *URI,
                            int nb_namespaces,
                            const xmlChar **namespaces,
                            int nb_attributes,
                            int nb_defaulted,
                            const xmlChar **attributes);

static void	endElementSAX(void *ctx,
                          const xmlChar *localname,
                          const xmlChar *prefix,
                          const xmlChar *URI);

static void	charactersFoundSAX(void * ctx, const xmlChar * ch, int len);
static void errorEncounteredSAX(void * ctx, const char * msg, ...);
static void startDocumentSAX(void * ctx);
static void endDocumentSAX(void * ctx);

static xmlSAXHandler xmlSAXHandlerStruct;

struct _xmlSAX2Attributes {
    const xmlChar *localname;
    const xmlChar *prefix;
    const xmlChar *uri;
    const xmlChar *value;
    const xmlChar *end;
};
typedef struct _xmlSAX2Attributes xmlSAX2Attributes;

#pragma mark - MNFeedParser

@interface MNFeedParser ()

@property (nonatomic) BOOL parsingEpisode;
@property (nonatomic) BOOL bufferingChars;
@property (nonatomic) BOOL feedHandled;
@property (nonatomic) BOOL aborted;
@property (nonatomic, retain) NSMutableData *characterBuffer;
@property (nonatomic) MNFeedEntry *episode;
@property (nonatomic) MNFeed *feed;
@property (nonatomic) xmlParserCtxtPtr context;
@property (nonatomic) int count;
@property (nonatomic) NSDateFormatter *dateFormatter;

- (void)delegateError:(const char *)msg;
- (void)delegateEpisode;
- (void)delegateShow;
- (void)delegateDocumentStart;
- (void)delegateDocumentEnd;

@end

@implementation MNFeedParser

- (void)dealloc {
    if (_context) {
        xmlFreeParserCtxt(_context);
        _context = nil;
    }
    
    _count = 0;
    _characterBuffer = nil;
    _episode = nil;
    _feed = nil;
}

- (id)init {
    self = [super init];
    
    if (self) {
        _feed = [MNFeed new];
        _count = 0;
        _characterBuffer = [NSMutableData new];
        _context = xmlCreatePushParserCtxt(&xmlSAXHandlerStruct,
                                           (__bridge void *)(self),
                                           NULL,
                                           0,
                                           NULL);
    }
    
    return self;
}


- (void)setStoringCharacters:(BOOL)value {
    if (!value) [_characterBuffer setLength:0];
    _bufferingChars = value;
}

# pragma mark - MNFeedParse (API)

+ (MNFeedParser *)parserWith:(id<MNFeedParserDelegate>)delegate
               dateFormatter:(NSDateFormatter *)dateFormatter {
    return [[MNFeedParser alloc] initWith:delegate dateFormatter:dateFormatter];
}

- (id)initWith:(id <MNFeedParserDelegate>)delegate
 dateFormatter:(NSDateFormatter *)dateFormatter {
    self = [self init];
    
    if (self) {
        _delegate = delegate;
        _dateFormatter = dateFormatter;
    }
    
    return self;
}

- (BOOL)parse:(NSData *)data {
    int stat = data ?
    xmlParseChunk(_context, (const char *)[data bytes], [data length], 0) :
    xmlParseChunk(_context, NULL, 0, 1);
    
    if (stat != 0) [self delegateError:"XML parser error"];
    if (_aborted) [self delegateError:"Aborted by user"];
    
    return stat == 0;
}

- (void)abortParsing {
    _aborted = YES;
    [self parse:nil];
}

- (void)parseStream:(NSInputStream *)stream withMaxLength:(NSInteger)maxLength {
    NSInteger result;
    uint8_t buffer[maxLength];
    [stream open];
    while((result = [stream read:buffer maxLength:maxLength]) > 0) {
        [self parse:[NSData dataWithBytesNoCopy:buffer
                                         length:result
                                   freeWhenDone:NO]];
    }
    [stream close];
    [self parse:nil];
}

#pragma mark - PodcastParserDelegate

- (void)delegateError:(const char *)msg {
    if (![_delegate respondsToSelector:@selector(parser: parseErrorOccurred:)]) {
        return;
    }
    
    NSString *description = [[NSString alloc]initWithBytes:msg
                                                    length:sizeof(msg)
                                                  encoding:NSASCIIStringEncoding];
    
    NSDictionary *errorDictionary = @{
                                      NSLocalizedDescriptionKey : description
                                      };
    
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSXMLParserInternalError
                                     userInfo:errorDictionary];
    
    [_delegate parser:self parseErrorOccurred:error];
}

- (void)delegateEpisode {
    if (![_delegate respondsToSelector:@selector(parser: foundEpisode:)]) {
        return;
    }
    
    [_delegate parser:self foundEpisode:_episode];
    _parsingEpisode = NO;
    _episode = nil;
    _count++;
}

- (void)delegateShow {
    if (![_delegate respondsToSelector:@selector(parser: foundShow:)]) {
        return;
    }
    
    [_delegate parser:self foundShow:_feed];
    _feedHandled = YES;
    _feed = nil;
}

- (void)delegateDocumentStart {
    if ([_delegate respondsToSelector:@selector(parserDidStart:)]) {
        [_delegate parserDidStart:self];
    }
}

- (void)delegateDocumentEnd {
    if ([_delegate respondsToSelector:@selector(parserDidEnd:)]) {
        [_delegate parserDidEnd:self];
    }
}

#pragma mark - Parsing support functions

- (void)appendCharacters:(const char *)charactersFound
                  length:(NSInteger)length {
    [_characterBuffer appendBytes:charactersFound length:length];
}

- (NSString *)currentString {
    NSString *currentString = [[NSString alloc] initWithData:_characterBuffer
                                                    encoding:NSUTF8StringEncoding];
    [_characterBuffer setLength:0];
    
    return currentString;
}

- (NSDate *)currentDate {
    return [self.dateFormatter dateFromString:[self currentString]];
}

@end

#pragma mark - utils

static struct {
    char * name;
    int length;
} keys[] = {
    { "itunes", 7 },
    { "item", 5 },
    { "title", 6 },
    { "subtitle", 9 },
    { "summary", 8 },
    { "author", 7 },
    { "enclosure", 10 },
    { "url", 4 },
    { "href", 5 },
    { "guid", 5 },
    { "link", 5 },
    { "image", 6 },
    { "pubDate", 8 },
    { "channel", 8 },
    { "feed", 5 }
};

typedef enum {
    PodcastFeedParserKeyItunes,
    PodcastFeedParserKeyItem,
    PodcastFeedParserKeyTitle,
    PodcastFeedParserKeySubtitle,
    PodcastFeedParserKeySummary,
    PodcastFeedParserKeyAuthor,
    PodcastFeedParserKeyEnclosure,
    PodcastFeedParserKeyUrl,
    PodcastFeedParserKeyHref,
    PodcastFeedParserKeyGuid,
    PodcastFeedParserKeyLink,
    PodcastFeedParserKeyImage,
    PodcastFeedParserKeyPubDate,
    PodcastFeedParserKeyChannel,
    PodcastFeedParserKeyFeed
} PodcastFeedParserKey;

#define PODPARSE_STRNCMP(a,b,l) !strncmp((const char *)a, b, l)
#define PODPARSE_IS_ENTRY prefix == NULL && isXMLChar(localname, PodcastFeedParserKeyItem)
#define PODPARSE_IS_FEED prefix == NULL && isXMLChar(localname, PodcastFeedParserKeyChannel) || isXMLChar(localname, PodcastFeedParserKeyFeed)
#define PODPARSE_PODCAST_PARSER(ctx) (__bridge MNFeedParser *)ctx

static int
isXMLChar (const xmlChar *localname, PodcastFeedParserKey key) {
    return PODPARSE_STRNCMP(localname, keys[key].name, keys[key].length);
}

static void
parseAttributes (const xmlChar **attributes,
                 int nb_attributes,
                 void (^b)(const xmlChar *name, NSString *value)) {
    
    const xmlChar *name;
    NSString *value;
    int valueLength;
    xmlSAX2Attributes *a = (xmlSAX2Attributes *)attributes;
    
    for (int i = 0; i < nb_attributes; i++) {
        valueLength = (int) (a[i].end - a[i].value);
        value = [[NSString alloc] initWithBytes:a[i].value
                                         length:valueLength
                                       encoding:NSUTF8StringEncoding];
        
        name = a[i].localname;
        
        b(name, value);
    }
}

static int
appendage (const xmlChar *localname, const xmlChar *prefix) {
    int r, prefixed = prefix != NULL;
    
    if (prefixed) {
        r = isXMLChar(localname, PodcastFeedParserKeyAuthor) ||
        isXMLChar(localname, PodcastFeedParserKeySubtitle) ||
        isXMLChar(localname, PodcastFeedParserKeySummary) ||
        isXMLChar(localname, PodcastFeedParserKeyImage);
    } else {
        r = isXMLChar(localname, PodcastFeedParserKeyTitle) ||
        isXMLChar(localname, PodcastFeedParserKeyGuid) ||
        isXMLChar(localname, PodcastFeedParserKeyLink) ||
        isXMLChar(localname, PodcastFeedParserKeyPubDate);
    }
    return r;
}

static void
updateEpisode (const xmlChar *localname,
               const xmlChar *prefix,
               MNFeedParser *parser) {
    
    MNFeedEntry *episode = parser.episode;
    
    if (prefix == NULL) {
        if (isXMLChar(localname, PodcastFeedParserKeyTitle)) {
            episode.title = [parser currentString];
        } else if (isXMLChar(localname, PodcastFeedParserKeyGuid)) {
            episode.guid = [parser currentString];
        } else if (isXMLChar(localname, PodcastFeedParserKeyPubDate)) {
            episode.pubDate = [parser currentDate];
        }
    } else if (isXMLChar(prefix, PodcastFeedParserKeyItunes)) {
        if (isXMLChar(localname, PodcastFeedParserKeyAuthor)) {
            episode.author = [parser currentString];
        } else if (isXMLChar(localname, PodcastFeedParserKeySubtitle)) {
            episode.subtitle = [parser currentString];
        } else if (isXMLChar(localname, PodcastFeedParserKeySummary)) {
            episode.summary = [parser currentString];
        }
    }
}

static void
updateFeed (const xmlChar *localname,
            const xmlChar *prefix,
            MNFeedParser *parser) {
    
    MNFeed *feed = parser.feed;
    
    if (isXMLChar(localname, PodcastFeedParserKeyTitle)) {
        feed.title = [parser currentString];
    } else if (isXMLChar(localname, PodcastFeedParserKeyLink)) {
        feed.link = [parser currentString];
    } else if (isXMLChar(localname, PodcastFeedParserKeySubtitle)) {
        feed.subtitle = [parser currentString];
    } else if (isXMLChar(localname, PodcastFeedParserKeyAuthor)) {
        feed.author = [parser currentString];
    } else if (isXMLChar(localname, PodcastFeedParserKeySummary)) {
        feed.summary = [parser currentString];
    }
}

static void
episodeAttributes (const xmlChar *localname,
                   const xmlChar *prefix,
                   int nb_attributes,
                   const xmlChar **attributes,
                   MNFeedParser *parser) {
    
    int prefixed = prefix == NULL;
    
    if (prefixed) {
        if (isXMLChar(localname, PodcastFeedParserKeyEnclosure)) {
            __block MNFeedEntry *episode = parser.episode;
            parseAttributes(attributes,
                            nb_attributes,
                            ^(const xmlChar *name, NSString *value) {
                                if (isXMLChar(name, PodcastFeedParserKeyUrl)) {
                                    episode.url = value;
                                }
                            });
        }
    }
}

static void
feedAttributes (const xmlChar *localname,
                const xmlChar *prefix,
                int nb_attributes,
                const xmlChar **attributes,
                MNFeedParser *parser) {
    
    int prefixed = prefix == NULL;
    
    if (!prefixed) {
        if (isXMLChar(localname, PodcastFeedParserKeyImage)) {
            __block MNFeed *feed = parser.feed;
            parseAttributes(attributes,
                            nb_attributes,
                            ^(const xmlChar *name, NSString *value) {
                                if (isXMLChar(name, PodcastFeedParserKeyHref)) {
                                    feed.image = value;
                                }
                            });
        }
    }
}

#pragma mark - SAX callbacks

static void
startElementSAX (void *ctx,
                 const xmlChar *localname,
                 const xmlChar *prefix,
                 const xmlChar *URI,
                 int nb_namespaces,
                 const xmlChar **namespaces,
                 int nb_attributes,
                 int nb_defaulted,
                 const xmlChar **attributes) {
    
    MNFeedParser *parser = PODPARSE_PODCAST_PARSER(ctx);
    
    if (PODPARSE_IS_ENTRY) {
        parser.episode = [MNFeedEntry new];
        parser.parsingEpisode = YES;
    }
    
    if (appendage(localname, prefix)) {
        parser.bufferingChars = YES;
    }
    
    if (parser.parsingEpisode) {
        episodeAttributes(localname, prefix, nb_attributes, attributes, parser);
    } else {
        feedAttributes(localname, prefix, nb_attributes, attributes, parser);
    }
}

static void
endElementSAX (void *ctx,
               const xmlChar *localname,
               const xmlChar *prefix,
               const xmlChar *URI) {
    
    MNFeedParser *parser = PODPARSE_PODCAST_PARSER(ctx);
    
    if (parser.parsingEpisode) {
        updateEpisode(localname, prefix, parser);
    } else {
        updateFeed(localname, prefix, parser);
    }
    
    if (PODPARSE_IS_ENTRY) {
        [parser delegateEpisode];
    } else if (PODPARSE_IS_FEED) {
        [parser delegateShow];
    }
    
    parser.bufferingChars = NO;
}

static void	charactersFoundSAX (void *ctx, const xmlChar *ch, int len) {
    MNFeedParser *parser = PODPARSE_PODCAST_PARSER(ctx);
    if (parser.bufferingChars) {
        [parser appendCharacters:(const char *)ch length:len];
    }
}

static void errorEncounteredSAX (void *ctx, const char *msg, ...) {
    [PODPARSE_PODCAST_PARSER(ctx) delegateError:msg];
}

static void startDocumentSAX (void * ctx) {
    [PODPARSE_PODCAST_PARSER(ctx) delegateDocumentStart];
}

static void endDocumentSAX (void * ctx) {
    [PODPARSE_PODCAST_PARSER(ctx) delegateDocumentEnd];
}

static xmlSAXHandler xmlSAXHandlerStruct = {
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    startDocumentSAX,
    endDocumentSAX,
    NULL,
    NULL,
    NULL,
    charactersFoundSAX,
    NULL,
    NULL,
    NULL,
    NULL,
    errorEncounteredSAX,
    NULL,
    NULL,
    NULL,
    NULL,
    XML_SAX2_MAGIC,
    NULL,
    startElementSAX,
    endElementSAX,
    NULL
};