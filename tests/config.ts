import {z} from 'zod'
import Sdk from '@1inch/cross-chain-sdk'
import * as process from 'node:process'

const bool = z
    .string()
    .transform((v) => v.toLowerCase() === 'true')
    .pipe(z.boolean())

const ConfigSchema = z.object({
    SRC_CHAIN_RPC: z.string().url(),
    DST_CHAIN_RPC: z.string().url(),
    SRC_CHAIN_CREATE_FORK: bool.default('true'),
    DST_CHAIN_CREATE_FORK: bool.default('true')
})

const fromEnv = ConfigSchema.parse(process.env)

export const config = {
    chain: {
        source: {
            chainId: 84532,
            url: fromEnv.SRC_CHAIN_RPC,
            createFork: fromEnv.SRC_CHAIN_CREATE_FORK,
            limitOrderProtocol: '0xE53136D9De56672e8D2665C98653AC7b8A60Dc44',  // 1inch limit order protocol on base sepolia
            wrappedNative: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
            ownerPrivateKey: '0xeda1b19bbf5fecbb9ee6c34e1e5ea2774bd355961bf8558668a505123e2ab2b4',
            tokens: {
                USDC: {
                    address: '0x036CbD53842c5426634e7929541eC2318f3dCF7e', // base sepolia USDC address
                    donor: '0x6c5aAE4622B835058A41879bA5e128019B9047d6' // whale address
                }
            }
        },
        destination: {
            chainId: 128123,
            url: 'https://node.ghostnet.etherlink.com',
            createFork: fromEnv.DST_CHAIN_CREATE_FORK,
            limitOrderProtocol: '0x0be3B4AF70eAB02052C8ab6ECd3fA4594240cFb1',
            wrappedNative: '0xB1Ea698633d57705e93b0E40c1077d46CD6A51d8', //XTZ (Testnt NATIVE TOKEN)
            ownerPrivateKey: '0xeda1b19bbf5fecbb9ee6c34e1e5ea2774bd355961bf8558668a505123e2ab2b4',
            tokens: {
                USDC: {
                    address: '0x4C2AA252BEe766D3399850569713b55178934849',
                    donor: '0xfEfE12bf26A2802ABEe59393B19b0704Fb274844' // antriksh
                }
            }
        }
    }
} as const

export type ChainConfig = (typeof config.chain)['source' | 'destination']