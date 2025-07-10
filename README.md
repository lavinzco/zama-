# 🛡️ PrivateQnA - FHE-Powered Anonymous Question & Answer with ERC20 Reward & Arbitration

> A Solidity-based decentralized Q&A protocol enabling users to send encrypted questions, reward responders with ERC20 tokens, and resolve disputes via on-chain arbitration.

## ✨ Features

- 🔐 **FHEVM-based Encrypted Messaging** (via Zama FHE)
- 🎁 **ERC20 Token Incentivized Questions**
- 🤝 **Anonymous Random Recipient Matching**
- 📩 **Responder Can Reply without Knowing Asker Identity**
- ⚖️ **Dispute Resolution via Neutral Arbitrator**
- 🧠 **Homomorphic Encryption Compatible**

---

## 📁 Project Structure

```
/contracts
  ├─ PrivateQnA.sol       # Main FHE Q&A Contract
  ├─ ERC20Mock.sol        # Minimal ERC20 token for testing

/test
  └─ PrivateQnA.test.ts   # Hardhat test suite
```

---

## 🚀 Getting Started

### 🔧 Install Dependencies

```bash
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npm install @openzeppelin/contracts @fhevm/solidity
```

### ⚒️ Compile Contracts

```bash
npx hardhat compile
```

---

## 🧪 Run Tests

Ensure `ERC20Mock.sol` and `PrivateQnA.sol` are present, then:

```bash
npx hardhat test
```

You should see output confirming:
- Successful ERC20 transfers
- Correct reward splitting
- Dispute flow execution

---

## 📜 Contract API Summary

### Ask a Question (with Token Reward)
```solidity
function askQuestionWithReward(
  string calldata encryptedQuestion,
  IERC20 token,
  uint256 amount
) external;
```

### Randomly Offer Question to Another User
```solidity
function tryDeliverQuestion(uint questionId, externalEuint32 salt, bytes calldata proof) external;
```

### Accept the Offered Question
```solidity
function acceptQuestion(uint questionId) external;
```

### Submit an Encrypted Reply
```solidity
function replyToQuestion(uint questionId, string calldata encryptedReply) external;
```

### File a Dispute (Asker only)
```solidity
function fileDispute(uint questionId) external;
```

### Arbitrate a Dispute (3rd party only)
```solidity
function arbitrateDispute(uint questionId, bool ruleInFavorOfAsker) external;
```

---

## 🧠 Notes

- Encrypted strings (question/reply) are expected to be processed via Zama FHE SDK off-chain
- The contract supports FHE `externalEuint32` input, verified via ZK Proof
- The arbitrator must **not** be the original asker or responder

---

## 📦 Future Work

- ✅ Frontend integration with Zama FHE SDK
- ✅ DAO-based arbitration (instead of single C)
- ✅ Question expiry and refund window
- ✅ NFT reward instead of ERC20

---

## 🔗 References

- Zama FHEVM Docs: https://docs.zama.ai/fhevm
- OpenZeppelin Contracts: https://github.com/OpenZeppelin/openzeppelin-contracts

---

## 👨‍💻 Author
Built by [YourName] using Zama FHEVM + Hardhat
