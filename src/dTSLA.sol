//SPDX-License-Identifier:MIT

pragma solidity ^0.8.28;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract dTSLA is ConfirmedOwner, FunctionsClient, ERC20 {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    //ERRORS
    error dTSLA__NotEnoughCollateral();
    error dTSLA__DoesntMeetMinimumWithdrwalAmount();
    error dTSLA__TransferFailed();
    error dTSLA__NotEnoughUsdc();

    error fund__NotEnoughUsdc();
    error fund__NotEnoughDTsla();
    error fund__NotApproved();
    error fund__TransferFailed();

    struct userReq {
        address user;
        uint256 amountOfUsdcReq;
        uint256 amountOfDTslaReq;
    }

    struct userStats {
        // bytes32 requestId;
        uint8 side;
        uint256 amountOfUsdc;
        uint256 amountOfDTsla;
        uint256 orderId;
    }

    /*SIDE
    0: NULL
    1: BUY
    2: SELL
    3: TRANSFER
    */

    //Math Constants
    uint256 constant PRECISION = 1e18;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;

    uint256 constant COLLATERAL_RATIO = 100; // 100% of TSLA stock should be held, to mint $100 worth of dTSLA, $200 of TSLA should be in custodial
    uint256 constant COLLATERAL_PRECISION = 100; //
    uint256 constant MINIMUM_WITHDRAWL_AMOUNT = 100e18;
    // $100 min and USDC 6 decimals -> 18 decimals

    address constant Arbitrum_TESLA_PRICE_FEED = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298; // LINK/USD for demo
    address constant Arbitrum_Functions_Router = 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
    address constant Arbitrum_USDC_PRICE_FEED = 0x0153002d20B96532C639313c2d54c3dA09109309;
    address TEST_USDC;

    uint64 immutable i_subId;
    uint32 constant GAS_LIMIT = 300_000;
    bytes32 constant DON_ID = hex"66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000";
    uint8 donHostedSecretsSlotID = 0;
    uint64 donHostedSecretsVersion = 1752710311;

    //s_ ~ storage
    string private s_buySourceCode;
    string private s_sellSourceCode;
    uint256 private s_portfolioBalance;
    bytes32 private currentRequestId;
    uint256 s_totalMintedTokens;

    bool issue = false;

    address Owner = owner();

    //MAPPING

    mapping(address user => userStats userstats) private s_userToUserStats;
    mapping(bytes32 requestId => userReq userreq) private s_requestIdToUserReq;

    constructor(uint64 subId, address usdcAddr)
        ConfirmedOwner(msg.sender)
        FunctionsClient(Arbitrum_Functions_Router)
        ERC20("dTSLA", "dTSLA")
    {
        i_subId = subId;
        TEST_USDC = usdcAddr;
    }

    function sendBuyRequest(uint256 amountOfTslaToBuy) external returns (bytes32) {
        uint256 amountOfUsdcForDTsla = getUsdcValueOfTsla(amountOfTslaToBuy);

        userStats storage stats = s_userToUserStats[msg.sender];

        if ((stats.amountOfUsdc) < amountOfUsdcForDTsla) {
            revert dTSLA__NotEnoughUsdc();
        }

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_buySourceCode);
        req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);

        string[] memory args = new string[](4);
        args[0] = amountOfTslaToBuy.toString(); //to broker sell x amt of tsla
        args[1] = "buy";
        args[2] = Strings.toHexString(msg.sender);
        args[3] = (stats.orderId).toString();
        req.setArgs(args);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, DON_ID); // CBOR encoding language which the Chainlink nodes understand

        userReq storage userreq = s_requestIdToUserReq[requestId];
        userreq.user = msg.sender;
        userreq.amountOfUsdcReq = amountOfUsdcForDTsla;

        stats.side = 1;
        stats.amountOfUsdc -= amountOfUsdcForDTsla;
        stats.orderId++;
        return requestId;
    }

    function _buyFulfillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 tslaToMint = uint256(bytes32(response));
        userReq storage userreq = s_requestIdToUserReq[requestId];

        if (tslaToMint == 0) {
            //Add USDC back to the user
            s_userToUserStats[userreq.user].amountOfUsdc += userreq.amountOfUsdcReq;
        } else {
            s_userToUserStats[userreq.user].amountOfDTsla += tslaToMint;
        }

        delete s_requestIdToUserReq[requestId];
    }

    /// For users to (sell)dTSLA for usdc
    /// sell TSLA on broker acc and buy usdc

    function sendSellRequest(uint256 amountOfDTsla) external {
        userStats storage stats = s_userToUserStats[msg.sender];

        if (stats.amountOfDTsla < amountOfDTsla) {
            revert dTSLA__DoesntMeetMinimumWithdrwalAmount();
        }

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_sellSourceCode);

        //send paramaeter of amountdTsla to the script
        string[] memory args = new string[](4);
        args[0] = amountOfDTsla.toString(); //to broker sell x amt of tsla
        args[1] = "sell"; //to send usdc to the contract
        args[2] = Strings.toHexString(msg.sender);

        args[3] = (stats.orderId).toString();
        req.setArgs(args);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, DON_ID);

        userReq storage userreq = s_requestIdToUserReq[requestId];
        userreq.user = msg.sender;
        userreq.amountOfDTslaReq = amountOfDTsla;

        stats.orderId++;
        stats.side = 2;
        stats.amountOfDTsla -= amountOfDTsla;
    }

    function _sellFulfillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 dTslaAmountSold = uint256(bytes32(response));

        uint256 amountTslaInUsdc = getUsdcValueOfTsla(dTslaAmountSold);

        userReq storage userreq = s_requestIdToUserReq[requestId];

        if (dTslaAmountSold == 0) {
            s_userToUserStats[userreq.user].amountOfDTsla += userreq.amountOfDTslaReq;
        } else {
            s_userToUserStats[userreq.user].amountOfUsdc += amountTslaInUsdc;
        }

        delete s_requestIdToUserReq[requestId];
    }

    //ROUTING

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /*err*/ ) internal override {
        address user = s_requestIdToUserReq[requestId].user;
        if (s_userToUserStats[user].side == 1) {
            _buyFulfillRequest(requestId, response);
        }
        if (s_userToUserStats[user].side == 2) {
            _sellFulfillRequest(requestId, response);
        }
    }

    //FUNDING

    function sendDTslaToContract(uint256 amount) external {
        if ((balanceOf(msg.sender)) < amount) {
            revert fund__NotEnoughDTsla();
        }
        bool succ = transferFrom(msg.sender, address(this), amount);
        if (!succ) revert fund__TransferFailed();
        s_userToUserStats[msg.sender].amountOfDTsla += amount;

        _burn(msg.sender, amount);
    }

    function sendUsdcToContract(uint256 amountOfUsdc) external {
        if ((ERC20(TEST_USDC).balanceOf(msg.sender)) < amountOfUsdc) {
            revert fund__NotEnoughUsdc();
        }

        if (ERC20(TEST_USDC).allowance(msg.sender, address(this)) < amountOfUsdc) {
            revert fund__NotApproved();
        }

        bool succ = (ERC20(TEST_USDC).transferFrom(msg.sender, address(this), amountOfUsdc));

        if (!succ) {
            revert fund__TransferFailed();
        }

        s_userToUserStats[msg.sender].amountOfUsdc += amountOfUsdc;
    }

    function withdrawDTsla(uint256 amountToWithdraw) external {
        if ((s_userToUserStats[msg.sender].amountOfDTsla) < amountToWithdraw) {
            revert fund__NotEnoughDTsla();
        }
        s_userToUserStats[msg.sender].amountOfDTsla -= amountToWithdraw;
        _mint(msg.sender, amountToWithdraw);
    }

    function withdrawUsdc(uint256 amountToWithdraw) external {
        if ((s_userToUserStats[msg.sender].amountOfUsdc) < amountToWithdraw) {
            revert fund__NotEnoughUsdc();
        }

        bool succ = ERC20(TEST_USDC).transfer(msg.sender, amountToWithdraw);
        if (!succ) {
            revert dTSLA__TransferFailed();
        }
        s_userToUserStats[msg.sender].amountOfUsdc -= amountToWithdraw;
    }

    //SETTER FUNCTIONS
    function setSellSource(string memory sellSourceCode) external onlyOwner {
        s_sellSourceCode = sellSourceCode;
    }

    function setBuySource(string memory buySourceCode) external onlyOwner {
        s_buySourceCode = buySourceCode;
    }

    function setUsdcAddress(address usdcAddr) external onlyOwner {
        TEST_USDC = usdcAddr;
    }

    function setDonHostedSecretsVersion(uint64 _donHostedSecretsVersion) external onlyOwner {
        donHostedSecretsVersion = _donHostedSecretsVersion;
    }

    //VIEW FUNCTIONS

    function getDtslaBalance(address user) public view returns (uint256) {
        return s_userToUserStats[user].amountOfDTsla;
    }

    function getUsdcBalance(address user) public view returns (uint256) {
        return s_userToUserStats[user].amountOfUsdc;
    }

    function getUsdcAddress() public view returns (address) {
        return TEST_USDC;
    }

    function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal view returns (uint256) {
        uint256 calculatedNewTotalValue = getCalculatedNewTotalValue(amountOfTokensToMint);
        return (calculatedNewTotalValue * COLLATERAL_RATIO) / COLLATERAL_PRECISION;
    }

    //expected value in USD of all dTSLA tokens combined
    function getCalculatedNewTotalValue(uint256 addedNumberOfTokens) internal view returns (uint256) {
        //      (10 dtsla tokens + 5 dtsla tokens)     * 100$  = $1500 in bank account(custodian)
        return ((totalSupply() + addedNumberOfTokens) * getTslaPrice()) / PRECISION;
    }

    function getTslaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(Arbitrum_TESLA_PRICE_FEED);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION; //TSLA DEC IS 8
    }

    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(Arbitrum_USDC_PRICE_FEED);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdValueofTsla(uint256 tslaAmount) public view returns (uint256) {
        return tslaAmount * getTslaPrice() / PRECISION;
    }

    function getUsdcValueofUsd(uint256 usdAmount) public view returns (uint256) {
        return usdAmount * getUsdcPrice() / PRECISION;
    }

    function getUsdcValueOfTsla(uint256 tslaAmount) public view returns (uint256) {
        return getUsdcValueofUsd(getUsdValueofTsla(tslaAmount));
    }

    // View functions

    function getPortfolioBalance() public view returns (uint256) {
        return s_portfolioBalance;
    }

    function getSubId() public view returns (uint64) {
        return i_subId;
    }

    function getBuySourceCode() public view returns (string memory) {
        return s_buySourceCode;
    }

    function getSellSourceCode() public view returns (string memory) {
        return s_sellSourceCode;
    }

    function getCollateralRatio() public pure returns (uint256) {
        return COLLATERAL_RATIO;
    }

    function getCollateralPrecision() public pure returns (uint256) {
        return COLLATERAL_PRECISION;
    }
}

/*
ADDITIONAL_FEED_PRECISION is wrong for all
*/
