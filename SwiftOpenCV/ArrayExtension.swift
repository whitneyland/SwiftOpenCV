//
//  ArrayExtension.swift
//  SwiftOpenCV
//
//  Created by Lee Whitney on 10/28/14.
//  Copyright (c) 2014 WhitneyLand. All rights reserved.
//

import Foundation

extension Array {
    func combine(separator: String) -> String{
        var str : String = ""
        var idx = 0
        for item in self {
            str += "\(item)"
            if idx < self.count-1 {
                str += separator
            }
            idx += 1
        }
        return str
    }
}
