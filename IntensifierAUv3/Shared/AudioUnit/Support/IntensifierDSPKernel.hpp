#ifndef IntensifierDSPKernel_h
#define IntensifierDSPKernel_h
#import "DSPKernel.hpp"
#import "ParameterRamper.hpp"
#import "AdjustableDelayLine.h"
#import "rmsaverage.h"
#import "slide.h"
static inline float convertBadValuesToZero(float x)
{
    /*
     Eliminate denormals, not-a-numbers, and infinities.
     Denormals will fail the first test (absx > 1e-15), infinities will fail
     the second test (absx < 1e15), and NaNs will fail both tests. Zero will
     also fail both tests, but since it will get set to zero that is OK.
     */
    float absx = fabs(x);

    if (absx > 1e-15 && absx < 1e15) {
        return x;
    }

    return 0.0;
}

enum {
    IntensifierParamInputAmount = 0,
    IntensifierParamAttackAmount = 1,
    IntensifierParamReleaseAmount = 2,
    IntensifierParamAttackTime = 3,
    IntensifierParamReleaseTime = 4,
    IntensifierParamOutputAmount = 5
};

static inline double squared(double x) {
    return x * x;
}

/*
 IntensifierDSPKernel
 Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */
class IntensifierDSPKernel : public DSPKernel
{
public:
    struct IntensifierState {
        float inputdB = 0.0;
        float attackdB = 0.0;
        float releasedB = 0.0;
        float outputdB = 0.0;

        void clear() {
            inputdB = 0.0;
            attackdB = 0.0;
            releasedB = 0.0;
            outputdB = 0.0;
        }

        void convertBadStateValuesToZero() {
            /*
             Make sure the dB levels never get bad values
             such as infinity or NaN
             */
            inputdB = convertBadValuesToZero(inputdB);
            attackdB = convertBadValuesToZero(attackdB);
            releasedB = convertBadValuesToZero(releasedB);
            outputdB = convertBadValuesToZero(outputdB);
        }
    };

    IntensifierDSPKernel() :
    inputAmountRamper(0.0),
    attackAmountRamper(0.0),
    releaseAmountRamper(0.0),
    attackTimeRamper(20.0),
    releaseTimeRamper(1.0),
    outputAmountRamper(0.0) {}

