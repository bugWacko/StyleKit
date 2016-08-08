import Foundation

class Stylist {
    
    typealias Style = [String:AnyObject]
    typealias setValueForControlState = @convention(c) (AnyObject, Selector, AnyObject, UInt) -> Void
    
    let data: Style
    var currentComponent: AnyClass?
    var viewStack = [AnyClass]()
    
    init(data: Style) {
        self.data = data
    }
    
    func apply() {
        let exception = tryBlock {
            self.validateAndApply(self.data)
        }
        
        if let exception = exception {
            loggingPrint("There was an error while applying styles: \(exception)")
        } else {
            loggingPrint("Styles applied")
        }
    }
    
    private func validateAndApply(data: Style) {
        
        for (key, value) in data {
            if let value = value as? Style where NSClassFromString(key) != nil {
                if selectCurrentComponent(key) {
                    viewStack.append(self.currentComponent!)
                }
                validateAndApply(value)
                viewStack.popLast()
            }
            else {
                if let currentComponent = self.currentComponent {
                    applyStyle(key, object: value, currentComponent: currentComponent)
                } else {
                    loggingPrint("Style \(value) not applied on \(key) for \(currentComponent.debugDescription)")
                }
                
            }
        }
    }
    
    private func selectCurrentComponent(name: String) -> Bool {
        
        loggingPrint("Switching to: \(name)")
        
        guard let currentComponent = NSClassFromString(name) else {
            loggingPrint("Component \(name) cannot be selected")
            return false
        }
        self.currentComponent = currentComponent
        return true
    }
    
    private func applyStyle(name: String, object: AnyObject, currentComponent: AnyClass) {
        
        var selectorName = name
        let nameState = name.componentsSeparatedByString(":")
        var state: AnyObject?
        if nameState.count == 2 {
            selectorName = "\(nameState.first!):forState"
            state = ValueTypeChecker().parseControlState(nameState.last!)
        } else {
            state = nil
        }
        
        loggingPrint("Applying: \(selectorName) on level \(viewStack.count)")
        if let styles = object as? Stylist.Style {
            var stylesToApply = Stylist.Style()
            for (style, value) in styles {
                stylesToApply[style] = ValueTypeChecker().getStyleFromValue(value as! String)
            }
            callAppearanceSelector(selectorName, valueOne: stylesToApply, valueTwo: state)
        } else if let object = object as? String {
            let value = ValueTypeChecker().getStyleFromValue(object)
            callAppearanceSelector(selectorName, valueOne: value, valueTwo: state)
        } else {
            loggingPrint("Skipping: \(selectorName), couldn't map to object")
        }
        
    }
    
    private func callAppearanceSelector(selector: String, valueOne: AnyObject?, valueTwo: AnyObject?) {
        
        let modifiedSelector = "set\(selector.capitalizeFirstLetter()):"
        
        var viewStack = self.viewStack
        viewStack.popLast()
        
        let isViewStackRelevant = viewStack.count > 0
        
        if valueOne == nil && valueTwo == nil {
            if isViewStackRelevant {
                self.currentComponent?.appearanceWhenContainedInInstancesOfClasses(viewStack).performSelector(Selector(modifiedSelector))
            } else {
                self.currentComponent?.appearance().performSelector(Selector(modifiedSelector))
            }
        } else if valueOne != nil && valueTwo != nil {
            if isViewStackRelevant {
                let methodSignature = self.currentComponent!.appearanceWhenContainedInInstancesOfClasses(viewStack).methodForSelector(Selector(modifiedSelector))
                let callback = unsafeBitCast(methodSignature, setValueForControlState.self)
                callback(self.currentComponent!.appearanceWhenContainedInInstancesOfClasses(viewStack), Selector(modifiedSelector), valueOne!, valueTwo as! UInt)
            } else {
                let methodSignature = self.currentComponent!.appearance().methodForSelector(Selector(modifiedSelector))
                let callback = unsafeBitCast(methodSignature, setValueForControlState.self)
                callback(self.currentComponent!.appearance(), Selector(modifiedSelector), valueOne!, valueTwo as! UInt)
            }
        } else if valueOne != nil {
            if isViewStackRelevant {
                self.currentComponent?.appearanceWhenContainedInInstancesOfClasses(viewStack).performSelector(Selector(modifiedSelector), withObject: valueOne!)
            } else {
                self.currentComponent?.appearance().performSelector(Selector(modifiedSelector), withObject: valueOne!)
            }
        }
    }
    
}