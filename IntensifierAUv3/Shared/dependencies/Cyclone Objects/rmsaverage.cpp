#include "rmsaverage.h"

namespace CycloneObjects {
    void rmsaverage::init(double sampleRate, unsigned int pointCount)
    {
        sampleRateHz = sampleRate;
        bufferMaxSize = 882000; // 20 seconds

        if (pointCount <= bufferMaxSize)
        {
            buffer.resize(pointCount);
        }
        else
        {
            buffer.resize(bufferMaxSize);
        }
        clear();
        output = 0.0f;
        npoints = pointCount;
    }
    void rmsaverage::deinit()
    {
        buffer.clear();
    }
    void rmsaverage::clear()
    {
        sampleCount = 0;
        accum = 0;
        readIndex = 0;
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }
    float rmsaverage::push(float input)
    {
        if (buffer.empty()) return input;
        unsigned int points = npoints;
        float result = 0; // eventual result
        if (points > 1) {
            unsigned int bufrd = readIndex;
            accum = rmssum(input, accum, 1);
            calib = rmssum(input, calib, 1);
            unsigned int count = sampleCount;
            if(count < npoints) {
                //update count
                count++;
                sampleCount = count;
            } else {
                accum = rmssum(buffer[bufrd], accum, 0);
            };

            // overwrite/store current input value into buf
            buffer[bufrd] = input;

            //calculate result
            result = accum/(float)npoints;
            result = sqrt(result);

            // incrementation step
            bufrd++;
            if (bufrd >= npoints) {
                bufrd = 0;
                accum = calib;
                calib = 0.0f;
            };
            readIndex = bufrd;
        } else {
            result = fabs(input);
        }
        if (isnan(result))
            result = input;
        return (output = result);
    }
    double rmsaverage::rmssum(float input, float accum, int add)
    {
        if (add) {
            accum += (input * input);
        } else {
            accum -= (input * input);
        };
        return (accum);
    }
}
