#pragma once
#define AVERAGE_MAXBUF  882000 //max buffer size
#define AVERAGE_DEFNPOINTS  100

#include <vector>
#include <math.h>
namespace CycloneObjects
{
    class rmsaverage {
    public:
        ~rmsaverage() { deinit(); }
        void init(double sampleRate, unsigned int pointCount);
        void deinit();
        void clear();
        float push(float input);
        float getOutput() { return output; }
    private:
        float accum; // sum
        float calib; // accumulator calibrator
        std::vector<float> buffer;
        unsigned int sampleCount; // number of samples seen so far
        unsigned int npoints; // number of samples for moving average
        unsigned int readIndex;
        double sampleRateHz;
        unsigned int bufferMaxSize;
        float output;
        double rmssum(float input, float accum, int add);
    };
}
