const truffleAssert = require('truffle-assertions');
const FlightSuretyData = artifacts.require("FlightSuretyData");
const FlightSuretyApp = artifacts.require("FlightSuretyApp");

describe('Oracle Tests', () => {
    const default_gas = 9500000;
    const default_oracle_fee = web3.utils.toWei("1");
    const default_minimum_funding = web3.utils.toWei("10");
    const default_initial_airline_name = "INITIAL_TEST_FLIGHT";
    const default_initial_flight = "FIRST_TEST_FLIGHT";
    const default_minimum_oracles = 30;

    let accounts;

    let owner;
    let dataContract;
    let appContract;

    contract('Oracle Tests', async (acc) => {
        accounts = acc;
        owner = accounts[0];
    });
    
    before(async () => {
        dataContract = await FlightSuretyData.new(default_initial_airline_name, { from: owner, value: default_minimum_funding, gas: default_gas });
        appContract = await FlightSuretyApp.new(dataContract.address, { from: owner, gas: default_gas });
        await dataContract.wireApp.sendTransaction(appContract.address, { from: owner });
    });

    it('oracles can register', async () => {
        let oracleCount = 0;
        const registrations = [];
        while (oracleCount < default_minimum_oracles) {
            const currentOracle = accounts[oracleCount];
            registrations.push(appContract.registerOracle.sendTransaction({ from: currentOracle, value: default_oracle_fee }));
            oracleCount+=1;
        }
        await Promise.all(registrations).then(txs => {
            for (let index = 0; index < txs.length; index++) {
                const tx = txs[index];
                truffleAssert.eventEmitted(tx, 'OracleRegistered');
            }
        });
    });
});