//
//  Configuration.swift
//  BitcoinKit-Example
//
//  Created by Sun on 2024/8/21.
//

import Foundation

import BitcoinCore
import HDWalletKit
import SWToolKit

class Configuration {
    static let shared = Configuration()

    let minLogLevel: Logger.Level = .verbose
    let testNet = false
    let purpose = Purpose.bip84
    let defaultWords = [
        //        "current force clump paper shrug extra zebra employ prefer upon mobile hire",
        "popular game latin harvest silly excess much valid elegant illness edge silk",
    ]
}
