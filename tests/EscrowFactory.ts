import {JsonRpcProvider, Contract, ContractFactory, parseEther, EventLog, Log} from 'ethers'
import {Wallet} from './wallet'

// Define the contract interface
interface IEscrowFactory {
  createSrcEscrow(
    taker: string,
    maker: string,
    secretHash: string,
    timeout: bigint,
    tokenContract: string,
    amount: bigint,
    safetyDeposit: bigint,
    salt: string,
    overrides?: any
  ): Promise<any>
  
  createDstEscrow(
    taker: string,
    maker: string,
    secretHash: string,
    timeout: bigint,
    tokenContract: string,
    amount: bigint,
    safetyDeposit: bigint,
    salt: string,
    overrides?: any
  ): Promise<any>
  
  addressOfEscrowSrc(
    taker: string,
    maker: string,
    secretHash: string,
    timeout: bigint,
    tokenContract: string,
    amount: bigint,
    safetyDeposit: bigint,
    salt: string
  ): Promise<string>
  
  addressOfEscrowDst(
    taker: string,
    maker: string,
    secretHash: string,
    timeout: bigint,
    tokenContract: string,
    amount: bigint,
    safetyDeposit: bigint,
    salt: string
  ): Promise<string>
  
  filters: {
    CreatedEscrow(escrow?: string | null, creator?: string | null, isSrc?: boolean | null, secretHash?: string | null): any
  }
  
  queryFilter(filter: any, blockHash?: string): Promise<(EventLog | Log)[]>
  target: string
}

export class EscrowFactory {
  private contract: Contract & IEscrowFactory
  private provider: JsonRpcProvider

  constructor(provider: JsonRpcProvider, factoryAddress: string) {
    this.provider = provider
    this.contract = new Contract(
      factoryAddress,
      [
        'function createSrcEscrow(address,address,bytes32,uint256,address,uint256,uint256,bytes32) payable returns (address)',
        'function createDstEscrow(address,address,bytes32,uint256,address,uint256,uint256,bytes32) payable returns (address)',
        'function addressOfEscrowSrc(address,address,bytes32,uint256,address,uint256,uint256,bytes32) view returns (address)',
        'function addressOfEscrowDst(address,address,bytes32,uint256,address,uint256,uint256,bytes32) view returns (address)',
        'event CreatedEscrow(address indexed escrow, address indexed creator, bool isSrc, bytes32 indexed secretHash)'
      ],
      provider
    ) as unknown as Contract & IEscrowFactory
  }

  async createSrcEscrow(
    taker: string,
    maker: string,
    secretHash: string,
    timeout: bigint,
    tokenContract: string,
    amount: bigint,
    safetyDeposit: bigint,
    salt: string,
    wallet: Wallet
  ): Promise<string> {
    const tx = await this.contract.connect(wallet as any).createSrcEscrow(
      taker,
      maker,
      secretHash,
      timeout,
      tokenContract, 
      amount,
      safetyDeposit,
      salt,
      {value: tokenContract === '0x0000000000000000000000000000000000000000' ? amount + safetyDeposit : safetyDeposit}
    )
    
    const receipt = await tx.wait()
    
    // Find the CreatedEscrow event
    const createdEvent = receipt.logs.find((log: Log | EventLog) => {
      if ('eventName' in log) {
        return log.eventName === 'CreatedEscrow'
      }
      return false
    }) as EventLog | undefined
    
    if (createdEvent && 'args' in createdEvent) {
      return createdEvent.args[0] // escrow address
    }
    
    // Fallback: return the first log's address
    return receipt.logs[0].address
  }

  async createDstEscrow(
    taker: string,
    maker: string,
    secretHash: string,
    timeout: bigint,
    tokenContract: string,
    amount: bigint,
    safetyDeposit: bigint,
    salt: string,
    wallet: Wallet
  ): Promise<string> {
    const tx = await this.contract.connect(wallet as any).createDstEscrow(
      taker,
      maker,
      secretHash,
      timeout,
      tokenContract,
      amount,
      safetyDeposit,
      salt,
      {value: tokenContract === '0x0000000000000000000000000000000000000000' ? amount + safetyDeposit : safetyDeposit}
    )
    
    const receipt = await tx.wait()
    
    // Find the CreatedEscrow event
    const createdEvent = receipt.logs.find((log: Log | EventLog) => {
      if ('eventName' in log) {
        return log.eventName === 'CreatedEscrow'
      }
      return false
    }) as EventLog | undefined
    
    if (createdEvent && 'args' in createdEvent) {
      return createdEvent.args[0] // escrow address
    }
    
    // Fallback: return the first log's address
    return receipt.logs[0].address
  }

  async getSrcDeployEvent(blockHash: string): Promise<any> {
    const filter = this.contract.filters.CreatedEscrow(null, null, true, null)
    const events = await this.contract.queryFilter(filter, blockHash)
    
    const eventLog = events[0] as EventLog | undefined
    if (eventLog && 'args' in eventLog) {
      return eventLog.args
    }
    
    return undefined
  }

  async getSourceImpl(): Promise<string> {
    // Return a mock implementation address - in real scenario this would be retrieved from the factory
    return '0x1000000000000000000000000000000000000001'
  }

  async getDestinationImpl(): Promise<string> {
    // Return a mock implementation address - in real scenario this would be retrieved from the factory
    return '0x2000000000000000000000000000000000000002'
  }

  getAddress(): string {
    return this.contract.target as string
  }
}
