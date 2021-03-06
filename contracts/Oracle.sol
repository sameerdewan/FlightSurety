// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "./Interfaces/DataInterface.sol";
import "./Interfaces/AppInterface.sol";

contract Oracle {
    using SafeMath for uint256;

    address public OWNER_ADDRESS;

    address public ORACLE_ADDRESS;
    bool public ORACLE_OPERATIONAL = false;

    DataInterface DATA;
    address public DATA_ADDRESS;
    bool public DATA_OPERATIONAL = false;

    AppInterface APP;
    address public APP_ADDRESS;
    bool public APP_OPERATIONAL = false;

    uint256 public MIN_RESPONSES = 3;
    uint8 private NONCE;
    mapping(address => ORACLE) public ORACLES;
    mapping(bytes32 => ORACLE_RESPONSE) public ORACLE_RESPONSES;

    struct ORACLE {
        uint8 INDEX_0;
        uint8 INDEX_1;
        uint8 INDEX_2;
        bool VALID;
        string NAME;
    }

    struct RESPONDER {
        bool RESPONDED;
    }

    struct ORACLE_RESPONSE {
        address REQUEST_ORIGIN;
        bool OPEN;
        mapping(address => RESPONDER) RESPONDERS;
        mapping(string => address[]) RESPONSES;
    }

    event DATA_CONTRACT_REGISTERED();
    event ORACLE_CONTRACT_OPERATIONAL();
    event ORACLE_REGISTERED(address oracle);
    event ORACLE_REQUEST(uint8 oracleIndex, uint256 oracleTimestamp, string airlineName, string flightName, string indexed airlineNameHashed, string indexed flightNameHashed);

    constructor() public {
        OWNER_ADDRESS = msg.sender;
        ORACLE_ADDRESS = address(this);
    }

    modifier isOwner() {
        require(msg.sender == OWNER_ADDRESS, 'Error: Only the OWNER can access this function.');
        _;
    }

    modifier isAppContract() {
        require(msg.sender == APP_ADDRESS, 'Error: Only the APP CONTRACT can access this function.');
        _;
    }

    modifier isOperational() {
        require(ORACLE_OPERATIONAL == true, 'Error: ORACLE CONTRACT is not operational.');
        _;
    }

    function setOracleOperational() external 
        isOwner() {
            require(DATA_OPERATIONAL == true, 'Error: Error: DATA CONTRACT is not operational.');
            require(APP_OPERATIONAL == true, 'Error: Error: APP CONTRACT is not operational.');
            ORACLE_OPERATIONAL = true;
            emit ORACLE_CONTRACT_OPERATIONAL();
    }

    function registerAppContract(address appContractAddress) external {
        require(tx.origin == OWNER_ADDRESS, 'Error: tx.origin is not OWNER.');
        APP_ADDRESS = appContractAddress;
        APP = AppInterface(appContractAddress);
        APP_OPERATIONAL = true;
    }

    function registerDataContract(address dataContractAddress) external 
        isOwner() {
            DATA_ADDRESS = dataContractAddress;
            DATA = DataInterface(dataContractAddress);
            DATA_OPERATIONAL = true;
            emit DATA_CONTRACT_REGISTERED();
    }

    function generateIndexes(address account) public returns(uint8, uint8, uint8) {
        uint8 index0 = getRandomIndex(account);
        uint8 index1 = index0;
        while(index1 == index0) {
            index1 = getRandomIndex(account);
        }
        uint8 index2 = index1;
        while(index2 == index1 || index2 == index0) {
            index2 = getRandomIndex(account);
        }
        return (index0, index1, index2);
    }

    function getRandomIndex(address account) public returns (uint8) {
        uint8 maxValue = 10;
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - NONCE++), account))) % maxValue);

        if (NONCE > 250) {
            NONCE = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    function registerOracle(address oracleAddress, string memory oracleName) external
        isAppContract() isOperational() {
            (uint8 index0, uint8 index1, uint8 index2) = generateIndexes(oracleAddress);
            ORACLES[oracleAddress] = ORACLE({
                INDEX_0: index0,
                INDEX_1: index1,
                INDEX_2: index2,
                VALID: true,
                NAME: oracleName
            });
            emit ORACLE_REGISTERED(oracleAddress);
    }

    function fireOracleFlightStatusRequest(string memory airlineName, string memory flightName) external
        isOperational() {
            (address airlineAddress, , ,) = DATA.getAirline(airlineName);
            uint256 oracleTimestamp = block.timestamp;
            uint8 oracleIndex = getRandomIndex(airlineAddress);
            bytes32 oracleKey = keccak256(abi.encodePacked(oracleIndex, oracleTimestamp, airlineName, flightName));
            ORACLE_RESPONSE memory oracleResponse = ORACLE_RESPONSE({
                REQUEST_ORIGIN: msg.sender,
                OPEN: true
            });
            ORACLE_RESPONSES[oracleKey] = oracleResponse;
            emit ORACLE_REQUEST(oracleIndex, oracleTimestamp, airlineName, flightName, airlineName, flightName);
    }

    function submitOracleResponse(uint8 oracleIndex, uint256 oracleTimestamp, string memory airlineName, string memory flightName, string memory flightStatus) external
        isOperational() {
            bool indexMatchesRequest = ORACLES[msg.sender].INDEX_0 == oracleIndex || ORACLES[msg.sender].INDEX_1 == oracleIndex || ORACLES[msg.sender].INDEX_2 == oracleIndex;
            require(indexMatchesRequest == true, 'Error: Invalid Oracle response.');
            bytes32 oracleKey = keccak256(abi.encodePacked(oracleIndex, oracleTimestamp, airlineName, flightName));
            require(ORACLE_RESPONSES[oracleKey].OPEN == true, 'Error: Oracle Request not open.');
            require(ORACLE_RESPONSES[oracleKey].RESPONDERS[msg.sender].RESPONDED == false, 'Error: Oracle already responded.');
            ORACLE_RESPONSES[oracleKey].RESPONSES[flightStatus].push(msg.sender);
            ORACLE_RESPONSES[oracleKey].RESPONDERS[msg.sender] = RESPONDER({ RESPONDED: true });
            string memory oracleName = ORACLES[msg.sender].NAME;
            APP.fireOracleResponded(oracleIndex, oracleName, airlineName, flightName, flightStatus);
            if (ORACLE_RESPONSES[oracleKey].RESPONSES[flightStatus].length >= MIN_RESPONSES) {
                DATA.updateFlight(airlineName, flightName, flightStatus);
                APP.fireFlightUpdate(airlineName, flightName, flightStatus);
            }
    }
}
