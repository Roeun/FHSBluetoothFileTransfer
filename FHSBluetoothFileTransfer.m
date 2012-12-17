//
//  FHSBluetoothFileTransfer.m
//  SwiftLoad
//
//  Created by Nathaniel Symer on 12/16/12.
//  Copyright (c) 2012 Nathaniel Symer. All rights reserved.
//

#import "FHSBluetoothFileTransfer.h"
#import <GameKit/GameKit.h>

@interface FHSBluetoothFileTransfer ()

@property (nonatomic, retain) NSMutableArray *dataChunks;
@property (nonatomic, assign) int recievedCount;
@property (nonatomic, assign) int totalRecievingChunkNumber;
@property (nonatomic, retain) GKPeerPickerController *ppc;

@end

@implementation FHSBluetoothFileTransfer

@synthesize receivedData, recievedCount, dataChunks, totalRecievingChunkNumber, progress, fileToBeSent, sendingSession, receivingSession, ppc;

- (BOOL)isSender {
    return !self.receivingSession.available;
}

- (void)cancel {
    [self.receivingSession disconnectFromAllPeers];
    [self.sendingSession disconnectFromAllPeers];
    self.receivingSession.available = YES;
    [[NSNotificationCenter defaultCenter]postNotificationName:FHSBluetoothFileTransferCancelledNotification object:nil];
}

- (void)modifySessionsForSending {
    self.receivingSession.available = NO;
}

- (void)modifySessionsAfterSent {
    [[NSNotificationCenter defaultCenter]postNotificationName:FHSBluetoothFileTransferFinishedNotification object:nil];
    self.receivingSession.available = YES;
}

- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state {
    if (state == GKPeerStateDisconnected) {
        [self.receivingSession disconnectFromAllPeers];
        [self.sendingSession disconnectFromAllPeers];
        self.receivingSession.available = YES;
        [[NSNotificationCenter defaultCenter]postNotificationName:FHSBluetoothFileTransferFailedNotification object:nil];
    }
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID {
    [self.receivingSession acceptConnectionFromPeer:peerID error:nil];
}

- (void)receiveData:(NSData *)data fromPeer:(NSString *)peer inSession:(GKSession *)session context:(void *)context {
    if (self.receivingSession.available == NO) {
        [[NSNotificationCenter defaultCenter]postNotificationName:FHSBluetoothFileTransferProgressSenderNotification object:nil];
        NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        self.recievedCount = [[array objectAtIndex:0]intValue];
        self.totalRecievingChunkNumber = [[array objectAtIndex:1]intValue];
        self.progress = self.recievedCount/self.totalRecievingChunkNumber;
        
        if (self.recievedCount < self.totalRecievingChunkNumber) {
            [self sendChunk];
        } else {
            [self modifySessionsAfterSent];
        }
    } else {
        [self didRecieveData:data];
        [self recieverSendInfoData];
    }
}

- (void)peerPickerController:(GKPeerPickerController *)picker didConnectPeer:(NSString *)peerID toSession:(GKSession *)session {
    [self sendFileAtPath:self.fileToBeSent];
    [self.ppc dismiss];
}

- (void)peerPickerControllerDidCancel:(GKPeerPickerController *)picker {
    [self modifySessionsAfterSent];
}

- (void)showPicker {
    [self modifySessionsForSending];
    [self.ppc show];
}

- (id)initWithFilePath:(NSString *)fp {
    self = [super init];

    if (self) {
        [self setDataChunks:[NSMutableArray array]];
        [self setReceivedData:[NSMutableData data]];
        [self setFileToBeSent:fp];
        
        GKSession *aSendingSession = [[GKSession alloc]initWithSessionID:nil displayName:nil sessionMode:GKSessionModeClient];
        [self setSendingSession:aSendingSession];
        [aSendingSession release];
        [self.sendingSession setDelegate:self];
        [self.sendingSession setDataReceiveHandler:self withContext:nil];
        [self.sendingSession setAvailable:NO];
        
        GKSession *aReceivingSession = [[GKSession alloc]initWithSessionID:nil displayName:nil sessionMode:GKSessionModeServer];
        [self setSendingSession:aReceivingSession];
        [aReceivingSession release];
        [self.receivingSession setDelegate:self];
        [self.receivingSession setDataReceiveHandler:self withContext:nil];
        
        GKPeerPickerController *peerPicker = [[GKPeerPickerController alloc]init];
        [self setPpc:peerPicker];
        [peerPicker release];
        [self.ppc setDelegate:self];
        [self.ppc setConnectionTypesMask:GKPeerPickerConnectionTypeNearby];
    }
    return self;
}

- (void)recieverSendInfoData {
    NSString *chunksRecieved = [NSString stringWithFormat:@"%d",self.recievedCount];
    NSString *totalChunks = [NSString stringWithFormat:@"%d",self.totalRecievingChunkNumber];
    NSArray *array = [NSArray arrayWithObjects:chunksRecieved, totalChunks, nil];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:array];
    [self.sendingSession sendDataToAllPeers:data withDataMode:GKMatchSendDataReliable error:nil];
}

