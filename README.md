# Loopbomb Marketplace

A specialized marketplace for art NFTs and digital collectibles with artist-centric features built on the Stacks blockchain using Clarity smart contracts.

## Overview

Loopbomb Marketplace is designed to empower artists and collectors in the digital art space by providing:

- **Artist-Centric Features**: Comprehensive profile management and portfolio showcasing
- **Automated Royalties**: Smart contract-based royalty payments on secondary sales
- **Art NFT Registry**: Robust cataloging and verification system for digital art pieces
- **Marketplace Functionality**: Seamless buying, selling, and trading of digital collectibles

## Smart Contracts

### 1. Art NFT Registry (`art-nft-registry`)
Registry system for cataloging and verifying art NFTs with features including:
- NFT metadata management
- Provenance tracking
- Verification status management
- Collection organization

### 2. Royalty Payment Processor (`royalty-payment-processor`)
Automated royalty payments to artists on secondary sales:
- Configurable royalty percentages
- Multi-party royalty splits
- Automatic payment distribution
- Historical royalty tracking

### 3. Artist Profile Manager (`artist-profile-manager`)
Profile management system for artists with portfolio and verification features:
- Artist profile creation and management
- Portfolio showcase functionality
- Verification system
- Social media integration

## Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) - Clarity development environment
- [Node.js](https://nodejs.org/) (v14 or higher)
- [Git](https://git-scm.com/)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/oliviaamelia1500956/loopbomb-marketplace.git
   cd loopbomb-marketplace
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Check contract syntax:
   ```bash
   clarinet check
   ```

4. Run tests:
   ```bash
   clarinet test
   ```

## Development

### Project Structure

```
loopbomb-marketplace/
├── contracts/           # Clarity smart contracts
│   ├── art-nft-registry.clar
│   ├── royalty-payment-processor.clar
│   └── artist-profile-manager.clar
├── tests/              # Contract tests
├── settings/           # Network configurations
├── Clarinet.toml       # Project configuration
└── README.md          # This file
```

### Testing

Run the test suite:
```bash
clarinet test
```

Run tests with coverage:
```bash
clarinet test --coverage
```

### Deployment

#### Testnet Deployment
```bash
clarinet deploy --testnet
```

#### Mainnet Deployment
```bash
clarinet deploy --mainnet
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Roadmap

- [ ] Complete core smart contracts
- [ ] Comprehensive testing suite
- [ ] Frontend marketplace interface
- [ ] Mobile application
- [ ] Advanced analytics dashboard
- [ ] Multi-chain support

## Support

For questions and support, please open an issue in the GitHub repository or contact the development team.

## Acknowledgments

- Built with [Clarinet](https://docs.hiro.so/clarinet) and [Clarity](https://clarity-lang.org/)
- Powered by the [Stacks](https://www.stacks.co/) blockchain
- Inspired by the growing digital art community