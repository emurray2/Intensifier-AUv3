#include "slide.h"
namespace CycloneObjects {
    void slide::init(float slideUpSamples, float slideDownSamples)
    {
        float f1 = slideup;
        float f2 = slidedown;
        setslideup(f1);
        setslidedown(f2);
        clear();
    }
    void slide::clear()
    {
        last = 0;
    }
    void slide::push(float input)
    {
        output = 0.0;
        if (input >= last) {
            if (slideup > 1.0f)
                output = last + ((input - last) / slideup);
            else
                output = last = input;
        } else if (input < last) {
            if (slidedown > 1)
                output = last + ((input - last) / slidedown);
            else
                output = last = input;
        }
        if (output == last && output != input)
            output = input;
        if (isnan(output))
            output = input;

        last = output;
    }
    void slide::setslideup(float f)
    {
        int i = (int)f;
        if (i > 1)
        {
            slideup = i;
        } else {
            slideup = 0;
        }
    }
    void slide::setslidedown(float f)
    {
        int i = (int)f;
        if (i > 1)
        {
            slidedown = i;
        } else {
            slidedown = 0;
        }
    }
}
