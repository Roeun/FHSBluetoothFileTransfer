//
//  FHSBluetoothFileTransfer.h
//  SwiftLoad
//
//  Created by Nathaniel Symer on 12/16/12.
//  Copyright (c) 2012 Nathaniel Symer. All rights reserved.
//

#import <Foundation/Foundation.h>

#define FHSBluetoothFileTransferProgressSenderNotification @"FHSBluetoothFileTransferProgressSenderNotification"
#define FHSBluetoothFileTransferProgressReceiverNotification @"FHSBluetoothFileTransferProgressReceiverNotification"
#define FHSBluetoothFileTransferFinishedNotification @"FHSBluetoothFileTransferFinishedNotification"
#define FHSBluetoothFileTransferCancelledNotification @"FHSBluetoothFileTransferCancelledNotification"
#define FHSBluetoothFileTransferFailedNotification @"FHSBluetoothFileTransferFailedNotification"

@interface FHSBluetoothFileTransfer : NSObject <GKSessionDelegate, GKPeerPickerControllerDelegate>

@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, assign) float progress;
@property (nonatomic, retain) GKSession *sendingSession;
@property (nonatomic, retain) GKSession *receivingSession;
@property (nonatomic, retain) NSString *fileToBeSent;

- (id)initWithFilePath:(NSString *)fp;
- (void)showPicker;
- (void)cancel;
- (BOOL)isSender;

@end
