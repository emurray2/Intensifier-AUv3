#ifndef IntensifierDSPKernel_h
#define IntensifierDSPKernel_h
#import "DSPKernel.hpp"
#import "ParameterRamper.hpp"
#import <vector>

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
                inputAmountRamper.setUIValue(clamp(value, -40.0f, 30.0f));
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
                outputAmountRamper.setUIValue(clamp(value, -40.0f, 30.0f));
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
                inputAmountRamper.startRamp(clamp(value, -40.0f, 30.0f), duration);
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
                outputAmountRamper.startRamp(clamp(value, -40.0f, 30.0f), duration);
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

        // For each sample.
        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            /*
             The parameter values are updated every sample! This is very
             expensive. You probably want to do things differently.
             */
            inputAmountRamper.getAndStep();
            attackAmountRamper.getAndStep();
            releaseAmountRamper.getAndStep();
            attackTimeRamper.getAndStep();
            releaseTimeRamper.getAndStep();
            outputAmountRamper.getAndStep();
            //double inputAmount = double(inputAmountRamper.getAndStep());
            //double attackAmount = double(attackAmountRamper.getAndStep());
            //double releaseAmount = double(releaseAmountRamper.getAndStep());
            //double attackTime = double(attackTimeRamper.getAndStep());
            //double releaseTime = double(releaseTimeRamper.getAndStep());
            //double outputAmount = double(outputAmountRamper.getAndStep());

            int frameOffset = int(frameIndex + bufferOffset);

            for (int channel = 0; channel < channelCount; ++channel) {
                //IntensifierState& state = channelStates[channel];
                float* in  = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                *out = *in;
            }
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
};
#endif /* IntensifierDSPKernel_h */
