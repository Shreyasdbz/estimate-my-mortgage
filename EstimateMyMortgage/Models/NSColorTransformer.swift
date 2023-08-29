//
//  NSColorTransformer.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import Foundation
import AppKit

class NSColorTransformer: ValueTransformer {

    override func transformedValue(_ value: Any?) -> Any? {
        
        guard let color = value as? NSColor else { return nil }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
            return data
        } catch {
            return nil
        }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        //
    }
}
