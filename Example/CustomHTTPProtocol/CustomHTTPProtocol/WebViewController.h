@import UIKit;

@protocol WebViewControllerDelegate;

/*! A view controller to run a web view.  The implementation includes a number 
 *  of interesting features, including:
 *
 *  - a Sites button, to display a pre-configured list of web sites (from "root.html")
 *  
 *  - the ability to download and install (via a delegate callback) a custom 
 *    root certificate (trusted anchor)
 */

@interface WebViewController : UIViewController

@property (nonatomic, weak,   readwrite) id<WebViewControllerDelegate>  delegate;           ///< The controller delegate.

@end

/*! The protocol for the WebViewController delegate.
 */

@protocol WebViewControllerDelegate <NSObject>

@optional

/*! Called by the WebViewController to add a certificate as a trusted anchor.
 *  Will be called on the main thread.
 *  \param controller The controller instance; will not be nil.
 *  \param anchor The certificate to add; will not be NULL.
 *  \param errorPtr If not NULL then, on error, set *errorPtr to the actual error.
 *  \returns Return YES for success, NO for failure.
 */

- (BOOL)webViewController:(WebViewController *)controller addTrustedAnchor:(SecCertificateRef)anchor error:(NSError **)errorPtr;

/*! Called by the WebViewController to log various actions. 
 *  Will be called on the main thread.
 *  \param controller The controller instance; will not be nil.
 *  \param format A standard NSString-style format string; will not be nil.
 *  \param arguments Arguments for that format string.
 */

- (void)webViewController:(WebViewController *)controller logWithFormat:(NSString *)format arguments:(va_list)arguments;

@end
