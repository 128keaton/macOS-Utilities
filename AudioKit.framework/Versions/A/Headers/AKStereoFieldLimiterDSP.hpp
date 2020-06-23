// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#pragma once

#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(AUParameterAddress, AKStereoFieldLimiterParameter) {
    AKStereoFieldLimiterParameterAmount,
};

#ifndef __cplusplus

AKDSPRef createStereoFieldLimiterDSP(void);

#else

#import "AKDSPBase.hpp"
#import "ParameterRamper.hpp"

struct AKStereoFieldLimiterDSP : AKDSPBase {
private:
    ParameterRamper amountRamp;

public:

    AKStereoFieldLimiterDSP() {
        parameters[AKStereoFieldLimiterParameterAmount] = &amountRamp;
    }
    
    void init(int channelCount, double sampleRate) override {
        AKDSPBase::init(channelCount, sampleRate);
        amountRamp.init(sampleRate);
    }

    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            int frameOffset = int(frameIndex + bufferOffset);
            
            float amount = amountRamp.getAndStep();

            if (!isStarted) {
                outputBufferLists[0]->mBuffers[0] = inputBufferLists[0]->mBuffers[0];
                outputBufferLists[0]->mBuffers[1] = inputBufferLists[0]->mBuffers[1];
                return;
            }

            float *tmpin[2];
            float *tmpout[2];
            for (int channel = 0; channel < channelCount; ++channel) {
                float *in  = (float *)inputBufferLists[0]->mBuffers[channel].mData  + frameOffset;
                float *out = (float *)outputBufferLists[0]->mBuffers[channel].mData + frameOffset;
                if (channel < 2) {
                    tmpin[channel] = in;
                    tmpout[channel] = out;
                }
            }
            *tmpout[0] = *tmpin[0] * (1.0f - amount / 2.0) + *tmpin[1] * amount / 2.0;
            *tmpout[1] = *tmpin[1] * (1.0f - amount / 2.0) + *tmpin[0] * amount / 2.0;
        }
    }
};

#endif




