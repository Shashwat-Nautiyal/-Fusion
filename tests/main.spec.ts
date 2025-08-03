import 'dotenv/config'

import {expect, jest} from '@jest/globals'

import {createServer, CreateServerReturnType} from 'prool'

import {anvil} from 'prool/instances'

import {
  ContractFactory,
  JsonRpcProvider,
  parseEther,
  parseUnits,
  randomBytes,
  Wallet as SignerWallet,
  ethers,
  keccak256,
  toUtf8Bytes,
  Contract
} from 'ethers'

import {uint8ArrayToHex} from '@1inch/byte-utils'
import assert from 'node:assert'
import {ChainConfig, config} from './config'
import {Wallet} from './wallet'
import {EscrowFactory} from './EscrowFactory'

// Import your contract artifacts
import resolverContractArtifact from '../out/Resolver.sol/Resolver.json'
import factoryContractArtifact from '../out/EscrowFactory.sol/EscrowFactory.json'
import mockERC20ContractArtifact from '../out/MockERC20.sol/MockERC20.json'

jest.setTimeout(1000 * 60 * 5) // 5 minutes timeout

const userPk = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d'
const resolverPk = '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a'

describe('Resolver Cross-Chain Tests', () => {
  const srcChainId = config.chain.source.chainId
  const dstChainId = config.chain.destination.chainId

  type Chain = {
    node?: CreateServerReturnType
    provider: JsonRpcProvider
    escrowFactory: string
    resolver: string
    mockToken: string
  }

  let src: Chain
  let dst: Chain
  let srcChainUser: Wallet
  let dstChainUser: Wallet
  let srcChainResolver: Wallet
  let dstChainResolver: Wallet
  let srcFactory: EscrowFactory
  let dstFactory: EscrowFactory

  // Test constants (matching your Foundry tests)
  const srcAmount = parseUnits('1000', 18) // 1000 tokens
  const dstAmount = parseEther('2') // 2 ETH
  const safetyDeposit = parseEther('0.1') // 0.1 ETH safety deposit
  const secret = keccak256(toUtf8Bytes('secret123'))
  const secretHash = ethers.sha256(ethers.getBytes(secret))
  const salt = keccak256(toUtf8Bytes('salt123'))

  async function increaseTime(seconds: number): Promise<void> {
    await Promise.all([
      src.provider.send('evm_increaseTime', [seconds]),
      dst.provider.send('evm_increaseTime', [seconds])
    ])
    await Promise.all([
      src.provider.send('evm_mine', []),
      dst.provider.send('evm_mine', [])
    ])
  }

  beforeAll(async () => {
    [src, dst] = await Promise.all([
      initChain(config.chain.source),
      initChain(config.chain.destination)
    ])

    srcChainUser = new Wallet(userPk, src.provider)
    dstChainUser = new Wallet(userPk, dst.provider)
    srcChainResolver = new Wallet(resolverPk, src.provider)
    dstChainResolver = new Wallet(resolverPk, dst.provider)

    srcFactory = new EscrowFactory(src.provider, src.escrowFactory)
    dstFactory = new EscrowFactory(dst.provider, dst.escrowFactory)

    // Fund accounts with ETH
    await Promise.all([
      src.provider.send('anvil_setBalance', [await srcChainUser.getAddress(), '0x56BC75E2D630E5E0']),
      dst.provider.send('anvil_setBalance', [await dstChainUser.getAddress(), '0x56BC75E2D630E5E0']),
      src.provider.send('anvil_setBalance', [await srcChainResolver.getAddress(), '0x56BC75E2D630E5E0']),
      dst.provider.send('anvil_setBalance', [await dstChainResolver.getAddress(), '0x56BC75E2D630E5E0']),
      src.provider.send('anvil_setBalance', [src.resolver, '0x56BC75E2D630E5E0']),
      dst.provider.send('anvil_setBalance', [dst.resolver, '0x56BC75E2D630E5E0'])
    ])

    // Fund accounts with tokens
    await fundTokens()
  })

  afterAll(async () => {
    src.provider.destroy()
    dst.provider.destroy()
    await Promise.all([src.node?.stop(), dst.node?.stop()])
  })

  async function fundTokens() {
    // Create deployer wallets for token transfers
    const srcDeployer = new SignerWallet(config.chain.source.ownerPrivateKey, src.provider)
    const dstDeployer = new SignerWallet(config.chain.destination.ownerPrivateKey, dst.provider)
    
    // Fund users and resolvers with mock tokens
    const srcTokenContract = new Contract(
      src.mockToken,
      ['function transfer(address,uint256) returns (bool)'],
      srcDeployer
    )

    const dstTokenContract = new Contract(
      dst.mockToken,
      ['function transfer(address,uint256) returns (bool)'],
      dstDeployer
    )

    // Transfer tokens to users and resolvers
    await srcTokenContract.transfer(await srcChainUser.getAddress(), parseUnits('5000', 18))
    await srcTokenContract.transfer(src.resolver, parseUnits('5000', 18))
  }

  describe('Basic Functionality Tests', () => {
    it('should transfer ownership', async () => {
      const resolverInstance = new Contract(
        src.resolver,
        resolverContractArtifact.abi,
        srcChainResolver as any
      )

      const newOwner = await dstChainUser.getAddress()
      await resolverInstance.transferOwnership(newOwner)
      
      const currentOwner = await resolverInstance.owner()
      expect(currentOwner).toBe(newOwner)
    })

    it('should deploy source escrow correctly', async () => {
      const timeout = BigInt(Math.floor(Date.now() / 1000) + 1000)
      
      // User approves tokens
      await srcChainUser.approveToken(src.mockToken, src.escrowFactory, srcAmount)
      
      const resolverInstance = new Contract(
        src.resolver,
        resolverContractArtifact.abi,
        srcChainUser as any
      )

      const tx = await resolverInstance.deploySrcEscrow(
        await srcChainUser.getAddress(),
        secretHash,
        timeout,
        src.mockToken,
        srcAmount,
        safetyDeposit,
        salt,
        {value: safetyDeposit}
      )

      const receipt = await tx.wait()
      expect(receipt.status).toBe(1)

      // Verify escrow was created
      const events = receipt.logs.filter((log: any) => 
        log.topics[0] === ethers.id('SrcEscrowDeployed(address,bytes32,address)')
      )
      expect(events.length).toBe(1)
    })

    it('should deploy destination escrow correctly', async () => {
      const timeout = BigInt(Math.floor(Date.now() / 1000) + 1000)
      
      const resolverInstance = new Contract(
        dst.resolver,
        resolverContractArtifact.abi,
        dstChainResolver as any
      )

      const tx = await resolverInstance.deployDstEscrow(
        await dstChainUser.getAddress(),
        secretHash,
        timeout,
        '0x0000000000000000000000000000000000000000', // ETH
        dstAmount,
        safetyDeposit,
        salt,
        {value: dstAmount + safetyDeposit}
      )

      const receipt = await tx.wait()
      expect(receipt.status).toBe(1)

      // Verify escrow was created
      const events = receipt.logs.filter((log: any) => 
        log.topics[0] === ethers.id('DstEscrowDeployed(address,bytes32,address)')
      )
      expect(events.length).toBe(1)
    })
  })

  describe('Withdraw and Cancel Tests', () => {
    let srcEscrowAddress: string
    let dstEscrowAddress: string

    beforeEach(async () => {
      const timeout = BigInt(Math.floor(Date.now() / 1000) + 1000)
      
      // Deploy source escrow
      await srcChainUser.approveToken(src.mockToken, src.escrowFactory, srcAmount)
      const srcResolverInstance = new Contract(
        src.resolver,
        resolverContractArtifact.abi,
        srcChainUser as any
      )
      
      const srcTx = await srcResolverInstance.deploySrcEscrow(
        await srcChainUser.getAddress(),
        secretHash,
        timeout,
        src.mockToken,
        srcAmount,
        safetyDeposit,
        salt,
        {value: safetyDeposit}
      )
      const srcReceipt = await srcTx.wait()
      srcEscrowAddress = srcReceipt.logs[0].address

      // Deploy destination escrow
      const dstResolverInstance = new Contract(
        dst.resolver,
        resolverContractArtifact.abi,
        dstChainResolver as any
      )
      
      const dstTx = await dstResolverInstance.deployDstEscrow(
        await dstChainUser.getAddress(),
        secretHash,
        timeout,
        '0x0000000000000000000000000000000000000000',
        dstAmount,
        safetyDeposit,
        salt,
        {value: dstAmount + safetyDeposit}
      )
      const dstReceipt = await dstTx.wait()
      dstEscrowAddress = dstReceipt.logs[0].address
    })

    it('should allow resolver to withdraw from source escrow', async () => {
      const resolverInstance = new Contract(
        src.resolver,
        resolverContractArtifact.abi,
        srcChainResolver as any
      )

      const resolverBalanceBefore = await srcChainResolver.tokenBalance(src.mockToken)
      
      await resolverInstance.withdrawFromSrc(srcEscrowAddress, secret)
      
      const resolverBalanceAfter = await srcChainResolver.tokenBalance(src.mockToken)
      expect(resolverBalanceAfter - resolverBalanceBefore).toBe(srcAmount)
    })

    it('should allow cancellation after timeout', async () => {
      await increaseTime(1001) // Pass timeout
      
      const resolverInstance = new Contract(
        src.resolver,
        resolverContractArtifact.abi,
        srcChainUser as any
      )

      const userBalanceBefore = await srcChainUser.tokenBalance(src.mockToken)
      
      await resolverInstance.cancelSrc(srcEscrowAddress)
      
      const userBalanceAfter = await srcChainUser.tokenBalance(src.mockToken)
      expect(userBalanceAfter - userBalanceBefore).toBe(srcAmount)
    })

    it('should allow public withdraw after timeout', async () => {
      await increaseTime(1001) // Pass timeout
      
      const randomWallet = await Wallet.fromAddress('0x1234567890123456789012345678901234567890', src.provider)
      
      const resolverInstance = new Contract(
        src.resolver,
        resolverContractArtifact.abi,
        randomWallet as any
      )

      await resolverInstance.publicWithdraw(srcEscrowAddress, secret)
      
      // Verify resolver received the funds (since resolver is taker in source escrow)
      // Additional balance checks would go here
    })
  })

  describe('Utility Functions Tests', () => {
    it('should verify secrets correctly', async () => {
      const resolverInstance = new Contract(
        src.resolver,
        resolverContractArtifact.abi,
        src.provider
      )

      const isValid = await resolverInstance.verifySecret(secret, secretHash)
      expect(isValid).toBe(true)

      const wrongSecret = keccak256(toUtf8Bytes('wrong'))
      const isInvalid = await resolverInstance.verifySecret(wrongSecret, secretHash)
      expect(isInvalid).toBe(false)
    })

    it('should handle emergency withdrawals', async () => {
      const resolverInstance = new Contract(
        src.resolver,
        resolverContractArtifact.abi,
        srcChainResolver as any
      )

      const ownerBalanceBefore = await srcChainResolver.getBalance()
      
      await resolverInstance.emergencyWithdraw(
        '0x0000000000000000000000000000000000000000',
        parseEther('1')
      )
      
      const ownerBalanceAfter = await srcChainResolver.getBalance()
      expect(ownerBalanceAfter > ownerBalanceBefore).toBe(true)
    })
  })

  async function initChain(cnf: ChainConfig): Promise<Chain> {
    const {node, provider} = await getProvider(cnf)
    const deployer = new SignerWallet(cnf.ownerPrivateKey, provider)

    // Deploy MockERC20 for testing
    const mockToken = await deployContract(
      mockERC20ContractArtifact,
      [],
      provider,
      deployer
    )

    // Deploy EscrowFactory
    const escrowFactory = await deployContract(
      factoryContractArtifact,
      [],
      provider,
      deployer
    )

    // Deploy Resolver
    const resolver = await deployContract(
      resolverContractArtifact,
      [escrowFactory, await deployer.getAddress()],
      provider,
      deployer
    )

    return {node, provider, escrowFactory, resolver, mockToken}
  }

  async function getProvider(cnf: ChainConfig): Promise<{node?: CreateServerReturnType; provider: JsonRpcProvider}> {
    if (!cnf.createFork) {
      return {
        provider: new JsonRpcProvider(cnf.url, cnf.chainId, {
          cacheTimeout: -1,
          staticNetwork: true
        })
      }
    }

    const node = createServer({
      instance: anvil({forkUrl: cnf.url, chainId: cnf.chainId}),
      limit: 1
    })

    await node.start()
    const address = node.address()
    assert(address)

    const provider = new JsonRpcProvider(
      `http://[${address.address}]:${address.port}/1`,
      cnf.chainId,
      {cacheTimeout: -1, staticNetwork: true}
    )

    return {provider, node}
  }

  async function deployContract(
    contractJson: {abi: any; bytecode: any},
    params: unknown[],
    provider: JsonRpcProvider,
    deployer: SignerWallet
  ): Promise<string> {
    const factory = new ContractFactory(contractJson.abi, contractJson.bytecode, deployer)
    const contract = await factory.deploy(...params)
    await contract.waitForDeployment()
    return await contract.getAddress()
  }
})
