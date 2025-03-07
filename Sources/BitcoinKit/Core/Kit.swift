//
//  Kit.swift
//  BitcoinKit
//
//  Created by Sun on 2024/8/15.
//

import Foundation

import BitcoinCore
import HDWalletKit
import Hodler
import SWToolKit

// MARK: - Kit

public class Kit: AbstractKit {
    // MARK: Nested Types

    public enum NetworkType: String, CaseIterable {
        case mainNet
        case testNet
        case regTest

        // MARK: Computed Properties

        var network: INetwork {
            switch self {
            case .mainNet:
                MainNet()
            case .testNet:
                TestNet()
            case .regTest:
                RegTest()
            }
        }
    }

    // MARK: Static Properties

    private static let heightInterval = 2016 // Default block count in difficulty change circle ( Bitcoin )
    private static let targetSpacing = 10 * 60 // Time to mining one block ( 10 min. Bitcoin )
    private static let maxTargetBits = 0x1D00FFFF // Initially and max. target difficulty for blocks

    private static let name = "BitcoinKit"

    // MARK: Computed Properties

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            bitcoinCore.delegate = delegate
        }
    }

    // MARK: Lifecycle

    public convenience init(
        seed: Data,
        purpose: Purpose,
        walletID: String,
        syncMode: BitcoinCore.SyncMode = .api,
        networkType: NetworkType = .mainNet,
        confirmationsThreshold: Int = 6,
        logger: Logger?
    ) throws {
        let version: HDExtendedKeyVersion =
            switch purpose {
            case .bip44: .xprv
            case .bip49: .yprv
            case .bip84: .zprv
            case .bip86: .xprv
            }
        let masterPrivateKey = HDPrivateKey(seed: seed, xPrivKey: version.rawValue)

        try self.init(
            extendedKey: .private(key: masterPrivateKey),
            purpose: purpose,
            walletID: walletID,
            syncMode: syncMode,
            networkType: networkType,
            confirmationsThreshold: confirmationsThreshold,
            logger: logger
        )
    }

    public convenience init(
        extendedKey: HDExtendedKey,
        purpose: Purpose,
        walletID: String,
        syncMode: BitcoinCore.SyncMode = .api,
        networkType: NetworkType = .mainNet,
        confirmationsThreshold: Int = 6,
        logger: Logger?
    ) throws {
        try self.init(
            extendedKey: extendedKey,
            watchAddressPublicKey: nil,
            purpose: purpose,
            walletID: walletID,
            syncMode: syncMode,
            networkType: networkType,
            confirmationsThreshold: confirmationsThreshold,
            logger: logger
        )

        let scriptConverter = ScriptConverter()
        let bech32AddressConverter = SegWitBech32AddressConverter(
            prefix: network.bech32PrefixPattern,
            scriptConverter: scriptConverter
        )
        let base58AddressConverter = Base58AddressConverter(
            addressVersion: network.pubKeyHash,
            addressScriptVersion: network.scriptHash
        )

        bitcoinCore.prepend(addressConverter: bech32AddressConverter)

        switch purpose {
        case .bip44:
            bitcoinCore.add(restoreKeyConverter: Bip44RestoreKeyConverter(addressConverter: base58AddressConverter))
            bitcoinCore.add(restoreKeyConverter: Bip49RestoreKeyConverter(addressConverter: base58AddressConverter))
            bitcoinCore.add(restoreKeyConverter: Bip84RestoreKeyConverter(addressConverter: bech32AddressConverter))

        case .bip49:
            bitcoinCore.add(restoreKeyConverter: Bip49RestoreKeyConverter(addressConverter: base58AddressConverter))

        case .bip84:
            bitcoinCore.add(restoreKeyConverter: Bip84RestoreKeyConverter(addressConverter: bech32AddressConverter))

        case .bip86:
            bitcoinCore.add(restoreKeyConverter: Bip86RestoreKeyConverter(addressConverter: bech32AddressConverter))
        }
    }

    public convenience init(
        watchAddress: String,
        purpose: Purpose,
        walletID: String,
        syncMode: BitcoinCore.SyncMode = .api,
        networkType: NetworkType = .mainNet,
        confirmationsThreshold: Int = 6,
        logger: Logger?
    ) throws {
        let network = networkType.network
        let scriptConverter = ScriptConverter()
        let bech32AddressConverter = SegWitBech32AddressConverter(
            prefix: network.bech32PrefixPattern,
            scriptConverter: scriptConverter
        )
        let base58AddressConverter = Base58AddressConverter(
            addressVersion: network.pubKeyHash,
            addressScriptVersion: network.scriptHash
        )
        let parserChain = AddressConverterChain()
        parserChain.prepend(addressConverter: base58AddressConverter)
        parserChain.prepend(addressConverter: bech32AddressConverter)

        let address = try parserChain.convert(address: watchAddress)
        let publicKey = try WatchAddressPublicKey(data: address.lockingScriptPayload, scriptType: address.scriptType)

        try self.init(
            extendedKey: nil,
            watchAddressPublicKey: publicKey,
            purpose: purpose,
            walletID: walletID,
            syncMode: syncMode,
            networkType: networkType,
            confirmationsThreshold: confirmationsThreshold,
            logger: logger
        )

        bitcoinCore.prepend(addressConverter: bech32AddressConverter)

        switch purpose {
        case .bip44:
            bitcoinCore.add(restoreKeyConverter: Bip44RestoreKeyConverter(addressConverter: base58AddressConverter))
        case .bip49:
            bitcoinCore.add(restoreKeyConverter: Bip49RestoreKeyConverter(addressConverter: base58AddressConverter))
        case .bip84:
            bitcoinCore.add(restoreKeyConverter: Bip84RestoreKeyConverter(addressConverter: bech32AddressConverter))
        case .bip86:
            bitcoinCore.add(restoreKeyConverter: Bip86RestoreKeyConverter(addressConverter: bech32AddressConverter))
        }
    }

    private init(
        extendedKey: HDExtendedKey?,
        watchAddressPublicKey: WatchAddressPublicKey?,
        purpose: Purpose,
        walletID: String,
        syncMode: BitcoinCore.SyncMode = .api,
        networkType: NetworkType = .mainNet,
        confirmationsThreshold: Int = 6,
        logger: Logger?
    ) throws {
        let network = networkType.network
        let logger = logger ?? Logger(minLogLevel: .verbose)
        let databaseFilePath = try DirectoryHelper.directoryURL(for: Kit.name)
            .appendingPathComponent(Kit.databaseFileName(
                walletID: walletID,
                networkType: networkType,
                purpose: purpose,
                syncMode: syncMode
            )).path
        let storage = GrdbStorage(databaseFilePath: databaseFilePath)
        let checkpoint = Checkpoint.resolveCheckpoint(network: network, syncMode: syncMode, storage: storage)
        let apiSyncStateManager = ApiSyncStateManager(
            storage: storage,
            restoreFromApi: network.syncableFromApi && syncMode != BitcoinCore.SyncMode.full
        )

        let apiTransactionProvider: IApiTransactionProvider?
        switch networkType {
        case .mainNet:
            let hsBlockHashFetcher = SWBlockHashFetcher(
                wwURL: "https://api.blocksdecoded.com/v1/blockchains/bitcoin",
                logger: logger
            )

            if case .blockchair = syncMode {
                let blockchairApi = BlockchairApi(chainID: network.blockchairChainID, logger: logger)
                let blockchairBlockHashFetcher = BlockchairBlockHashFetcher(blockchairApi: blockchairApi)
                let blockHashFetcher = BlockHashFetcher(
                    wwFetcher: hsBlockHashFetcher,
                    blockchairFetcher: blockchairBlockHashFetcher,
                    checkpointHeight: checkpoint.block.height
                )

                apiTransactionProvider = BlockchairTransactionProvider(
                    blockchairApi: blockchairApi,
                    blockHashFetcher: blockHashFetcher
                )
//                    let blockchainComProvider = BlockchainComApi(url: "https://blockchain.info", blockHashFetcher:
//                    blockHashFetcher, logger: logger)
//                    apiTransactionProvider = BiApiBlockProvider(restoreProvider: blockchainComProvider, syncProvider:
//                    blockchairProvider, apiSyncStateManager: apiSyncStateManager)
            } else {
                apiTransactionProvider = BlockchainComApi(
                    url: "https://blockchain.info",
                    blockHashFetcher: hsBlockHashFetcher,
                    logger: logger
                )
            }

        case .testNet:
            apiTransactionProvider = BCoinApi(url: "https://btc-testnet.horizontalsystems.xyz/api", logger: logger)

        case .regTest:
            apiTransactionProvider = nil
        }

        let paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)
        let bitcoinCoreBuilder = BitcoinCoreBuilder(logger: logger)

        let difficultyEncoder = DifficultyEncoder()

        let blockValidatorSet = BlockValidatorSet()
        blockValidatorSet.add(blockValidator: ProofOfWorkValidator(difficultyEncoder: difficultyEncoder))

        let blockValidatorChain = BlockValidatorChain()
        let blockHelper = BlockValidatorHelper(storage: storage)

        switch networkType {
        case .mainNet:
            blockValidatorChain.add(blockValidator: LegacyDifficultyAdjustmentValidator(
                encoder: difficultyEncoder,
                blockValidatorHelper: blockHelper,
                heightInterval: Kit.heightInterval,
                targetTimespan: Kit.heightInterval * Kit.targetSpacing,
                maxTargetBits: Kit.maxTargetBits
            ))
            blockValidatorChain.add(blockValidator: BitsValidator())

        case .regTest,
             .testNet:
            blockValidatorChain.add(blockValidator: LegacyDifficultyAdjustmentValidator(
                encoder: difficultyEncoder,
                blockValidatorHelper: blockHelper,
                heightInterval: Kit.heightInterval,
                targetTimespan: Kit.heightInterval * Kit.targetSpacing,
                maxTargetBits: Kit.maxTargetBits
            ))
            blockValidatorChain.add(blockValidator: LegacyTestNetDifficultyValidator(
                blockHelper: blockHelper,
                heightInterval: Kit.heightInterval,
                targetSpacing: Kit.targetSpacing,
                maxTargetBits: Kit.maxTargetBits
            ))
        }

        blockValidatorSet.add(blockValidator: blockValidatorChain)

        let blockMedianTimeHelper =
            if case .blockchair = syncMode {
                BlockMedianTimeHelper(storage: storage, approximate: true)
            } else {
                BlockMedianTimeHelper(storage: storage, approximate: false)
            }
        let hodler = HodlerPlugin(
            addressConverter: bitcoinCoreBuilder.addressConverter,
            blockMedianTimeHelper: blockMedianTimeHelper,
            publicKeyStorage: storage
        )

        let bitcoinCore = try bitcoinCoreBuilder
            .set(network: network)
            .set(apiTransactionProvider: apiTransactionProvider)
            .set(checkpoint: checkpoint)
            .set(apiSyncStateManager: apiSyncStateManager)
            .set(paymentAddressParser: paymentAddressParser)
            .set(walletID: walletID)
            .set(confirmationsThreshold: confirmationsThreshold)
            .set(peerSize: 10)
            .set(syncMode: syncMode)
            .set(storage: storage)
            .set(blockValidator: blockValidatorSet)
            .add(plugin: hodler)
            .set(purpose: purpose)
            .set(extendedKey: extendedKey)
            .set(watchAddressPublicKey: watchAddressPublicKey)
            .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        if purpose == .bip44 {
            bitcoinCore.add(restoreKeyConverter: hodler)
        }
    }
}

