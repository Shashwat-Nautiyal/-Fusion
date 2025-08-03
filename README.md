# 🔁 Fusion+ Cross-Chain Escrow Swaps (Base Sepolia ↔ Etherlink)

🚀 A minimal proof-of-concept for atomic, trustless swaps across different testnets using escrows and the 1inch cross-chain SDK.

 This project enables token swaps between Base Sepolia and Etherlink testnets without relying on a single bridging mechanism or external sequencers. Swaps are settled using smart contract escrows, secured by hashlocks and timelocks, and executed using the 1inch SDK.

---

## ✨ Features

- ⛓️ Trustless swaps between Base Sepolia & Etherlink testnets
- 🔐 Escrow contracts on both chains with onchain hashlock + timelock settlement
- ⚡ Uses 1inch cross-chain SDK for order routing and relayer abstraction
- 🧪 Complete end-to-end test suite for swap flows across both chains

---

## 🧠 How It Works

1. **Maker creates an order** specifying:
   - Source chain, destination chain
   - Token & amount offered
   - Token & amount expected in return

2. **Taker accepts the order** using a shared secret, generating a hashlock.

3. The system:
   - 🏗 Deploys source & destination escrows via factory contracts
   - ⛓ Locks funds with hashlock & timelock
   - ✅ On destination chain, taker claims tokens by revealing the secret
   - 🔁 On source chain, maker uses the revealed secret to claim the counter tokens

4. If timeout expires, escrows can be reclaimed by their creators using the timelock mechanism.

---

## 🧰 Tech Stack

- ⚙️ Foundry (Solidity)
- 🧪 Ethers.js (for contract interactions)
- 💻 TypeScript for scripting/tests
- 🌉 1inch Cross-Chain SDK
- 🌐 Base Sepolia + Etherlink testnets

---

## 🛠️ Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/your-username/fusion-plus-crosschain-escrow.git
cd fusion-plus-crosschain-escrow
pnpm install
````

Set up your environment variables:

```bash
cp .env.example .env
# Then edit .env with your RPC URLs, private key, and factory addresses
```

---

## 🔐 .env Configuration

Create a .env file with the following:

```env
BASE_SEPOLIA_RPC=https://...
ETHERLINK_RPC=https://...
PRIVATE_KEY=your_private_key
ESCROW_FACTORY_BASE=0xabcSRC...
ESCROW_FACTORY_ETHERLINK=0xabcDST...
```

---

## 🧪 Run Tests

Run all cross-chain tests with:

```bash
pnpm test
```

You can also run individual test files (e.g. main.spec.ts).

---

## 📦 Build Contracts

Compile contracts using:

```bash
forge build
```

---

## 📎 Notes

* The factories for Base Sepolia and Etherlink have different addresses. The tests and deployment logic respect this and fetch addresses from the .env file.
* Escrow implementation contracts (SRC and DST) are deployed and referenced via the factory.

---

## 🏁 Status

✅ Working prototype for hashlock-based swaps across Base Sepolia and Etherlink testnets using separate escrow contracts and the 1inch cross-chain SDK.

