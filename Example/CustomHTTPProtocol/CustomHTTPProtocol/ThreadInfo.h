#import <Foundation/Foundation.h>

/*! Records information about a thread.  This is a simple 'data carrier' class, with no 
 *  brains at all, used by the app's logging code.
 */

@interface ThreadInfo : NSObject

/*! Initialises the object with the specified values.
 *  \param tid The globally unique thread ID.
 *  \param number The thread number inside this app.
 *  \param name The name of the thread; must not be nil.
 *  \returns An initialised instance.
 */

- (instancetype)initWithThreadID:(uint64_t)tid number:(NSUInteger)number name:(NSString *)name;

@property (atomic, assign, readonly ) uint64_t      tid;            ///< The globally unique thread ID.
@property (atomic, assign, readonly ) NSUInteger    number;         ///< The thread number inside this app.
@property (atomic, copy,   readonly ) NSString *    name;           ///< The name of the thread; will not be nil.

@end
