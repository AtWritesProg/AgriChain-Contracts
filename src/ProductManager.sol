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
    error ProductBlocked();
    error NotProductOwner();
    error ProductNotFound();
    error UnauthorizedStageTransition();
    error QualityScoreTooLow();
    error InsufficientReputation();

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
    modifier productExists(uint256 _productId) {
        if (!products[_productId].isActive) revert ProductNotFound();
        _;
    }

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

    modifier canParticipateInTransactions() {
        if (!stakeholderManager.canParticipateInTransactions(msg.sender)) {
            revert InsufficientReputation();
        }
        _;
    }

    modifier productNotBlocked(uint256 _productId) {
        if(blockedProducts[_productId]) revert ProductBlocked();
        _;
    }

    modifier onlyProductOwner(uint256 _productId) {
        if (products[_productId].currentOwner != msg.sender) revert NotProductOwner();
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
        DataStructures.Location memory farmLocation = farmer.farmLocation;

        //Create Product struct in Memory then copy to storage
        DataStructures.Product memory newProduct = DataStructures.Product ({
            id: newProductId,
            name: _data.name,
            variety: _data.variety,
            category: _data.category,
            quantity: uint128(_data.quantity),
            plantedDate: uint64(_data.plantedDate),
            harvestDate: 0,
            expiryDate: uint64(_data.expiryDate),
            lastUpdated: uint64(block.timestamp),
            unit: _data.unit,
            farmer: msg.sender,
            currentOwner: msg.sender,
            farmLocation: farmLocation,
            currentLocation: farmLocation,
            qualityHistory: new DataStructures.Quality[](0),
            certificationType: _data.certificationType,
            price: DataStructures.Price({
                farmGatePrice: uint128(_data.farmGatePrice),
                distributorPrice: 0,
                retailerPrice: 0,
                recommendedRetailPrice: 0,
                currency: bytes3("INR"),
                lastUpdated: uint64(block.timestamp)
            }),
            practices: _data.practices,
            stage: DataStructures.ProductStage.Planted,
            batchNumber: _generateBatchNumber(msg.sender, newProductId),
            isActive: true,
            carbonFootprint: 0,
            metadataIPFS: "",
            imagesIPFS: new string[](0)
        });

        products[newProductId] = newProduct;

        //Update tracking arrays efficiently
        allProductsIds.push(newProductId);
        productByCategory[_data.category].push(newProductId);
        productsByOwner[msg.sender].push(newProductId);

        if (!categoryExists[_data.category]) {
            allCategories.push(_data.category);
            categoryExists[_data.category] = true;
        }

        // Create intial transaction record
        DataStructures.Transaction memory initialTx = DataStructures.Transaction({
            productID: newProductId,
            from: address(0),
            to: msg.sender,
            price: 0,
            quantity: uint128(_data.quantity),
            stage: DataStructures.ProductStage.Planted,
            timestamp: uint64(block.timestamp),
            estimatedDelivery: 0,
            transactionHash: "",
            notes: "Product Created",
            locationIPFS: ""
        });

        productTransactions[newProductId].push(initialTx);

        try stakeholderManager._addProductToFarmer(msg.sender, newProductId) {} catch {}

        emit ProductCreated(newProductId, msg.sender, _data.name, _data.category, _data.quantity);

        return newProductId;

   }

   //=======================Optimized Product Lifecycle==============

    function updateProductStage(uint256 _productId, DataStructures.ProductStage _newStage,DataStructures.Location memory _newLocation,string memory _notes) external 
        productExists(_productId)
        onlyProductOwner(_productId)
        productNotBlocked(_productId)
        userNotBlocked {
            DataStructures.Product storage product = products[_productId];

            // Gas Optimization
            assembly {
            let currentStage := sload(add(product.slot, 0x15)) // currentStage offset
            if iszero(gt(_newStage, currentStage)) {
                mstore(0x00, 0x73746167655f657272)
                revert(0x00, 0x20)
            }   
        }
        _validateStageTransition(product.currentOwner, _newStage); 

        DataStructures.ProductStage previousStage = product.stage;

        product.stage = _newStage;
        product.currentLocation = _newLocation;
        product.lastUpdated = uint64(block.timestamp);

        if(_newStage == DataStructures.ProductStage.Harvested && product.harvestDate == 0) {
            product.harvestDate = uint64(block.timestamp);
        }

        //Create transaction record
        DataStructures.Transaction memory stageTransaction = DataStructures.Transaction({
            productID: _productId,
            from: msg.sender,
            to: msg.sender,
            price: 0,
            quantity: product.quantity,
            stage: _newStage,
            timestamp: uint64(block.timestamp),
            estimatedDelivery: 0,
            transactionHash: "",
            notes: _notes,
            locationIPFS: ""
        });

        productTransactions[_productId].push(stageTransaction);

        emit ProductStageUpdated(_productId, previousStage, _newStage, msg.sender, block.timestamp);
        emit ProductLocationUpdated(_productId, product.currentLocation.name, _newLocation.name, _newLocation.coordinates, msg.sender);
    }
    //======================Optimized Quality Assessment======================
    function recordQualityAssessment(uint256 _productId, DataStructures.QualityData memory _qualityData
    ) external
        productExists(_productId)
        onlyRole(INSPECTOR_ROLE)
        productNotBlocked(_productId) {

            if(_qualityData.score > 100) revert InvalidInputData();
            if(_qualityData.parameters.length != _qualityData.parameterScores.length) revert InvalidInputData();
            if(_qualityData.score < systemConfig.minQualityScore) revert QualityScoreTooLow();
            if(!stakeholderManager.canPerformVerification(msg.sender)) revert StakeholderNotVerified();

            //Create Quality Record
            DataStructures.Quality memory qualityRecord = DataStructures.Quality ({
                grade: _qualityData.grade,
                score: _qualityData.score,
                inspector: msg.sender,
                timestamp: uint64(block.timestamp),
                testResults: _qualityData.testResults,
                parameters: _qualityData.parameters,
                parameterScores: _qualityData.parameterScores
            });

            products[_productId].qualityHistory.push(qualityRecord);

            try stakeholderManager._addProductToInspector(msg.sender, _productId) {} catch {}

            emit QualityRecorded(_productId, _qualityData.grade, _qualityData.score, msg.sender, block.timestamp);
    }
    //======================Optimized Product Transfer==================

    function transferProduct(
        DataStructures.TransferData memory _transferData
    ) external 
        productExists(_transferData.productId)
        onlyProductOwner(_transferData.productId)
        productNotBlocked(_transferData.productId)
        userNotBlocked
        canParticipateInTransactions
        nonReentrant {

            if (_transferData.to == address(0) || _transferData.to == msg.sender) revert InvalidInputData();
            if (_transferData.price == 0) revert InvalidInputData();
            if (!stakeholderManager.canParticipateInTransactions(_transferData.to)) {
            revert InsufficientReputation();
            }

            // Check transaction hash uniqueness
            if (bytes(_transferData.transactionHash).length > 0) {
                bytes32 txHash = keccak256(bytes(_transferData.transactionHash));
                if (usedTransactionHashes[txHash]) revert InvalidInputData();
                usedTransactionHashes[txHash] = true;
            }

            _validateStageRecipient(_transferData.to , _transferData.newStage);

            DataStructures.Product storage product = products[_transferData.productId];
            address previousOwner = product.currentOwner;

            product.currentOwner = _transferData.to;
            product.stage = _transferData.newStage;
            product.lastUpdated = uint64(block.timestamp);

            _updatePricingForStage(product, _transferData.newStage, _transferData.price);

            _removeFromArray(productsByOwner[previousOwner], _transferData.productId);

            DataStructures.Transaction memory transaction = DataStructures.Transaction({
                productID: _transferData.productId,
                from: previousOwner,
                to: _transferData.to,
                price: uint256(_transferData.price),
                quantity: product.quantity,
                stage: _transferData.newStage,
                timestamp: uint64(block.timestamp),
                estimatedDelivery: uint64(_transferData.estimatedDelivery),
                transactionHash: _transferData.transactionHash,
                notes: _transferData.notes,
                locationIPFS: _transferData.locationIPFS
            });

            productTransactions[_transferData.productId].push(transaction);

            _updateStakeholderProductLists(_transferData.to, _transferData.productId);

            emit ProductTransferred(_transferData.productId, previousOwner, _transferData.to, _transferData.price, product.quantity, _transferData.newStage);   
        }
   //=======================Internal Functions=======================
   function _validateStageTransition(address _owner, DataStructures.ProductStage _newStage) internal view {

        string memory stakeholderType = stakeholderManager.getStakeholderType(_owner);
        bytes32 typeHash = keccak256(bytes(stakeholderType));

        if (typeHash == keccak256("farmer")) {
            revert UnauthorizedStageTransition();
        } else if (typeHash == keccak256("distributor")) {
            if (_newStage < DataStructures.ProductStage.ShippedToDistributor ||
            _newStage > DataStructures.ProductStage.ShippedToRetailer){
                revert UnauthorizedStageTransition();
            }
        } else if (typeHash == keccak256("retailer")) {
            if (_newStage < DataStructures.ProductStage.ReceivedByRetailer) {
                revert UnauthorizedStageTransition();
            }
        }
   }

   function _generateBatchNumber(address _farmer, uint256 _productId) internal view returns (string memory) {
    return string(abi.encodePacked(
        "BATCH-",
        _addressToString(_farmer),
        "-",
        _uint256ToString(_productId),
        "-",
        _uint256ToString(block.timestamp)
    ));
   }

   function _addressToString(address _addr) internal pure returns (string memory) {
        
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(8);
        for (uint256 i = 0; i < 4; i++) {
            str[i*2] = alphabet[uint8(value[i + 12] >> 4)];
            str[1 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str); 
   }
   
   function _uint256ToString(uint256 _value) internal pure returns(string memory) {
       if(_value == 0) return "0";

       uint256 temp = _value;
       uint256 digits;
       while (temp != 0) {
        digits++;
        temp /= 10;
       }

       bytes memory buffer =  new bytes(digits);
       while (_value != 0) {
        digits -= 1;
        buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
       }
       return string(buffer);
   }

   function _validateStageRecipient(address _recipient , DataStructures.ProductStage _stage) internal view {

        string memory stakeholderType = stakeholderManager.getStakeholderType(_recipient);
        bytes32 typeHash = keccak256(bytes(stakeholderType));

        if(_stage >= DataStructures.ProductStage.ShippedToDistributor && _stage <= DataStructures.ProductStage.ShippedToRetailer) {
            if (typeHash != keccak256("distributor")) revert UnauthorizedStageTransition();
        } else if (_stage >= DataStructures.ProductStage.ReceivedByRetailer) {
            if (typeHash != keccak256("retailer")) revert UnauthorizedStageTransition();
        }
   }

    function _updatePricingForStage(DataStructures.Product storage _product, DataStructures.ProductStage _stage, uint256 _price) internal {
        
        if (_stage >= DataStructures.ProductStage.ReceivedByDistributor && _stage <= DataStructures.ProductStage.ShippedToRetailer) {
            _product.price.distributorPrice = uint128(_price);
        } else if (_stage >= DataStructures.ProductStage.ReceivedByRetailer) {
            _product.price.distributorPrice = uint128(_price);
        }
        _product.price.lastUpdated = uint64(block.timestamp);
   }

   function _removeFromArray(uint256[] storage _array, uint256 _value) internal {
        uint256 length = _array.length;
        for(uint256 i = 0; i < length; i++) {
            if(_array[i] == _value) {
                _array[i] = _array[length - 1];
                _array.pop();
                break;
            }
        }
   }

   function _updateStakeholderProductLists(address _recipient, uint256 _productId) internal {
        string memory stakeholderType = stakeholderManager.getStakeholderType(_recipient);
        bytes32 typeHash = keccak256(bytes(stakeholderType));
        
        if (typeHash == keccak256("distributor")) {
            try stakeholderManager._addProductToDistributor(_recipient, _productId) {} catch {}
        } else if (typeHash == keccak256("retailer")) {
            try stakeholderManager._addProductToRetailer(_recipient, _productId) {} catch {}
        }
    }

   
}