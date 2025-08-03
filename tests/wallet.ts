import {JsonRpcProvider, Wallet as EthersWallet, parseEther, Contract, MaxUint256} from 'ethers'

export class Wallet {
  private wallet: EthersWallet
  private provider: JsonRpcProvider

  constructor(privateKey: string, provider: JsonRpcProvider) {
    this.provider = provider
    this.wallet = new EthersWallet(privateKey, provider)
  }

  static async fromAddress(address: string, provider: JsonRpcProvider): Promise<Wallet> {
    // For contract addresses, we'll impersonate them
    await provider.send('anvil_impersonateAccount', [address])
    const wallet = new EthersWallet(address, provider)
    return new Wallet(address, provider)
  }

  async getAddress(): Promise<string> {
    return this.wallet.address
  }

  async getBalance(): Promise<bigint> {
    return await this.provider.getBalance(this.wallet.address)
  }

  async tokenBalance(tokenAddress: string): Promise<bigint> {
    if (tokenAddress === '0x0000000000000000000000000000000000000000') {
      return await this.getBalance()
    }
    
    const contract = new Contract(
      tokenAddress,
      ['function balanceOf(address) view returns (uint256)'],
      this.provider
    )
    return await contract.balanceOf(this.wallet.address)
  }

  async transfer(to: string, amount: bigint): Promise<string> {
    const tx = await this.wallet.sendTransaction({
      to,
      value: amount
    })
    return tx.hash
  }

  async approveToken(tokenAddress: string, spender: string, amount: bigint): Promise<string> {
    const contract = new Contract(
      tokenAddress,
      ['function approve(address,uint256) returns (bool)'],
      this.wallet
    )
    const tx = await contract.approve(spender, amount)
    return tx.hash
  }

  async unlimitedApprove(tokenAddress: string, spender: string): Promise<string> {
    return this.approveToken(tokenAddress, spender, MaxUint256)
  }

  async topUpFromDonor(tokenAddress: string, donorAddress: string, amount: bigint): Promise<void> {
    // Impersonate donor account
    await this.provider.send('anvil_impersonateAccount', [donorAddress])
    
    const donorWallet = new EthersWallet(donorAddress, this.provider)
    const contract = new Contract(
      tokenAddress,
      ['function transfer(address,uint256) returns (bool)'],
      donorWallet
    )
    
    await contract.transfer(this.wallet.address, amount)
    await this.provider.send('anvil_stopImpersonatingAccount', [donorAddress])
  }

  async send(transaction: any): Promise<{txHash: string; blockHash?: string; blockTimestamp?: bigint}> {
    const tx = await this.wallet.sendTransaction(transaction)
    const receipt = await tx.wait()
    
    return {
      txHash: tx.hash,
      blockHash: receipt?.blockHash,
      blockTimestamp: receipt ? BigInt(receipt.blockNumber) : undefined
    }
  }

  async signOrder(chainId: number, order: any): Promise<string> {
    // This would implement order signing based on your specific order format
    // For now, returning a mock signature
    return '0x' + '00'.repeat(65)
  }
}
