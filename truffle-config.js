const HDWalletProvider = require('@truffle/hdwallet-provider');
const { mnemonic, infuraKey } = require('./constants');


module.exports = {
    networks: {
        development: {
            host: '127.0.0.1',
            port: 8545,
            network_id: '*'
        },
        rinkeby: {
            provider: () => new HDWalletProvider(mnemonic, infuraKey),
            network_id: 4,
            gas: 8500000,
            gasPrice: 10000000000,
            type: 'quorum'
        }
    },
    compilers: {
        solc: {
            version: '^0.6.0'
        }
    },
    mocha: {
        enableTimeouts: false
    }
};