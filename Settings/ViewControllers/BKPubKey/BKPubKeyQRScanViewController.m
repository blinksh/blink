//
//  BKPubKeyQRScanViewController.m
//  Blink
//
//  Created by Roman Belyakovsky on 03/04/2017.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKPubKeyQRScanViewController.h"

@interface BKPubKeyQRScanViewController () <AVCaptureMetadataOutputObjectsDelegate> {

AVCaptureSession *_session;
AVCaptureDevice *_device;
AVCaptureDeviceInput *_input;
AVCaptureMetadataOutput *_output;
AVCaptureVideoPreviewLayer *_prevLayer;

UIView *_highlightView;
}

@end

@implementation BKPubKeyQRScanViewController

@synthesize delegate;

- (void)viewDidLoad {
  [super viewDidLoad];
  
  _highlightView = [[UIView alloc] init];
  _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
  _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
  _highlightView.layer.borderWidth = 3;
  [_videoView addSubview:_highlightView];
  
  _session = [AVCaptureSession new];
  _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  NSError *error = nil;
  
  _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
  if (_input) {
    [_session addInput:_input];
  } else {
    NSLog(@"Error: %@", error);
  }
  
  _output = [AVCaptureMetadataOutput new];
  [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
  [_session addOutput:_output];
  
  _output.metadataObjectTypes = [_output availableMetadataObjectTypes];
  
  _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
  _prevLayer.frame = self.view.bounds;
  _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
  [_videoView.layer addSublayer:_prevLayer];
  
  [_session startRunning];
  
  [self.view bringSubviewToFront:_highlightView];
  
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cancelQRScan:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
  CGRect highlightViewRect = CGRectZero;
  AVMetadataMachineReadableCodeObject *barCodeObject;
  NSString *detectionString = nil;
  NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode, AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
                            AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeCode128Code,
                            AVMetadataObjectTypePDF417Code, AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode];
  
  for (AVMetadataObject *metadata in metadataObjects) {
    for (NSString *type in barCodeTypes) {
      if ([metadata.type isEqualToString:type])
      {
        barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
        highlightViewRect = barCodeObject.bounds;
        detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
        break;
      }
    }
    
    if (detectionString != nil)
    {
      [self dismissViewControllerAnimated:YES completion:nil];
      NSLog(@"Key scanned");
      [_session stopRunning];
      [delegate importKey:detectionString];
      break;
    }
  }
  
  _highlightView.frame = highlightViewRect;
}

@end
