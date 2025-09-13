// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {AgriChain} from "../src/AgriChain.sol";
import {Stakeholder} from "../src/Stakeholder.sol";
import {ProductManager} from "../src/ProductManager.sol";

contract Interactions is Script {
    AgriChain agriChain;
    Stakeholder stakeholder;
    ProductManager productManager;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();
    }

    //====================Batch Operations=====================
}