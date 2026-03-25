# ⚡ FlowArc — Onchain Payroll Protocol

> Stream USDC salaries per second, manage workers trustlessly, and mint soulbound payslip NFTs — all onchain on Arc Testnet.

---

## What is FlowArc?

FlowArc is a decentralized payroll protocol built on the Arc Testnet. It allows employers to register their company, deposit USDC, add workers with monthly salaries, and let workers claim their earned salary in real time — calculated per second. Every salary claim automatically mints a **soulbound Payslip NFT** as an on-chain proof of payment.

---

## Smart Contracts

### `FlowArc.sol` — Core Payroll Contract

The main contract that handles all payroll logic:

- Employers register with a company name
- Employers deposit USDC to fund payroll
- Employers add workers with monthly salary amounts (converted to per-second streaming)
- Workers claim their earned USDC at any time
- On every claim, a PayslipNFT is minted automatically

### `PayslipNFT.sol` — Soulbound Payslip NFT

An ERC-like NFT contract that:

- Mints a non-transferable (soulbound) NFT on every salary claim
- Stores the employer address, worker address, amount paid, timestamp, and company name
- Can only be minted by the FlowArc contract
- Workers can view all their payslips on-chain

---

## Tech Stack

| Layer                 | Technology                   |
| --------------------- | ---------------------------- |
| Smart Contracts       | Solidity ^0.8.30             |
| Development Framework | Foundry (Forge, Cast, Anvil) |
| Payment Token         | USDC                         |
| Network               | Arc Testnet                  |
| Testing               | Forge Test                   |

---

## Contract Addresses (Arc Testnet)

| Contract   | Address                                    |
| ---------- | ------------------------------------------ |
| FlowArc    | 0x9F3bbf462dee5A0242786fd47037F96ABa82Ad5a |
| PayslipNFT | 0x5468B8a06Bf904E7D27f75c329206B31d00d83B9 |
| USDC       | 0x3600000000000000000000000000000000000000 |

---

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) installed
- An Arc Testnet RPC URL
- A funded wallet on Arc Testnet

### Installation

```bash
git clone https://github.com/Hardycore5/flowarc.git
cd flowarc
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Deploy

```bash
forge script script/Deploy.s.sol --rpc-url <arc_testnet_rpc_url> --private-key <your_private_key> --broadcast
```

---

## How It Works

1. **Employer registers** → calls `registerEmployer("Company Name")`
2. **Employer deposits USDC** → calls `depositFunds(amount)`
3. **Employer adds worker** → calls `addWorker(workerAddress, "Name", monthlySalary)`
4. **Worker claims salary** → calls `claimSalary(employerAddress)`
   - Earned amount is calculated: `elapsed seconds × salary per second`
   - USDC is transferred to worker
   - A soulbound PayslipNFT is minted to the worker

---

## Frontend

The FlowArc frontend is available at a separate repository:

🔗 [flowarc-frontend](https://github.com/Hardycore5/flowarc-frontend) — Live at [flowarc-frontend.vercel.app](https://flowarc-frontend.vercel.app)

---

## License

MIT
