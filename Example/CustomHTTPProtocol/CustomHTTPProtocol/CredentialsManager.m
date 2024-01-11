#import "CredentialsManager.h"

@import Security;

@interface CredentialsManager ()

@property (atomic, strong, readonly ) NSMutableArray *   mutableTrustedAnchors;

@end

@implementation CredentialsManager

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        self->_mutableTrustedAnchors = [[NSMutableArray alloc] init];
        assert(self->_mutableTrustedAnchors != nil);
    }
    return self;
}

- (NSArray *)trustedAnchors
{
    NSArray *   result;

    @synchronized (self) {
        result = [self->_mutableTrustedAnchors copy];
        assert(result != nil);
    }
    return result;
}

- (void)addTrustedAnchor:(SecCertificateRef)newAnchor
{
    BOOL        found;
    
    assert(newAnchor != NULL);
    
    @synchronized (self) {
        
        // Check to see if the certificate is already in the mutableTrustedAnchors 
        // array.  Somewhere along the line SecCertificate refs started supporting 
        // CFEqual, so we can use -indexOfObject:, which is nice.
        
        found = [self->_mutableTrustedAnchors indexOfObject:(__bridge id) newAnchor] != NSNotFound;
        
        // If the new anchor isn't already in the array, add it.
        
        if ( ! found ) {
            NSIndexSet *    indexSet;
            
            indexSet = [NSIndexSet indexSetWithIndex:[self->_mutableTrustedAnchors count]];
            assert(indexSet != nil);
            
            [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"trustedAnchors"];
            [self->_mutableTrustedAnchors addObject:(__bridge id)newAnchor];
            [self  didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"trustedAnchors"];
        }
    }
}

@end
