#ifndef IntensifierDSPKernel_h
#define IntensifierDSPKernel_h
#import "DSPKernel.hpp"
#import "ParameterRamper.hpp"
#import "AdjustableDelayLine.h"
#import "rmsaverage.h"
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
//        rmsaverage_create(&RMSAverage1);
//        rmsaverage_init(RMSAverage1, 441);
//        rmsaverage_create(&RMSAverage2);
//        rmsaverage_init(RMSAverage2, 882);
        RMSAverage1.clear();
        RMSAverage1.init(sampleRate, 441);
        RMSAverage2.clear();
        RMSAverage2.init(sampleRate, 882);
//        slide_create(&attackSlideUp);
//        slide_init(attackSlideUp, 882, 0);
//        slide_create(&attackSlideDown);
//        slide_init(attackSlideDown, 0, 882);
//        slide_create(&releaseSlideDown);
//        slide_init(releaseSlideDown, 0, 44100);
//        delay1.clear();
//        delay1.init(sampleRate, 10);
    }
    void deinit()
    {
        RMSAverage1.deinit();
        RMSAverage2.deinit();
//        slide_destroy(&attackSlideUp);
//        slide_destroy(&attackSlideDown);
//        slide_destroy(&releaseSlideDown);
//        delay1.deinit();
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
        //rmsaverage_reset(RMSAverage1);
        //rmsaverage_reset(RMSAverage2);
        RMSAverage1.clear();
        RMSAverage1.init(sampleRate, 441);
        RMSAverage2.clear();
        RMSAverage2.init(sampleRate, 882);
//        slide_reset(attackSlideUp);
//        slide_reset(attackSlideDown);
//        slide_reset(releaseSlideDown);
//        delay1.clear();
//        delay1.init(sampleRate, 10);
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

//        delay1.setDelayMs(20.0);
//        delay1.setFeedback(0.0);
//        float *tmpAttackOut;
//        float tmpAttackOutVal;
//        tmpAttackOut = &tmpAttackOutVal;
//
//        float *tmpReleaseOut;
//        float tmpReleaseOutVal;
//        tmpReleaseOut = &tmpReleaseOutVal;
//        float *tmpMixOut;
//        float tmpMixOutVal;
//        tmpMixOut = &tmpMixOutVal;
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
//            releaseT = releaseT * 1000;
//            attackT = convertMsToSamples(attackT, sampleRate);
//            releaseT = convertMsToSamples(releaseT, sampleRate);
//            slide_slide_up(attackSlideUp, attackT);
//            slide_slide_down(attackSlideDown, attackT);
//            slide_slide_down(releaseSlideDown, releaseT);

            // advance sample
            for (int channel = 0; channel < channelCount; ++channel) {
                const float *in = (const float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                inputSample = *in;
                float *out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                // convert decibels to amplitude
                *out = (inputSample * pow(10., inputAmount / 20.0));
//                compute_attackLR(out, tmpAttackOut, RMSAverage1, attackSlideUp, attackSlideDown);
//                compute_releaseLR(out, tmpReleaseOut, RMSAverage2, releaseSlideDown);
//                *tmpAttackOut = *tmpAttackOut * attackA;
//                *tmpReleaseOut = *tmpReleaseOut * releaseA;
//                // mix release and attack
//                *tmpMixOut = *tmpAttackOut + *tmpReleaseOut;
//                // convert decibels to amplitude
//                *tmpMixOut = pow(10., *tmpMixOut / 20.0);
//                // reduce/increase output decibels
//                *tmpMixOut = *tmpMixOut * pow(10., outputAmount / 20.0);
//                delay1.push(*out);
//                *out = delay1.getOutput() * *tmpMixOut;
                RMSAverage1.push(*in);
                *out = RMSAverage1.getOutput();
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
    // MARK: Cyclone RMS
//    #define AVERAGE_STACK    44100 //stack value
//    #define AVERAGE_MAXBUF  882000 //max buffer size
//    #define AVERAGE_DEFNPOINTS  100  /* CHECKME */
//    typedef struct {
//        float x_accum; // sum
//        float x_calib; // accumulator calibrator
//        float *x_buf; // buffer pointer
//        float x_stack[AVERAGE_STACK]; // buffer
//        int x_alloc; // if x_buf is allocated or stack
//        unsigned int x_count; // number of samples seen so far
//        unsigned int x_npoints; // number of samples for moving average
//        unsigned int x_sz; // allocated size for x_buf
//        unsigned int x_bufrd; // readhead for buffer
//        unsigned int x_max; // max size of buffer as specified by argument
//    } rmsaverage;
    // MARK: Cyclone Slide
    typedef struct {
        int x_slide_up;
        int x_slide_down;
        float x_last;
    } slide;
    CycloneObjects::rmsaverage RMSAverage1;
    CycloneObjects::rmsaverage RMSAverage2;
//    slide *attackSlideUp;
//    slide *attackSlideDown;
//    slide *releaseSlideDown;
//    DunneCore::AdjustableDelayLine delay1;
//    // MARK: BEGIN Cyclone RMS
//    void rmsaverage_zerobuf(rmsaverage *x) {
//        unsigned int i;
//        for (i=0; i < x->x_sz; i++) {
//            x->x_buf[i] = 0.;
//        };
//    }
//
//    void rmsaverage_reset(rmsaverage *x) {
//        // clear buffer and reset everything to 0
//        x->x_count = 0;
//        x->x_accum = 0;
//        x->x_bufrd = 0;
//        rmsaverage_zerobuf(x);
//    }
//
//    void rmsaverage_sz(rmsaverage *x, unsigned int newsz) {
//        // helper function to deal with allocation issues if needed
//        int alloc = x->x_alloc;
//        unsigned int cursz = x->x_sz; //current size
//        // requested size
//        if (newsz < 0) {
//            newsz = 0;
//        } else if (newsz > AVERAGE_MAXBUF) {
//            newsz = AVERAGE_MAXBUF;
//        };
//        if (!alloc && newsz > AVERAGE_STACK) {
//            x->x_buf = (float *)malloc(sizeof(float) * newsz);
//            x->x_alloc = 1;
//            x->x_sz = newsz;
//        } else if (alloc && newsz > cursz) {
//            x->x_buf = (float *)realloc(x->x_buf, sizeof(float) * newsz);
//            x->x_sz = newsz;
//        } else if (alloc && newsz < AVERAGE_STACK) {
//            free(x->x_buf);
//            x->x_sz = AVERAGE_STACK;
//            x->x_buf = x->x_stack;
//            x->x_alloc = 0;
//        };
//        rmsaverage_reset(x);
//    }
//
//    double rmsaverage_rmssum(float input, float accum, int add) {
//        if (add) {
//            accum += (input * input);
//        } else {
//            accum -= (input * input);
//        };
//        return (accum);
//    }
//
//    int rmsaverage_compute(rmsaverage *x, const float *inSample, float *outSample) {
//        unsigned int npoints = x->x_npoints;
//        float result; // eventual result
//        float input = *inSample;
//        if (npoints > 1) {
//            unsigned int bufrd = x->x_bufrd;
//            // add input to accumulator
//            x->x_accum = rmsaverage_rmssum(input, x->x_accum, 1);
//            x->x_calib = rmsaverage_rmssum(input, x->x_calib, 1);
//            unsigned int count = x->x_count;
//            if(count < npoints) {
//                // update count
//                count++;
//                x->x_count = count;
//            } else {
//                x->x_accum = rmsaverage_rmssum(x->x_buf[bufrd], x->x_accum, 0);
//            };
//
//            // overwrite/store current input value into buf
//            x->x_buf[bufrd] = input;
//
//            // calculate result
//            result = x->x_accum/(float)npoints;
//            result = sqrt(result);
//
//            // incrementation step
//            bufrd++;
//            if (bufrd >= npoints) {
//                bufrd = 0;
//                x->x_accum = x->x_calib;
//                x->x_calib = 0.0;
//            };
//            x->x_bufrd = bufrd;
//        } else {
//            result = fabs(input);
//        }
//        if (isnan(result))
//            result = input;
//
//        *outSample = result;
//        return 1;
//    }
//
//    int rmsaverage_init(rmsaverage *x, unsigned int pointCount) {
//        // default to stack for now...
//        x->x_buf = x->x_stack;
//        x->x_alloc = 0;
//        x->x_sz = AVERAGE_STACK;
//
//        //now allocate x_buf if necessary
//        rmsaverage_sz(x, x->x_npoints);
//
//        rmsaverage_reset(x);
//
//        x->x_npoints = pointCount;
//        return 1;
//    }
//
//    int rmsaverage_create(rmsaverage **x) {
//        *x = (rmsaverage *)malloc(sizeof(rmsaverage));
//        return 1;
//    }
//
//    int rmsaverage_destroy(rmsaverage **x) {
//        free(*x);
//        return 1;
//    }
    // MARK: END Cyclone RMS
    // MARK: BEGIN Cyclone Slide
    int slide_compute(slide *x, float *inSample, float *outSample) {
        float last = x->x_last;
        float f = *inSample;
        float output = 0.0;
        if (f >= last) {
            if (x->x_slide_up > 1.)
                output = last + ((f - last) / x->x_slide_up);
            else
                output = last = f;
        } else if (f < last) {
            if (x->x_slide_down > 1)
                output = last + ((f - last) / x->x_slide_down);
            else
                output = last = f;
        }
        if (output == last && output != f)
            output = f;
        if (isnan(output))
            output = *inSample;

        *outSample = output;
        last = output;
        x->x_last = last;
        return 1;
    }

    void slide_reset(slide *x) {
        x->x_last = 0;
    }

    void slide_slide_up(slide *x, float f) {
        int i = (int)f;
        if (i > 1) {
            x->x_slide_up = i;
        } else {
            x->x_slide_up = 0;
        }
    }

    void slide_slide_down(slide *x, float f) {
        int i = (int)f;
        if (i > 1) {
            x->x_slide_down = i;
        } else {
            x->x_slide_down = 0;
        }
    }

    int slide_init(slide *x, float slideUpSamples, float slideDownSamples) {
        float f1 = slideUpSamples;
        float f2 = slideDownSamples;
        slide_slide_up(x, f1);
        slide_slide_down(x, f2);
        x->x_last = 0.;
        return 1;
    }

    int slide_create(slide **x) {
        *x = (slide *)malloc(sizeof(slide));
        return 1;
    }

    int slide_destroy(slide **x) {
        free(*x);
        return 1;
    }
    // MARK: END Cyclone Slide

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
                         CycloneObjects::rmsaverage average,
                         slide *slideUp,
                         slide *slideDown)
    {
        average.push(*inChannel);
        *outChannel = average.getOutput();
        //rmsaverage_compute(average, inChannel, outChannel);
        // Copy this signal for later comparison
        float attackMixCopy = *outChannel;
        slide_compute(slideUp, outChannel, outChannel);
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
        slide_compute(slideDown, outChannel, outChannel);
        return 1;
    }

    int compute_releaseLR(const float *inChannel,
                         float *outChannel,
                          CycloneObjects::rmsaverage average,
                         slide *slideDown)
    {

        float *tmpRMSOut;
        float tmpRMSOutVal;
        tmpRMSOut = &tmpRMSOutVal;

        average.push(*inChannel);
        *outChannel = average.getOutput();
//        rmsaverage_compute(average, inChannel, outChannel);

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

        slide_compute(slideDown, outChannel, outChannel);

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
