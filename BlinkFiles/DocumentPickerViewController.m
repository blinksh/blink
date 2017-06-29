//
//  DocumentPickerViewController.m
//  BlinkFiles
//
//  Created by Nicolas Holzschuch on 29/06/2017.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import "DocumentPickerViewController.h"
#define appGroupFiles @"group.Nicolas-Holzschuch-blinkshell"


@interface DocumentPickerViewController ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@end

#define CELL_REUSE_IDENTIFIER @"fileInfosCell"

@implementation DocumentPickerViewController
{
  NSArray *fileInfos;
  NSString *storagePath;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  NSURL *groupURL = [[NSFileManager defaultManager]
                     containerURLForSecurityApplicationGroupIdentifier:
                     appGroupFiles];
  NSString *groupPath = [groupURL path];
  storagePath = [groupPath stringByAppendingPathComponent:@"File Provider Storage"];

  [self makeFileInfo:storagePath];
}

- (void)makeFileInfo:(NSString *)path {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  fileInfos = [fileManager contentsOfDirectoryAtPath:path error:nil];
  [self.tableView reloadData];
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  // Return the number of sections.
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  // Return the number of rows in the section.
  return [fileInfos count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CELL_REUSE_IDENTIFIER forIndexPath:indexPath];
  
  // Configure the cell...
  NSString *file = [fileInfos objectAtIndex:indexPath.row];
  cell.textLabel.text = file;
  if ([self validFile:file]) {
    cell.textLabel.textColor = [UIColor blackColor];
  } else {
    cell.textLabel.textColor = [UIColor grayColor];
  }
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSString *file = [fileInfos objectAtIndex:indexPath.row];
  if ([self validFile:file]) {
    NSString *path = [storagePath stringByAppendingPathComponent:file];
    NSURL *url = [NSURL fileURLWithPath:path];
    [self dismissGrantingAccessToURL:url];
  }
}

// check validity of document type
- (BOOL)validFile:(NSString *)file {
  NSString *extension = [file pathExtension];
  // "self" refers to the app calling us. What can it open?
  for (NSString *UTI in self.validTypes) {
    if ([UTI isEqualToString:@"public.content"]) {
      return YES;
    } if ([UTI isEqualToString:@"public.data"]) {
      return YES;
    } else if ([UTI isEqualToString:@"public.text"]) {
      if ([extension isEqualToString:@"txt"]) {
        return YES;
      }
    } else if ([UTI isEqualToString:@"public.plain-text"]) {
      if ([extension isEqualToString:@"txt"]) {
        return YES;
      }
    } else if ([UTI isEqualToString:@"public.html"]) {
      if ([extension isEqualToString:@"html"]) {
        return YES;
      }
    }
  }
  return NO;
}


-(void)prepareForPresentationInMode:(UIDocumentPickerMode)mode {
    // TODO: present a view controller appropriate for picker mode here
  
  
}

@end
