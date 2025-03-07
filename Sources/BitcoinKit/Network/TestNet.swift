//
//  TestNet.swift
//  BitcoinKit
//
//  Created by Sun on 2024/8/15.
//

import Foundation

import BitcoinCore

class TestNet: INetwork {
    // MARK: Static Properties

    private static let testNetDiffDate = 1329264000 // February 16th 2012

    // MARK: Properties

    let bundleName = "Bitcoin"

    let pubKeyHash: UInt8 = 0x6F
    let privateKey: UInt8 = 0xEF
    let scriptHash: UInt8 = 0xC4
    let bech32PrefixPattern = "tb"
    let xPubKey: UInt32 = 0x043587CF
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0x0B110907
    let port = 18333
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi = true
    var blockchairChainID = "bitcoin/testnet"

    let dnsSeeds = [
        "testnet-seed.bitcoin.petertodd.org", // Peter Todd
        "testnet-seed.bitcoin.jonasschnelli.ch", // Jonas Schnelli
        "testnet-seed.bluematt.me", // Matt Corallo
        "testnet-seed.bitcoin.schildbach.de", // Andreas Schildbach
        "bitcoin-testnet.bloqseeds.net", // Bloq
    ]

    let dustRelayTxFee =
        3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50
}
