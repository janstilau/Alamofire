#import "ThreadInfo.h"

@implementation ThreadInfo

- (instancetype)initWithThreadID:(uint64_t)tid number:(NSUInteger)number name:(NSString *)name
{
    assert(name != nil);
    self = [super init];
    if (self != nil) {
        self->_tid = tid;
        self->_number = number;
        self->_name = [name copy];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %zu %#llx %@", [self class], (size_t) self->_number, self->_tid, self->_name];
}

@end