extension Kit {
    public static func clear(exceptFor walletIDsToExclude: [String] = []) throws {
        try DirectoryHelper.removeAll(inDirectory: Kit.name, except: walletIDsToExclude)
    }

    private static func databaseFileName(
        walletID: String,
        networkType: NetworkType,
        purpose: Purpose,
        syncMode: BitcoinCore.SyncMode
    )
        -> String {
        "\(walletID)-\(networkType.rawValue)-\(purpose.description)-\(syncMode)"
    }
    
    private static func addressConverter(purpose: Purpose, network: INetwork) -> AddressConverterChain {
        let addressConverter = AddressConverterChain()
        switch purpose {
        case .bip44,
             .bip49:
            addressConverter.prepend(addressConverter: Base58AddressConverter(
                addressVersion: network.pubKeyHash,
                addressScriptVersion: network.scriptHash
            ))

        case .bip84,
             .bip86:
            let scriptConverter = ScriptConverter()
            addressConverter.prepend(addressConverter: SegWitBech32AddressConverter(
                prefix: network.bech32PrefixPattern,
                scriptConverter: scriptConverter
            ))
        }
        return addressConverter
    }

    public static func firstAddress(
        seed: Data,
        purpose: Purpose,
        networkType: NetworkType = .mainNet
    ) throws
        -> Address {
        let network = networkType.network

        return try BitcoinCore.firstAddress(
            seed: seed,
            purpose: purpose,
            network: network,
            addressCoverter: addressConverter(purpose: purpose, network: network)
        )
    }
    
    public static func firstAddress(
        extendedKey: HDExtendedKey,
        purpose: Purpose,
        networkType: NetworkType = .mainNet
    ) throws
        -> Address {
        let network = networkType.network
        
        return try BitcoinCore.firstAddress(
            extendedKey: extendedKey,
            purpose: purpose,
            network: network,
            addressCoverter: addressConverter(purpose: purpose, network: network)
        )
    }
}
