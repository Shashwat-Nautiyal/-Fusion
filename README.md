
# 🚀 Fusion+ Cross-Chain Escrow Swaps

> 🔗 **Trustless atomic swaps between Base Sepolia and Etherlink testnets**

**Fusion+** is a cutting-edge **proof-of-concept** blockchain application that enables **atomic, trustless token swaps** between different blockchain networks without relying on centralized bridges or intermediaries. Currently supporting **Base Sepolia** and **Etherlink** testnets, this project demonstrates how cryptographic primitives can solve one of DeFi's biggest challenges: secure cross-chain asset transfers.

## 🎯 Problem Statement

Traditional cross-chain swaps suffer from:
- 🔐 **Trust Requirements**: Relying on centralized bridges
- ⚡ **Security Risks**: Vulnerability to bridge hacks and exploits  
- 🕐 **Timing Issues**: Risk of funds being permanently locked
- 💸 **High Fees**: Expensive intermediary costs

## ✨ Key Features

### 🔒 **Cryptographic Security**
- **Hashlock Mechanism**: Uses SHA-256 hashes for secure secret-based unlocking
- **Timelock Safety**: Built-in expiration prevents permanent fund loss
- **Atomic Guarantees**: Either both sides complete or neither does

### 🌐 **Cross-Chain Support**
- **Base Sepolia**: Ethereum Layer 2 testnet integration
- **Etherlink**: Tezos-based blockchain support
- **Extensible Design**: Architecture supports additional chains

### 🏭 **Smart Contract Factory Pattern**
- **Scalable Deployment**: Factory contracts create individual escrows
- **Gas Optimization**: Efficient contract instantiation
- **Modular Architecture**: Clean separation of concerns

### 🛡️ **Advanced Security Features**
- **No Bridge Dependencies**: Eliminates bridge-related vulnerabilities
- **Trustless Design**: No need for trusted third parties
- **Timeout Protection**: Automatic fund recovery mechanisms

## 🔄 How It Works

### **Step 1: Order Creation** 📝
```
👤 Maker creates swap order:
├── Source Chain: Base Sepolia
├── Offer: 100 USDC
├── Target Chain: Etherlink  
└── Want: 95 DAI
```

### **Step 2: Order Acceptance** 🤝
```
👤 Taker accepts order:
├── Generates shared secret
├── Creates cryptographic hashlock
└── Initiates escrow deployment
```

### **Step 3: Escrow Deployment & Fund Locking** 🔐
```
🏭 Factory Contracts Deploy:
├── Base Sepolia Escrow
│   ├── Locks 100 USDC
│   ├── Hashlock: 0xabc123...
│   └── Timelock: 24 hours
└── Etherlink Escrow
    ├── Locks 95 DAI
    ├── Same Hashlock: 0xabc123...
    └── Timelock: 12 hours
```

### **Step 4: Atomic Settlement** ⚡
```
🔓 Settlement Process:
├── Taker reveals secret on Etherlink → Claims 95 DAI
├── Secret becomes public on blockchain
├── Maker uses revealed secret on Base → Claims 100 USDC
└── ✅ Swap Complete!

⏰ Fallback: If timeout expires → Both parties reclaim funds
```

## 🛠️ Technical Stack

### **Smart Contracts** 📋
- **Language**: Solidity ^0.8.0
- **Framework**: Foundry
- **Pattern**: Factory + Implementation contracts
- **Security**: Hashlock + Timelock mechanisms

### **Integration Layer** 🔌
- **Cross-Chain SDK**: 1inch Cross-Chain SDK
- **Blockchain Interaction**: Ethers.js
- **Language**: TypeScript
- **Package Manager**: PNPM

### **Supported Networks** 🌐
| Network | Type | RPC | Factory Contract |
|---------|------|-----|------------------|
| Base Sepolia | L2 Testnet | Custom RPC | `0x...` |
| Etherlink | Tezos-based | Custom RPC | `0x...` |

## 🚀 Quick Start

### **Prerequisites** 📋
```bash
# Required tools
- Node.js v18+
- PNPM
- Foundry
- Git
```

### **Installation** 💻
```bash
# Clone the repository
git clone https://github.com/Shashwat-Nautiyal/-Fusion.git
cd Fusion

# Install dependencies
pnpm install

# Install Foundry dependencies
forge install
```

