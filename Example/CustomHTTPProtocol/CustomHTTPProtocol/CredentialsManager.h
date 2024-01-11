@import Foundation;

/*! Manages the list of trusted anchor certificates.  This class is thread 
 *  safe.
 */

@interface CredentialsManager : NSObject

- (instancetype)init;

@property (atomic, copy,   readonly ) NSArray *    trustedAnchors;       ///< The list of trusted anchor certificates; elements are of type SecCertificateRef; observable.

/*! Adds a certificate to the end of the list of trusted anchor certificates.
 *  Does nothing if the certificate is already in the list.
 *  \param newAnchor The certificate to add; must not be NULL.
 */

- (void)addTrustedAnchor:(SecCertificateRef)newAnchor;

@end
