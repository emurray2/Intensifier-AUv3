#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

struct BufferedAudioBus {
    AUAudioUnitBus* bus = nullptr;
    AUAudioFrameCount maxFrames = 0;
};