    void init(int channelCount, double inSampleRate)
    {
        channelStates.resize(channelCount);

        sampleRate = float(inSampleRate);
        nyquist = 0.5 * sampleRate;
        inverseNyquist = 1.0 / nyquist;
        dezipperRampDuration = (AUAudioFrameCount)floor(0.02 * sampleRate);
        inputAmountRamper.init();
        attackAmountRamper.init();
        releaseAmountRamper.init();
        attackTimeRamper.init();
        releaseTimeRamper.init();
        outputAmountRamper.init();
        RMSAverage1->clear();
        RMSAverage1->init(sampleRate, 441);
        RMSAverage2->clear();
        RMSAverage2->init(sampleRate, 882);
        attackSlideUp->clear();
        attackSlideUp->init(882, 0);
        attackSlideDown->clear();
        attackSlideDown->init(0, 882);
        releaseSlideDown->clear();
        releaseSlideDown->init(0, 44100);
        delay1->clear();
        delay1->init(sampleRate, 10);
    }
    void deinit()
    {
    }
    void reset()
    {
        inputAmountRamper.reset();
        attackAmountRamper.reset();
        releaseAmountRamper.reset();
        attackTimeRamper.reset();
        releaseTimeRamper.reset();
        outputAmountRamper.reset();
        for (IntensifierState& state : channelStates) {
            state.clear();
        }
        RMSAverage1->clear();
        RMSAverage1->init(sampleRate, 441);
        RMSAverage2->clear();
        RMSAverage2->init(sampleRate, 882);
        attackSlideUp->clear();
        attackSlideUp->init(882, 0);
        attackSlideDown->clear();
        attackSlideDown->init(0, 882);
        releaseSlideDown->clear();
        releaseSlideDown->init(0, 44100);
        delay1->clear();
        delay1->init(sampleRate, 10);
    }
    bool isBypassed() {
        return bypassed;
    }
    void setBypass(bool shouldBypass) {
        bypassed = shouldBypass;
    }
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case IntensifierParamInputAmount:
                inputAmountRamper.setUIValue(clamp(value, -40.0f, 15.0f));
                break;
            case IntensifierParamAttackAmount:
                attackAmountRamper.setUIValue(clamp(value, -40.0f, 30.0f));
                break;
            case IntensifierParamReleaseAmount:
                releaseAmountRamper.setUIValue(clamp(value, -40.0f, 30.0f));
                break;
            case IntensifierParamAttackTime:
                attackTimeRamper.setUIValue(clamp(value, 0.0f, 500.0f));
                break;
            case IntensifierParamReleaseTime:
                releaseTimeRamper.setUIValue(clamp(value, 0.0f, 5.0f));
                break;
            case IntensifierParamOutputAmount:
                outputAmountRamper.setUIValue(clamp(value, -40.0f, 15.0f));
                break;
        }
    }
    AUValue getParameter(AUParameterAddress address)
    {
        switch (address) {
            case IntensifierParamInputAmount:
                // Return the goal. It is not thread safe to return the ramping value.
                //return (inputAmountRamper.getUIValue() * nyquist);
                return inputAmountRamper.getUIValue();
            case IntensifierParamAttackAmount:
                return attackAmountRamper.getUIValue();
            case IntensifierParamReleaseAmount:
                return releaseAmountRamper.getUIValue();
            case IntensifierParamAttackTime:
                return attackTimeRamper.getUIValue();
            case IntensifierParamReleaseTime:
                return releaseTimeRamper.getUIValue();
            case IntensifierParamOutputAmount:
                return outputAmountRamper.getUIValue();

            default: return 0.0;
        }
    }
    void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override
    {
        switch (address) {
            case IntensifierParamInputAmount:
                inputAmountRamper.startRamp(clamp(value, -40.0f, 15.0f), duration);
                break;
            case IntensifierParamAttackAmount:
                attackAmountRamper.startRamp(clamp(value, -40.0f, 30.0f), duration);
                break;
            case IntensifierParamReleaseAmount:
                releaseAmountRamper.startRamp(clamp(value, -40.0f, 30.0f), duration);
                break;
            case IntensifierParamAttackTime:
                attackTimeRamper.startRamp(clamp(value, 0.0f, 500.0f), duration);
                break;
            case IntensifierParamReleaseTime:
                releaseTimeRamper.startRamp(clamp(value, 0.0f, 5.0f), duration);
                break;
            case IntensifierParamOutputAmount:
                outputAmountRamper.startRamp(clamp(value, -40.0f, 15.0f), duration);
                break;
        }
    }
    void setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList)
    {
        inBufferListPtr = inBufferList;
        outBufferListPtr = outBufferList;
    }
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override
    {
        float inputSample;
        if (bypassed) {
            // Pass the samples through
            int channelCount = int(channelStates.size());
            for (int channel = 0; channel < channelCount; ++channel) {
                if (inBufferListPtr->mBuffers[channel].mData ==  outBufferListPtr->mBuffers[channel].mData) {
                    continue;
                }
                for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                    int frameOffset = int(frameIndex + bufferOffset);
                    float* in  = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                    float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                    *out = *in;
                }
            }
            return;
        }

        int channelCount = int(channelStates.size());

        inputAmountRamper.dezipperCheck(dezipperRampDuration);
        attackAmountRamper.dezipperCheck(dezipperRampDuration);
        releaseAmountRamper.dezipperCheck(dezipperRampDuration);
        attackTimeRamper.dezipperCheck(dezipperRampDuration);
        releaseTimeRamper.dezipperCheck(dezipperRampDuration);
        outputAmountRamper.dezipperCheck(dezipperRampDuration);

        delay1->setDelayMs(20.0);
        delay1->setFeedback(0.0);
        float *tmpAttackOut;
        float tmpAttackOutVal;
        tmpAttackOut = &tmpAttackOutVal;

        float *tmpReleaseOut;
        float tmpReleaseOutVal;
        tmpReleaseOut = &tmpReleaseOutVal;
        float *tmpMixOut;
        float tmpMixOutVal;
        tmpMixOut = &tmpMixOutVal;
        // For each sample.
        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            int frameOffset = int(frameIndex + bufferOffset);
            /*
             The parameter values are updated every sample! This is very
             expensive. You probably want to do things differently.
             */

            float inputAmount = (float)inputAmountRamper.get();
            float outputAmount = (float)outputAmountRamper.get();
            float attackA = (float)attackAmountRamper.get() * 2.5;
            float releaseA = (float)releaseAmountRamper.get() * 2.5;
            float attackT = (float)attackTimeRamper.get();
            float releaseT = (float)releaseTimeRamper.get();
            releaseT = releaseT * 1000;
            attackT = convertMsToSamples(attackT, sampleRate);
            releaseT = convertMsToSamples(releaseT, sampleRate);
            attackSlideUp->setslideup(attackT);
            attackSlideDown->setslidedown(attackT);
            releaseSlideDown->setslidedown(releaseT);

            // advance sample
            for (int channel = 0; channel < channelCount; ++channel) {
                const float *in = (const float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                inputSample = *in;
                float *out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                // convert decibels to amplitude
                *out = (inputSample * pow(10., inputAmount / 20.0));
                compute_attackLR(out, tmpAttackOut, RMSAverage1, attackSlideUp, attackSlideDown);
                compute_releaseLR(out, tmpReleaseOut, RMSAverage2, releaseSlideDown);
                *tmpAttackOut = *tmpAttackOut * attackA;
                *tmpReleaseOut = *tmpReleaseOut * releaseA;
                // mix release and attack
                *tmpMixOut = *tmpAttackOut + *tmpReleaseOut;
                // convert decibels to amplitude
                *tmpMixOut = pow(10., *tmpMixOut / 20.0);
                // reduce/increase output decibels
                *tmpMixOut = *tmpMixOut * pow(10., outputAmount / 20.0);
                delay1->push(*out);
                *out = delay1->getOutput() * *tmpMixOut;
            }
            inputAmountRamper.step();
            attackAmountRamper.step();
            releaseAmountRamper.step();
            attackTimeRamper.step();
            releaseTimeRamper.step();
            outputAmountRamper.step();
        }
        // Squelch any blowups once per cycle.
        for (int channel = 0; channel < channelCount; ++channel) {
            channelStates[channel].convertBadStateValuesToZero();
        }
    }