### **Environment Setup** 🔧
Create a `.env` file:
```env
# Network RPCs
BASE_SEPOLIA_RPC=your_base_sepolia_rpc_url
ETHERLINK_RPC=your_etherlink_rpc_url

# Private Keys (for testing only!)
PRIVATE_KEY_1=your_test_private_key_1
PRIVATE_KEY_2=your_test_private_key_2

# Factory Contract Addresses
BASE_FACTORY_ADDRESS=0x...
ETHERLINK_FACTORY_ADDRESS=0x...
```

### **Build & Test** 🧪
```bash
# Compile contracts
forge build

# Run comprehensive test suite
pnpm test

# Run specific test
forge test -vvv
```

## 📊 Contract Architecture

### **Factory Contracts** 🏭
```solidity
contract EscrowFactory {
    function createEscrow(
        bytes32 hashlock,
        uint256 timelock,
        address recipient,
        uint256 amount
    ) external returns (address escrow);
}
```

### **Escrow Implementation** 🔐
```solidity
contract Escrow {
    // Hashlock: Cryptographic security
    bytes32 public hashlock;
    
    // Timelock: Time-based safety
    uint256 public timelock;
    
    // Claim with secret
    function claim(string calldata secret) external;
    
    // Reclaim after timeout
    function reclaim() external;
}
```

## 🔐 Security Model

### **Hashlock Security** 🛡️
- **One-way Function**: SHA-256 ensures secret cannot be reverse-engineered
- **Atomic Revelation**: Secret revealed on one chain enables claim on other
- **Cryptographic Proof**: Mathematical guarantee of authenticity

### **Timelock Safety** ⏰
- **Asymmetric Timeouts**: Different expiration times prevent deadlocks
- **Automatic Recovery**: Funds automatically recoverable after timeout
- **Fail-Safe Design**: System defaults to returning funds to owners

### **Economic Incentives** 💰
- **Completion Reward**: Both parties benefit from successful completion
- **Time Pressure**: Earlier timeout encourages prompt execution
- **Risk Mitigation**: No permanent fund loss possible

## 🧪 Testing Framework

### **Comprehensive Test Suite** ✅
```bash
tests/
├── unit/
│   ├── EscrowFactory.t.sol      # Factory functionality
│   ├── Escrow.t.sol             # Individual escrow logic
│   └── Hashlock.t.sol           # Cryptographic primitives
├── integration/
│   ├── CrossChainSwap.t.sol     # End-to-end swap flows
│   └── TimeoutScenarios.t.sol   # Edge case handling
└── e2e/
    └── FullSwapCycle.t.sol      # Complete user journey
```

### **Test Coverage** 📈
- ✅ **Happy Path**: Successful swap completion
- ✅ **Timeout Scenarios**: Fund recovery mechanisms
- ✅ **Invalid Secrets**: Security boundary testing
- ✅ **Cross-Chain Coordination**: Network interaction verification

## 🌍 Use Cases

### **DeFi Protocols** 💱
- **DEX Integration**: Enable cross-chain trading pairs
- **Liquidity Bridging**: Move assets between ecosystems
- **Yield Farming**: Access opportunities across chains

### **Individual Traders** 👤
- **Portfolio Rebalancing**: Move assets without centralized risk
- **Arbitrage Opportunities**: Exploit price differences across chains
- **Ecosystem Migration**: Transfer holdings between preferred networks

### **Developers** 👨💻
- **dApp Integration**: Build cross-chain functionality
- **Research Platform**: Study atomic swap mechanisms
- **Infrastructure Building**: Create trustless bridge alternatives

## ⚠️ Important Disclaimers

### **Testnet Only** 🧪
- **Current Status**: Proof-of-concept on testnets
- **Not Production Ready**: Requires security audits
- **Educational Purpose**: Designed for learning and testing

### **Risk Considerations** ⚠️
- **Smart Contract Risk**: Potential bugs in contract logic
- **Network Risk**: Testnet instability
- **Key Management**: Secure private key handling required

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### **Development Workflow** 🔄
1. 🍴 Fork the repository
2. 🌿 Create feature branch (`git checkout -b feature/amazing-feature`)
3. 💾 Commit changes (`git commit -m 'Add amazing feature'`)
4. 📤 Push to branch (`git push origin feature/amazing-feature`)
5. 🔄 Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **1inch Network**: Cross-chain SDK integration
- **Foundry Team**: Development framework
- **Base**: Testnet infrastructure
- **Tezos**: Etherlink blockchain support

## 📞 Contact & Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/Shashwat-Nautiyal/-Fusion/issues)
- **Discussions**: [Join community discussions](https://github.com/Shashwat-Nautiyal/-Fusion/discussions)

⭐ **Star this repository if you find it useful!** ⭐

