const HDWalletProvider = require('@truffle/hdwallet-provider');
const Web3 = require('web3');
const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');
const { mnemonic, infuraKey, initialAirline, initialFlight, getInitialFlightTime } = require('../constants');

module.exports = async function(deployer) {
    const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));
    const accounts = await web3.eth.getAccounts();
    owner = accounts[0];
    value = web3.utils.toWei("11");

    await deployer.deploy(FlightSuretyData, initialAirline, initialFlight, getInitialFlightTime(), {from: owner, value})
    .then(flightSuretyDataInstance => {
        return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
                .then(async flightSuretyAppInstance => {
                    let config = {
                        localhost: {
                            url: 'http://localhost:8545',
                            FlightSuretyData: {
                                address: flightSuretyDataInstance.address,
                                abi: flightSuretyDataInstance.abi
                            },
                            FlightSuretyApp: {
                                address: flightSuretyAppInstance.address,
                                abi: flightSuretyAppInstance.abi
                            }
                        }
                    };
                    await new Promise(resolve => resolve(
                        fs.writeFileSync('./client/src/deployments.json', JSON.stringify(config, null, '\t'), 'utf-8'))
                    );
                    await new Promise(resolve => resolve(
                        fs.writeFileSync('./server/deployments.json', JSON.stringify(config, null, '\t'), 'utf-8'))
                    );
                    const provider = new HDWalletProvider(mnemonic, infuraKey);
                    const web3 = new Web3(provider);
                    const { abi, address } = config.localhost.FlightSuretyData;
                    const dataContractinstance = new web3.eth.Contract(abi, address);
                    const { address: appAddress } = config.localhost.FlightSuretyApp; 
                    dataContractinstance.methods.wireApp(appAddress).call()
                        .then(() => {
                            console.log('<--WIRED APP-->');
                        }).catch(error => {
                            console.log({error});
                            console.log('!--FAILED TO WIRE APP--!');
                        });
                });
    });
}
