//
//  UIColorTransformer.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/26/23.
//

import Foundation
import SwiftUI

class UIColorTransformer: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let color = value as? UIColor else { return nil }
        do{
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
            return data
        } catch {
            print("[EMM] -- UIColorTransformer -- transformedValue -- error: \(error)")
            return nil
        }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let color = value as? UIColor else { return nil }
        do{
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
            return data
        } catch {
            print("[EMM] -- UIColorTransformer -- transformedValue -- error: \(error)")
            return nil
        }
    }
}
