#pragma once
#include <math.h>
namespace CycloneObjects
{
    class slide {
    public:
        void init(float slideUpSamples, float slideDownSamples);
        void clear();
        void push(float input);
        float getOutput() { return output; }
        void setslideup(float f);
        void setslidedown(float f);
    private:
        int slideup;
        int slidedown;
        float last;
        float output;
    };
}
