#import <UIKit/UIKit.h>
#import "SSViewController.h"
#import <rootless.h>

@interface AppStoreAccountViewController: UIViewController
@end

%hook AppStoreAccountViewController

- (id)init {
  return %orig;
}

- (void)viewDidLoad {
	%orig;
  UIBarButtonItem *switcherButton =
    [[UIBarButtonItem alloc]
      initWithImage:[UIImage imageNamed:ROOT_PATH_NS(@"/Library/Application Support/StoreSwitcher/switcher")]
      style:UIBarButtonItemStylePlain
      target:self
      action:@selector(openSwitcher:)
    ];

  [self navigationItem].leftBarButtonItems = @[[self navigationItem].leftBarButtonItem, switcherButton];
}

%new
- (void)openSwitcher:(UIButton *)button {
	SSViewController *viewController = [[SSViewController alloc] init];
	[viewController setModalPresentationStyle:UIModalPresentationPageSheet];
	[self presentViewController:viewController animated:YES completion:nil];
}

%end

%ctor {
  %init(AppStoreAccountViewController = objc_getClass("AppStore.AccountViewController")
	);
}