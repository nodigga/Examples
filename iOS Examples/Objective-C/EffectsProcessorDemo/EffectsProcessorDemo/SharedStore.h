//
//  SharedStore.h
//  EffectsProcessorDemo
//
//  Created by Aurelius Prochazka on 12/26/13.
//  Copyright (c) 2013 Aurelius Prochazka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "AKFoundation.h"
#import "VariableDelay.h"
#import "MoogLadder.h"
#import "RingModulator.h"

@interface SharedStore : NSObject

@property (nonatomic, retain) AKStereoAudioFilePlayer *audioFilePlayer;
@property (nonatomic, retain) AKReverbPedal *reverb;
@property (nonatomic, retain) VariableDelay *variableDelay;
@property (nonatomic, retain) MoogLadder *moogLadder;
@property (nonatomic, retain) RingModulator *ringModulator;

@property (nonatomic, strong) MPMediaItem *currentSong;
@property (nonatomic) BOOL isPlaying;

// message from which our instance is obtained
+ (SharedStore *)globals;

@end
