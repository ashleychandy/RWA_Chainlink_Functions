//SPDX-License-Identifier:MIT

pragma solidity ^0.8.28;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

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

    enum MintOrRedeem {
        mint,
        redeem
    }

    struct dTslaRequest {
        uint256 amountofTokens;
        address requester;
        MintOrRedeem mintOrRedeem;
    }

    struct Funds {
        uint256 amountOfUsdc;
        uint256 amountOfDTsla;
    }

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
    uint64 donHostedSecretsVersion = 1752534582;

    //s_ ~ storage
    string private s_buySourceCode;
    string private s_redeemSourceCode;
    uint256 private s_portfolioBalance;
    bytes32 private currentRequestId;
    uint256 s_totalMintedTokens;

    bool issue = false;

    address Owner = owner();

    mapping(bytes32 requestId => MintOrRedeem mintOrRedeem) private s_requestIdToMintOrRedeem;

    mapping(address user => Funds funds) private s_userToFunds;
    mapping(bytes32 requestId => address user) private s_requestIdToUser;

    constructor(string memory redeemSourceCode, uint64 subId, address usdcAddr)
        ConfirmedOwner(msg.sender)
        FunctionsClient(Arbitrum_Functions_Router)
        ERC20("dTSLA", "dTSLA")
    {
        //
        s_redeemSourceCode = redeemSourceCode;
        i_subId = subId;
        TEST_USDC = usdcAddr;
    }

    ///check broker acc if TSLA stock is present
    ///if present then mint equivalent amt of stocks as dTSLA

    function sendBuyRequest(uint256 amountOfTslaToBuy) external returns (bytes32) {
        uint256 amountOfUsdcForDTsla = getUsdcValueOfTsla(amountOfTslaToBuy);

        if ((s_userToFunds[msg.sender].amountOfUsdc) < amountOfUsdcForDTsla) {
            revert dTSLA__NotEnoughUsdc();
        }

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_buySourceCode);
        req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);

        string[] memory args = new string[](2);
        args[0] = amountOfTslaToBuy.toString(); //to broker sell x amt of tsla
        args[1] = "buy";
        req.setArgs(args);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, DON_ID); // CBOR encoding language which the Chainlink nodes understand
        currentRequestId = requestId;
        s_requestIdToMintOrRedeem[currentRequestId] = MintOrRedeem.mint;
        s_requestIdToUser[currentRequestId] = msg.sender;
        s_userToFunds[msg.sender].amountOfUsdc -= amountOfUsdcForDTsla;
        return currentRequestId;
    }

    function _buyFulfillRequest(bytes memory response) internal {
        uint256 tslaToMint = uint256(bytes32(response));

        if (tslaToMint == 0) {
            issue = true;
        }

        address user = s_requestIdToUser[currentRequestId];
        s_userToFunds[user].amountOfDTsla += tslaToMint;
    }

    /// For users to (sell)dTSLA for usdc
    /// sell TSLA on broker acc and buy usdc

    function sendRedeemRequest(uint256 amountdTsla) external {
        uint256 amountTslaInUsdc = getUsdcValueOfTsla(amountdTsla);

        if (amountTslaInUsdc < MINIMUM_WITHDRAWL_AMOUNT) {
            revert dTSLA__DoesntMeetMinimumWithdrwalAmount();
        }
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSourceCode);

        //send paramaeter of amountdTsla to the script
        string[] memory args = new string[](2);
        args[0] = amountdTsla.toString(); //to broker sell x amt of tsla
        args[1] = amountTslaInUsdc.toString(); //to send usdc to the contract
        req.setArgs(args);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, DON_ID);

        _burn(msg.sender, amountdTsla);
    }

    // function _redeemFulfillRequest(bytes32 requestId, bytes memory response) internal {
    //     uint256 usdcAmount = uint256(bytes32(response));
    // }

    //ROUTING

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /*err*/ ) internal override {
        if (s_requestIdToMintOrRedeem[requestId] == MintOrRedeem.mint) {
            _buyFulfillRequest(response);
        } else {
            // _redeemFulfillRequest(requestId, response);
        }
    }

    //FUNDING

    function sendDTslaToContract(uint256 amount) external {
        if ((balanceOf(msg.sender)) < amount) {
            revert fund__NotEnoughDTsla();
        }
        bool succ = transferFrom(msg.sender, address(this), amount);
        if (!succ) revert fund__TransferFailed();
        s_userToFunds[msg.sender].amountOfDTsla += amount;
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

        s_userToFunds[msg.sender].amountOfUsdc += amountOfUsdc;
    }

    function withdrawDTsla(uint256 amountToWithdraw) external {
        if ((s_userToFunds[msg.sender].amountOfDTsla) < amountToWithdraw) {
            revert fund__NotEnoughDTsla();
        }
        s_userToFunds[msg.sender].amountOfDTsla -= amountToWithdraw;
        _mint(msg.sender, amountToWithdraw);
    }

    function withdrawUsdc(uint256 amountToWithdraw) external {
        if ((s_userToFunds[msg.sender].amountOfUsdc) < amountToWithdraw) {
            revert fund__NotEnoughUsdc();
        }

        bool succ = ERC20(TEST_USDC).transfer(msg.sender, amountToWithdraw);
        if (!succ) {
            revert dTSLA__TransferFailed();
        }
        s_userToFunds[msg.sender].amountOfUsdc -= amountToWithdraw;
    }

    //SETTER FUNCTIONS

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

    function getIssue() public view returns (bool) {
        return issue;
    }

    function getDtslaBalance(address user) public view returns (uint256) {
        return s_userToFunds[user].amountOfDTsla;
    }

    function getUsdcBalance(address user) public view returns (uint256) {
        return s_userToFunds[user].amountOfUsdc;
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

    function getRedeemSourceCode() public view returns (string memory) {
        return s_redeemSourceCode;
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
