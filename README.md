# Vault: Bitcoin-Inspired DeFi Protocol

A minimalist, secure DeFi protocol built on Stacks blockchain using Clarity smart contracts. The protocol focuses on providing essential DeFi functionality while maintaining Bitcoin's principles of simplicity and security.

## Features

- **Secure Asset Vault**: Store and manage digital assets with Bitcoin-level security
- **Liquidity Pools**: Provide liquidity and earn fees from token swaps
- **Token Swaps**: Efficient token exchanges with minimal price impact
- **Exchange Rate Oracle**: Real-time token pair exchange rate calculations
- **Dynamic Liquidity Management**: Add and remove liquidity with proportional returns
- **Low Fee Structure**: Competitive 0.5% base fee for all operations
- **Transparent Logic**: All smart contract code is readable and verifiable

## Technical Architecture

### Smart Contracts

The protocol consists of the following core components:

1. **Vault Contract**: Manages deposits, withdrawals, and access control
2. **Liquidity Pool**: Handles token pair pools and swap operations
3. **Exchange Rate Oracle**: Provides accurate token pair pricing
4. **Fee Distribution**: Manages protocol fees and distribution

### Key Functions

- `deposit`: Deposit assets into the vault
- `withdraw`: Withdraw assets from the vault
- `add-liquidity`: Provide liquidity to token pairs
- `remove-liquidity`: Withdraw liquidity with proportional returns
- `swap`: Execute token swaps with optimal pricing
- `get-exchange-rate`: Calculate current exchange rates for token pairs
- `calculate-swap-output`: Calculate token swap outputs with fees
- `set-protocol-fee`: Admin function to adjust protocol fees

## Security Features

- Immutable contract logic
- Access control mechanisms
- Balance checks and validations
- Liquidity proportion validation
- Share-based liquidity tracking
- Reentrancy protection
- Arithmetic overflow protection (built into Clarity)

## Getting Started

### Prerequisites

- Stacks wallet
- STX tokens for transaction fees
- Supported tokens for liquidity provision

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/vault.git
cd vault
```

2. Install dependencies:
```bash
clarinet install
```

3. Run tests:
```bash
clarinet test
```

### Usage Examples

#### Depositing Assets
```clarity
(contract-call? .vault deposit u1000000)
```

#### Adding Liquidity
```clarity
(contract-call? .vault add-liquidity token-x token-y u1000000 u1000000)
```

#### Removing Liquidity
```clarity
(contract-call? .vault remove-liquidity token-x token-y u500000)
```

#### Checking Exchange Rates
```clarity
(contract-call? .vault get-exchange-rate token-x-principal token-y-principal u1000000)
```

## Protocol Parameters

- Minimum deposit: None
- Protocol fee: 0.5%
- Maximum fee: 10%
- Supported tokens: STX and SIP-010 compliant tokens
- Minimum liquidity: Dynamic based on pool size

## Advanced Features

### Liquidity Pool Mathematics

The protocol uses constant product market maker (CPMM) mathematics:
- Pool invariant: x * y = k
- Swap pricing: dy = y * dx / (x + dx)
- Liquidity shares: proportional to contributed assets

### Exchange Rate Calculation

Exchange rates are calculated using:
- Current pool reserves
- Protocol fees
- Minimum output guarantees

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Testing

The protocol includes comprehensive test coverage:

```bash
clarinet test
```

Test coverage includes:
- Core functionality
- Edge cases
- Security scenarios
- Fee calculations
- Liquidity management

## Security Considerations

- All smart contracts have been designed with security-first principles
- Formal verification is recommended before mainnet deployment
- Regular security audits should be conducted
- Liquidity providers should understand impermanent loss risks

## Future Enhancements

Planned features:
- Multi-token pools
- Flash loan protection
- Governance mechanism
- Yield farming rewards
- Advanced fee distribution models

## Acknowledgments

- Bitcoin whitepaper
- Clarity language documentation
- Stacks blockchain community
- Uniswap v2 mathematical formulas