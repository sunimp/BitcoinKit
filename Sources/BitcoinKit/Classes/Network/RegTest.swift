//
//  RegTest.swift
//
//  Created by Sun on 2018/8/23.
//

import Foundation

import BitcoinCore

class RegTest: INetwork {
    let bundleName = "BitcoinKit"

    let pubKeyHash: UInt8 = 0x6F
    let privateKey: UInt8 = 0xEF
    let scriptHash: UInt8 = 0xC4
    let bech32PrefixPattern = "bcrt"
    let xPubKey: UInt32 = 0x043587CF
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xFABFB5DA
    let port = 18444
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi = false
    var blockchairChainID = ""

    let dnsSeeds = [
        "btc-regtest.horizontalsystems.xyz",
        "btc01-regtest.horizontalsystems.xyz",
        "btc02-regtest.horizontalsystems.xyz",
        "btc03-regtest.horizontalsystems.xyz",
    ]

    let dustRelayTxFee =
        3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50
}
