import Foundation

class AUv3IntensifierParameters {
    private enum AUv3IntensifierParam: AUParameterAddress {
        case inputAmount, attackAmount, releaseAmount, attackTime, releaseTime, outputAmount
    }

    var inputAmountParam: AUParameter = {
        let parameter =
            AUParameterTree.createParameter(withIdentifier: "inputAmount",
                                            name: "Input Amount",
                                            address: AUv3IntensifierParam.inputAmount.rawValue,
                                            min: -40.0,
                                            max: 30.0,
                                            unit: .decibels,
                                            unitName: nil,
                                            flags: [.flag_IsReadable,
                                                    .flag_IsWritable,
                                                    .flag_CanRamp],
                                            valueStrings: nil,
                                            dependentParameters: nil)
        // Set default value
        parameter.value = 0.0

        return parameter
    }()
    var attackAmountParam: AUParameter = {
        let parameter =
            AUParameterTree.createParameter(withIdentifier: "attackAmount",
                                            name: "Attack Amount",
                                            address: AUv3IntensifierParam.attackAmount.rawValue,
                                            min: -40.0,
                                            max: 30.0,
                                            unit: .decibels,
                                            unitName: nil,
                                            flags: [.flag_IsReadable,
                                                    .flag_IsWritable,
                                                    .flag_CanRamp],
                                            valueStrings: nil,
                                            dependentParameters: nil)
        // Set default value
        parameter.value = 0.0

        return parameter
    }()
    var releaseAmountParam: AUParameter = {
        let parameter =
            AUParameterTree.createParameter(withIdentifier: "releaseAmount",
                                            name: "Release Amount",
                                            address: AUv3IntensifierParam.releaseAmount.rawValue,
                                            min: -40.0,
                                            max: 30.0,
                                            unit: .decibels,
                                            unitName: nil,
                                            flags: [.flag_IsReadable,
                                                    .flag_IsWritable,
                                                    .flag_CanRamp],
                                            valueStrings: nil,
                                            dependentParameters: nil)
        // Set default value
        parameter.value = 0.0

        return parameter
    }()
    var attackTimeParam: AUParameter = {
        let parameter =
            AUParameterTree.createParameter(withIdentifier: "attackTime",
                                            name: "Attack Time",
                                            address: AUv3IntensifierParam.attackTime.rawValue,
                                            min: 0.0,
                                            max: 500.0,
                                            unit: .milliseconds,
                                            unitName: nil,
                                            flags: [.flag_IsReadable,
                                                    .flag_IsWritable,
                                                    .flag_CanRamp],
                                            valueStrings: nil,
                                            dependentParameters: nil)
        // Set default value
        parameter.value = 20.0

        return parameter
    }()
    var releaseTimeParam: AUParameter = {
        let parameter =
            AUParameterTree.createParameter(withIdentifier: "releaseTime",
                                            name: "Release Time",
                                            address: AUv3IntensifierParam.releaseTime.rawValue,
                                            min: 0.0,
                                            max: 5.0,
                                            unit: .seconds,
                                            unitName: nil,
                                            flags: [.flag_IsReadable,
                                                    .flag_IsWritable,
                                                    .flag_CanRamp],
                                            valueStrings: nil,
                                            dependentParameters: nil)
        // Set default value
        parameter.value = 1.0

        return parameter
    }()
    var outputAmountParam: AUParameter = {
        let parameter =
            AUParameterTree.createParameter(withIdentifier: "outputAmount",
                                            name: "Output Amount",
                                            address: AUv3IntensifierParam.outputAmount.rawValue,
                                            min: -40.0,
                                            max: 30.0,
                                            unit: .decibels,
                                            unitName: nil,
                                            flags: [.flag_IsReadable,
                                                    .flag_IsWritable,
                                                    .flag_CanRamp],
                                            valueStrings: nil,
                                            dependentParameters: nil)
        // Set default value
        parameter.value = 0.0

        return parameter
    }()

    let parameterTree: AUParameterTree

    init(kernelAdapter: IntensifierDSPKernelAdapter) {

        // Create the audio unit's tree of parameters
        parameterTree = AUParameterTree.createTree(withChildren: [inputAmountParam,
                                                                  attackAmountParam,
                                                                  releaseAmountParam,
                                                                  attackTimeParam,
                                                                  releaseTimeParam,
                                                                  outputAmountParam])

        // Closure observing all externally-generated parameter value changes.
        parameterTree.implementorValueObserver = { param, value in
            kernelAdapter.setParameter(param, value: value)
        }

        // Closure returning state of requested parameter.
        parameterTree.implementorValueProvider = { param in
            return kernelAdapter.value(for: param)
        }

        // Closure returning string representation of requested parameter value.
        parameterTree.implementorStringFromValueCallback = { param, value in
            switch param.address {
            case AUv3IntensifierParam.inputAmount.rawValue:
                return String(format: "%.2f", value ?? param.value)
            case AUv3IntensifierParam.attackAmount.rawValue:
                return String(format: "%.2f", value ?? param.value)
            case AUv3IntensifierParam.releaseAmount.rawValue:
                return String(format: "%.2f", value ?? param.value)
            case AUv3IntensifierParam.attackTime.rawValue:
                return String(format: "%.2f", value ?? param.value)
            case AUv3IntensifierParam.releaseTime.rawValue:
                return String(format: "%.2f", value ?? param.value)
            case AUv3IntensifierParam.outputAmount.rawValue:
                return String(format: "%.2f", value ?? param.value)
            default:
                return "?"
            }
        }
    }
    func setParameterValues(
        inputAmount: AUValue,
        attackAmount: AUValue,
        releaseAmount: AUValue,
        attackTime: AUValue,
        releaseTime: AUValue,
        outputAmount: AUValue
    ) {
        inputAmountParam.value = inputAmount
        attackAmountParam.value = attackAmount
        releaseAmountParam.value = releaseAmount
        attackTimeParam.value = attackTime
        releaseTimeParam.value = releaseTime
        outputAmountParam.value = outputAmount
    }
}
