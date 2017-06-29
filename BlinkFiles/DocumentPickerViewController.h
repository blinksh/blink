//
//  DocumentPickerViewController.h
//  BlinkFiles
//
//  Created by Nicolas Holzschuch on 29/06/2017.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DocumentPickerViewController : UIDocumentPickerExtensionViewController<UITableViewDataSource,UITableViewDelegate>

  - (void)dismissGrantingAccessToURL:(NSURL *)url;
  
@end
