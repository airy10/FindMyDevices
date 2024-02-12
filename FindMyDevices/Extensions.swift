//
//  Extensions.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 08/02/2024.
//

import Foundation

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
