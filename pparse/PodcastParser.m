//
//  Podcast.m
//  podparse
//
//  Created by Michael Nisi on 15.10.12.
//  Copyright (c) 2012 Michael Nisi. All rights reserved.
//

#import <libxml/tree.h>
#import "PodcastParser.h"

#pragma mark - PodcastFeedParserShow

@implementation PodcastFeedParserShow
@end

#pragma mark - PodcastFeedParserEpisode

@implementation PodcastFeedParserEpisode
- (BOOL)isEqualToEpisode:(PodcastFeedParserEpisode *)episode {
    return [self.title isEqualToString:episode.title] &&
    [self.subtitle isEqualToString:episode.subtitle] &&
    [self.summary isEqualToString:episode.summary];
}
- (id)initWithTitle:(NSString *)title
             author:(NSString *)author
           subtitle:(NSString *)subtitle
            summary:(NSString *)summary
                url:(NSString *)url
               guid:(NSString *)guid
            pubDate:(NSDate *)pubDate
{
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

+ (PodcastFeedParserEpisode *)episodeWithTitle:(NSString *)title
                       author:(NSString *)author
                     subtitle:(NSString *)subtitle
                      summary:(NSString *)summary
                          url:(NSString *)url
                         guid:(NSString *)guid
                      pubDate:(NSDate *)pubDate {
    
    return [[PodcastFeedParserEpisode alloc] initWithTitle:title
                                   author:author
                                 subtitle:subtitle
                                  summary:summary
                                      url:url
                                     guid:guid
                                  pubDate:pubDate];
}
@end

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

static void parseAttributes (const xmlChar **attributes,
                             int nb_attributes,
                             void (^b)(const xmlChar *name, NSString *value));

static int appendage (const xmlChar *localname, const xmlChar *prefix);

static xmlSAXHandler xmlSAXHandlerStruct;

struct _xmlSAX2Attributes {
    const xmlChar *localname;
    const xmlChar *prefix;
    const xmlChar *uri;
    const xmlChar *value;
    const xmlChar *end;
};
typedef struct _xmlSAX2Attributes xmlSAX2Attributes;

@interface PodcastParser ()
@property (nonatomic) BOOL parsingAnEpisode;
@property (nonatomic) BOOL bufferingChars;
@property (nonatomic) BOOL showHandled;
@property (nonatomic) BOOL aborted;
@property (nonatomic, retain) NSMutableData *characterBuffer;
@property (nonatomic) PodcastFeedParserEpisode *currentEpisode;
@property (nonatomic) PodcastFeedParserShow *show;
@property (nonatomic) xmlParserCtxtPtr context;
@property (nonatomic) int countOfParsedEpisodes;
@property (nonatomic) NSDateFormatter *dateFormatter;
- (void)delegateError:(const char *)msg;
- (void)delegateEpisode;
- (void)delegateShow;
- (void)delegateDocumentStart;
- (void)delegateDocumentEnd;
@end

@implementation PodcastParser

- (void)dealloc {
    if (_context) {
        xmlFreeParserCtxt(_context);
        _context = nil;
    }

    _countOfParsedEpisodes = 0;
    _characterBuffer = nil;
    _currentEpisode = nil;
    _show = nil;
}

- (id)init {
    self = [super init];
    
    if (self) {
        _show = [PodcastFeedParserShow new];
        _countOfParsedEpisodes = 0;
        _characterBuffer = [NSMutableData new];
        _context = xmlCreatePushParserCtxt(&xmlSAXHandlerStruct,
                                           (__bridge void *)(self),
                                           NULL,
                                           0,
                                           NULL);
    }
    
   return self;
}

- (id)initWith:(id <PodcastParserDelegate>)delegate
 dateFormatter:(NSDateFormatter *)dateFormatter {
    self = [self init];
    
    if (self) {
        _delegate = delegate;
        _dateFormatter = dateFormatter;
    }
    
    return self;
}

+ (PodcastParser *)parserWith:(id<PodcastParserDelegate>)delegate
                dateFormatter:(NSDateFormatter *)dateFormatter {
    return [[PodcastParser alloc] initWith:delegate dateFormatter:dateFormatter];
}

- (void)setStoringCharacters:(BOOL)value {
    if (!value) [_characterBuffer setLength:0];
    _bufferingChars = value;
}

- (BOOL)parse:(NSData *)data {
    int stat;

    if (!data) {
        stat = xmlParseChunk(_context, NULL, 0, 1);
    } else {
        stat = xmlParseChunk(_context, (const char *)[data bytes], [data length], 0);
    }
    
    if (stat != 0) {
        [self delegateError:"XML parser error"];
    }
    
    if (_aborted) {
        [self delegateError:"Aborted by user"];
    }
    
    return stat == 0;
}

- (void)abortParsing {
    _aborted = YES;
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
    
    [_delegate parser:self foundEpisode:_currentEpisode];
    _parsingAnEpisode = NO;
    _currentEpisode = nil;
    _countOfParsedEpisodes++;
}

- (void)delegateShow {
    if (![_delegate respondsToSelector:@selector(parser: foundShow:)]) {
        return;
    }
    
    [_delegate parser:self foundShow:_show];
    _showHandled = YES;
    _show = nil;
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

#pragma mark - SAX parsing callbacks

typedef struct {
    char * name;
    int length;
} key;

static const key keys[] = {
    {"itunes", 7},
    {"item", 5},
    {"title",6},
    {"subtitle",9},
    {"summary",8},
    {"author",7},
    {"enclosure",10},
    {"url",4},
    {"href",5},
    {"guid",5},
    {"link",5},
    {"image",6},
    {"pubDate",8}
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
    PodcastFeedParserKeyPubDate
} PodcastFeedParserKey;

#define PODPARSE_STRNCMP(a,b,l) !strncmp((const char *)a, b, l)
#define PODPARSE_IS_EPISODE prefix == NULL && isXMLChar(localname, PodcastFeedParserKeyItem)
#define PODPARSE_PODCAST_PARSER(ctx) (__bridge PodcastParser *)ctx

static int
isXMLChar (const xmlChar *localname, PodcastFeedParserKey key) {
    return PODPARSE_STRNCMP(localname, keys[key].name, keys[key].length);
}

static int appendage (const xmlChar *localname, const xmlChar *prefix) {
    int r;
    int prefixed = prefix != NULL;
    
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

static void startElementSAX(void *ctx, const xmlChar *localname,
                            const xmlChar *prefix,
                            const xmlChar *URI,
                            int nb_namespaces,
                            const xmlChar **namespaces,
                            int nb_attributes,
                            int nb_defaulted,
                            const xmlChar **attributes) {
    
    PodcastParser *parser = PODPARSE_PODCAST_PARSER(ctx);

    if (PODPARSE_IS_EPISODE) {
        parser.currentEpisode = [PodcastFeedParserEpisode new];
        parser.parsingAnEpisode = YES;
    }
    
    if (appendage(localname, prefix)) {
        parser.bufferingChars = YES;
    }
    
    int prefixed = prefix == NULL;
    
    if (parser.parsingAnEpisode) {
        if (prefixed) {
            if (isXMLChar(localname, PodcastFeedParserKeyEnclosure)) {
                __block PodcastFeedParserEpisode *episode = parser.currentEpisode;
                parseAttributes(attributes,
                                nb_attributes,
                                ^(const xmlChar *name, NSString *value) {
                                    
                    if (isXMLChar(name, PodcastFeedParserKeyUrl)) {
                        episode.url = value;
                    }
                });
            }
        }
    } else {
        if (!prefixed) {
            if (isXMLChar(localname, PodcastFeedParserKeyImage)) {
                __block PodcastFeedParserShow *show = parser.show;
                parseAttributes(attributes,
                                nb_attributes,
                                ^(const xmlChar *name, NSString *value) {
                                    
                    if (isXMLChar(name, PodcastFeedParserKeyHref)) {
                        show.image = value;
                    }
                });
            }
        }
    }
}

static void parseAttributes (const xmlChar **attributes,
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

static void	endElementSAX(void *ctx,
                          const xmlChar *localname,
                          const xmlChar *prefix,
                          const xmlChar *URI) {
    
    PodcastParser *parser = PODPARSE_PODCAST_PARSER(ctx);
    PodcastFeedParserEpisode *episode = parser.currentEpisode;
    PodcastFeedParserShow *show = parser.show;
    
    if (parser.parsingAnEpisode) {
        if (prefix == NULL) {
            if (PODPARSE_IS_EPISODE) {
                [parser delegateEpisode];
            } else if (isXMLChar(localname, PodcastFeedParserKeyTitle)) {
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
    } else if (!parser.showHandled) {
        if (isXMLChar(localname, PodcastFeedParserKeyTitle)) {
            show.title = parser.currentString;
        } else if (isXMLChar(localname, PodcastFeedParserKeyLink)) {
            show.link = parser.currentString;
        } else if (isXMLChar(localname, PodcastFeedParserKeySubtitle)) {
            show.subtitle = parser.currentString;
        } else if (isXMLChar(localname, PodcastFeedParserKeyAuthor)) {
            show.author = parser.currentString;
        } else if (isXMLChar(localname, PodcastFeedParserKeySummary)) {
            show.summary = parser.currentString;
        }
        
        if (show
            && show.title
            && show.link
            && show.subtitle
            && show.author
            && show.summary
            && show.image) {
            
            [parser delegateShow];
        }
    }
    
    parser.bufferingChars = NO;
}

static void	charactersFoundSAX(void *ctx, const xmlChar *ch, int len) {
    PodcastParser *parser = PODPARSE_PODCAST_PARSER(ctx);
    if (parser.bufferingChars) {
       [parser appendCharacters:(const char *)ch length:len];
    }
}

static void errorEncounteredSAX(void *ctx, const char *msg, ...) {
    [PODPARSE_PODCAST_PARSER(ctx) delegateError:msg];
}

static void startDocumentSAX(void * ctx) {
    [PODPARSE_PODCAST_PARSER(ctx) delegateDocumentStart];
}

static void endDocumentSAX(void * ctx) {
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