private:
    std::vector<IntensifierState> channelStates;
    float sampleRate = 44100.0;
    float nyquist = 0.5 * sampleRate;
    float inverseNyquist = 1.0 / nyquist;
    AUAudioFrameCount dezipperRampDuration;

    AudioBufferList* inBufferListPtr = nullptr;
    AudioBufferList* outBufferListPtr = nullptr;

    bool bypassed = false;

public:

    // Parameters.
    ParameterRamper inputAmountRamper;
    ParameterRamper attackAmountRamper;
    ParameterRamper releaseAmountRamper;
    ParameterRamper attackTimeRamper;
    ParameterRamper releaseTimeRamper;
    ParameterRamper outputAmountRamper;
private:
    CycloneObjects::rmsaverage* RMSAverage1 = new CycloneObjects::rmsaverage();
    CycloneObjects::rmsaverage* RMSAverage2 = new CycloneObjects::rmsaverage();
    CycloneObjects::slide* attackSlideUp = new CycloneObjects::slide();
    CycloneObjects::slide* attackSlideDown = new CycloneObjects::slide();;
    CycloneObjects::slide* releaseSlideDown = new CycloneObjects::slide();;
    DunneCore::AdjustableDelayLine* delay1 = new DunneCore::AdjustableDelayLine();

    float convertMsToSamples(float fMilleseconds, float fSampleRate)
    {
        return fMilleseconds * (fSampleRate / 1000.0);
    }

    float convertMsToSeconds(float fMilleseconds) {
        return fMilleseconds / 1000;
    }

    float convertSecondsToCutoffFrequency(float fSeconds) {
        return 1.0 / (2 * M_PI * fSeconds);
    }
    int compute_attackLR(const float *inChannel,
                         float *outChannel,
                         CycloneObjects::rmsaverage *average,
                         CycloneObjects::slide *slideUp,
                         CycloneObjects::slide *slideDown)
    {
        average->push(*inChannel);
        *outChannel = average->getOutput();
        // Copy this signal for later comparison
        float attackMixCopy = *outChannel;
        slideUp->push(*outChannel);
        *outChannel = slideUp->getOutput();
        float slideMixCopy = *outChannel;
        // MARK: BEGIN Logic
        float slideToCompare = slideMixCopy + 0.0; // FIXME: later replace this with attack sensitivity
        float comparator1 = 0.0;
        if (attackMixCopy >= slideToCompare)
            comparator1 = 1.0;
        else
            comparator1 = 0.0;
        float subtractedMix1 = attackMixCopy - slideMixCopy;
        *outChannel = comparator1 * subtractedMix1;
        // MARK: END Logic
        slideDown->push(*outChannel);
        *outChannel = slideDown->getOutput();
        return 1;
    }

    int compute_releaseLR(const float *inChannel,
                         float *outChannel,
                          CycloneObjects::rmsaverage *average,
                          CycloneObjects::slide *slideDown)
    {

        float *tmpRMSOut;
        float tmpRMSOutVal;
        tmpRMSOut = &tmpRMSOutVal;

        average->push(*inChannel);
        *outChannel = average->getOutput();

        float *tmpMixOut;
        float tmpMixOutVal;
        tmpMixOut = &tmpMixOutVal;

        // Mix Left and Right Channel (on left channel) and half them
        *tmpMixOut = *tmpRMSOut * 0.5;

        // Copy this signal for later comparison
        float releaseMixCopy = *outChannel;

        float *tmpSlideOut;
        float tmpSlideOutVal;
        tmpSlideOut = &tmpSlideOutVal;

        slideDown->push(*outChannel);
        *outChannel = slideDown->getOutput();

        float slideMixCopy = *outChannel;

        // MARK: BEGIN Logic

        float slideToCompare = slideMixCopy + 0.0; // FIXME: later replace this with release sensitivity

        float comparator1 = 0.0;

        if (releaseMixCopy <= slideToCompare)
            comparator1 = 1.0;
        else
            comparator1 = 0.0;

        float subtractedMix1 = slideMixCopy - releaseMixCopy;

        *outChannel = comparator1 * subtractedMix1;

        // MARK: END Logic
        return 1;
    }
};
#endif /* IntensifierDSPKernel_h */
