//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DataStructures} from "./DataStructures.sol";
import {IAgriChainEvents} from "./IAgriChainEvents.sol";
import {StakeholderManager} from "./StakeholderManager.sol";

contract ProductManager is Pausable,AccessControl,IAgriChainEvents,ReentrancyGuard {
    //Role Definitions
    bytes32 constant ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant FARMER_ROLE = 0x9decc540ed7e12dc756a0a33fd30896853d6f3395609286d2d83d03db68fbac9;
    bytes32 constant DISTRIBUTOR_ROLE = 0x7722e3dbdf7a5417dd23d582ff681776bb661e10ab9355388e1d977817a7a1b5;
    bytes32 constant RETAILER_ROLE = 0xc3ca1c550e48f508639854b12b070ee6611457a1fe9df69a92864114bfc0e5cf;
    bytes32 constant INSPECTOR_ROLE = 0x52d54c20deb3c9c90c1e2b1d66f2c5b1c2c839c7563acb76f7b6cc33fcfea88d;

    struct SystemConfig {
        uint32 maxProductPerFarmer;
        uint32 maxTransactionPerProduct;
        uint32 minQualityScore;
        uint32 currentProduceId;
    }
    SystemConfig public systemConfig;

    //core storage
    mapping(uint256 => DataStructures.Product) public products;
    mapping(uint256 => DataStructures.Transaction[]) public productTransactions;

    // Optimized Tracking Mappings
    mapping(bytes32 => bool) public usedTransactionHashes;
    mapping(string => uint256[]) public productByCategory;
    mapping(address => uint256[]) public productsByOwner;

    // Packed arrays for enumeration (gas optimization)
    uint256[] public allProductsIds;
    string[] public allCategories;
    mapping(string => bool) public categoryExists;

    // Reference contracts
    StakeholderManager public immutable stakeholderManager;

    //Emergency Control
    mapping(uint256 => bool) public blockedProducts;
    mapping(address => bool) public blockedUsers;

    //Custom Errors
    error StakeholderNotVerified();
    error UserBlocked();
    error InvalidInputData();

    constructor(address _stakeholderManager) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        stakeholderManager = StakeholderManager(_stakeholderManager);

        systemConfig = SystemConfig({
            maxProductPerFarmer: 1000,
            maxTransactionPerProduct: 100,
            minQualityScore: 0,
            currentProduceId: 0
        });
    }

    //Modifiers
    modifier onlyVerifiedStakeholder() {
        if (!stakeholderManager.isStakeholderVerified(msg.sender)) {
            revert StakeholderNotVerified();
        }
        _;
    }

    modifier userNotBlocked() {
        if (blockedUsers[msg.sender]) {
            revert UserBlocked();
        }
        _;
    }

    //===================PRODUCT CREATION=======================

    function createProduct(DataStructures.ProductCreationData memory _data
    ) external whenNotPaused onlyRole(FARMER_ROLE)
               onlyVerifiedStakeholder
               userNotBlocked returns (uint256) {

        if (bytes(_data.name).length == 0 || bytes(_data.category).length == 0) {
            revert InvalidInputData();
        }
        if(_data.quantity == 0 || _data.farmGatePrice == 0) {
            revert InvalidInputData();
        }
        if (_data.plantedDate > block.timestamp || _data.expiryDate <= _data.harvestDate) {
            revert InvalidInputData();
        }
        
        uint256 newProductId;
        unchecked {
            systemConfig.currentProduceId++;
            newProductId = systemConfig.currentProduceId;
        }

        //Farmer Location
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(msg.sender);
        string memory farmName = farmer.farmName;
        DataStructures.Location memory farmLocation = farmer.farmLocation;

        //Create Product struct in Memory then copy to storage
        DataStructures.Product memory newProduct = DataStructures.Product ({
            id: newProductId,
            name: _data.name,
            varitey: _data.variety,
            category: _data.category,
            quantity: uint128(_data.quantity),
            plantedDate: uint64(_data.plantedDate),
            harvestDate: 0,
            expiryDate: uint64(_data.expiryDate),
            lastUpdated: uint64(block.timestamp),
            unit: _data.unit,
            farmer: msg.sender,
            farmLocation: farmLocation,
            currentLocation: farmLocation,
            qualityRecords: new DataStructures.Quality[](0),
            certifications: _data.certifications,
            pricing: DataStructures.Price({
                farmGatePrice: uint128(_data.farmGatePrice),
                distributorPrice: 0,
                retailerPrice: 0,
                recommendedRetailPrice: 0,
                currency: bytes3("INR"),
                lastUpdated: uint64(block.timestamp)
            }),
            practices: _data.practices,
            currentStage: DataStructures.ProductStage.Planted,
            batchNumber: _generateBatchNumber(msg.sender, newProductId),
            isActive: true,
            carbonFootprint: 0,
            metadataIPFS: "",
            imagesIPFS: new string[](0)
        });
   }    

}