- (void)didRecieveData:(NSData *)data {
    NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSString *flag = [array objectAtIndex:1];
    
    if ([flag isEqualToString:@"header"]) {
        self.totalRecievingChunkNumber = [[array objectAtIndex:0]intValue];
    } else {
        [self.receivedData appendData:[array objectAtIndex:0]];
        self.recievedCount = self.recievedCount+1;
        if (self.recievedCount == self.totalRecievingChunkNumber) {
            [[NSNotificationCenter defaultCenter]postNotificationName:FHSBluetoothFileTransferFinishedNotification object:nil];
        } else {
            [[NSNotificationCenter defaultCenter]postNotificationName:FHSBluetoothFileTransferProgressReceiverNotification object:nil];
        }
    }
    
    self.progress = self.recievedCount/self.totalRecievingChunkNumber;
}

- (void)sendFileAtPath:(NSString *)string {
    NSData *file = [NSData dataWithContentsOfFile:string];
    NSString *fileNameSending = [string lastPathComponent];
    NSArray *array = [NSArray arrayWithObjects:fileNameSending, file, nil];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:array];
    [self prepareData:data];
}

- (void)sendHeaderData {
    NSString *chunkCount = [NSString stringWithFormat:@"%d",self.dataChunks.count];
    NSString *headerFlag = @"header";
    NSArray *array = [NSArray arrayWithObjects:chunkCount, headerFlag, nil];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:array];
    [self.sendingSession sendDataToAllPeers:data withDataMode:GKMatchSendDataReliable error:nil];
}

- (void)prepareData:(NSData *)data {
    float chunkLength = 12800;
    
    int numItems = ceil((double)data.length/chunkLength);
	
	for (int i = 0; i < numItems; i++) {
		NSUInteger start = i*chunkLength;
		NSUInteger length = chunkLength;
		NSUInteger end = start + length;
        
		if (end > data.length) {
            length = fmod(data.length, chunkLength);
		}
		
		NSRange range = {start, length};
		NSData *chunkData = [data subdataWithRange:range];
		
		[self.dataChunks addObject:chunkData];
	}
    [self sendHeaderData];
}

- (void)sendChunk {
    NSData *chunkToSend = [self.dataChunks objectAtIndex:self.recievedCount];
    NSString *flag = @"chunk";
    NSArray *array = [NSArray arrayWithObjects:chunkToSend, flag, nil];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:array];
    [self.sendingSession sendDataToAllPeers:data withDataMode:GKSendDataReliable error:nil];
}

- (void)dealloc {
    [self.receivingSession release];
    [self.sendingSession release];
    [self.receivedData release];
    [self.dataChunks release];
    [self.fileToBeSent release];
    [self.ppc release];
    NSLog(@"FHSBluetoothFileTransfer has dealloc'd");
    [super dealloc];
}

@end
