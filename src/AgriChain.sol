//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DataStructures} from "./DataStructures.sol";
import {IAgriChainEvents} from "./IAgriChainEvents.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {StakeholderManager} from "./StakeholderManager.sol";
import {IPFSStorage} from "./IPFSStorage.sol";
import {ProductManager} from "./ProductManager.sol";

/**
 * @title AgriChain Main Supply Chain Tracking Contract
 * @dev Optimized for gas efficiency and security.
 * Inherits from OpenZeppelin's AccessControl, Pausable, and ReentrancyGuard for robust access management and security.
 * Central Contract for managing agricultural product lifecycle from farm to consumer and IPFS integration.
 */
contract AgriChain is Pausable, IAgriChainEvents, AccessControl, ReentrancyGuard {
    
    string public constant VERSION ="2.0.0";
    //Role Definitions
    bytes32 constant ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant FARMER_ROLE = 0x9decc540ed7e12dc756a0a33fd30896853d6f3395609286d2d83d03db68fbac9;
    bytes32 constant DISTRIBUTOR_ROLE = 0x7722e3dbdf7a5417dd23d582ff681776bb661e10ab9355388e1d977817a7a1b5;
    bytes32 constant RETAILER_ROLE = 0xc3ca1c550e48f508639854b12b070ee6611457a1fe9df69a92864114bfc0e5cf;
    bytes32 constant INSPECTOR_ROLE = 0x52d54c20deb3c9c90c1e2b1d66f2c5b1c2c839c7563acb76f7b6cc33fcfea88d;
    bytes32 constant CONSUMER_ROLE = 0xf68bd05f8c923fb67135d973b6dd82d27a4c223491e429030519a49304933945;

    struct SystemConfig {
        uint128 platformFeePercentage;  // 0.25% 25 basis points
        uint128 maxPlatformFee;
        bool systemInitialized;
        bool emergencyStop;
    }   

    // Core contract references
    StakeholderManager public immutable stakeholderManager;
    ProductManager public immutable productManager;
    IPFSStorage public immutable ipfsStorage;

    // System config 
    SystemConfig public systemConfig;

    // Deployment and admin info
    uint256 public immutable deploymentTime;
    address public immutable systemAdmin;
    address payable public feeRecipient;

    // Packed system metrics for gas optimization
    struct SystemMetrics {
        uint64 totalSystemTransactions;
        uint64 totalValueTransacted;
        uint64 totalCarbonFootprintTracked;
        uint64 lastUpdated;
    }
    SystemMetrics public systemMetrics;

    //Emergency Control
    mapping(address => bool) public emergencyAdmins;

    //Events
    event SystemInitialized(address indexed admin, uint256 timestamp);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee, address indexed updatedBy);
    event EmergencyStopToggled(bool stopped, address indexed toggledBy);

    //Errors
    error AlreadyInitialized();
    error NotInitialized();
    error EmergencyStopActive();
    error InsufficientPlatformFee();
    error InvalidFeePercentage();
    error NotEmergencyAdmin();
    error NoFeesToWithdraw();

    //Modifiers
    // Modifiers optimized for gas

    modifier onlyInitialized() {
        if (!systemConfig.systemInitialized) revert NotInitialized();
        _;
    }

    modifier notInEmergency() {
        if (systemConfig.emergencyStop) revert EmergencyStopActive();
        _;
    }

    modifier onlyEmergencyAdmin() {
        if (!emergencyAdmins[msg.sender] && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert NotEmergencyAdmin();
        }
        _;
    }

    constructor() {
        stakeholderManager = new StakeholderManager();
        productManager = new ProductManager(address(stakeholderManager));
        ipfsStorage = new IPFSStorage();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        systemAdmin = msg.sender;
        deploymentTime = block.timestamp;
        feeRecipient = payable(msg.sender); 

        systemConfig = SystemConfig({
            platformFeePercentage: 25,
            maxPlatformFee: 500,
            systemInitialized: false,
            emergencyStop: false
        });

        emergencyAdmins[msg.sender] = true;

        emit SystemInitialized(msg.sender, block.timestamp);
    }

    // ========================SYSTEM INITIALIZATION===========================

    function initializeSystem() external onlyRole(ADMIN_ROLE) {
        if(systemConfig.systemInitialized) revert AlreadyInitialized();

        //Grant roles to component contracts 
        _grantRole(ADMIN_ROLE, address(stakeholderManager));
        _grantRole(ADMIN_ROLE, address(productManager));
        _grantRole(ADMIN_ROLE, address(ipfsStorage));

        systemConfig.systemInitialized = true;

        emit SystemInitialized(msg.sender, block.timestamp);
    }

    // ======================== STAKEHOLDER MANAGEMENT ============================

    function registerFarmer(DataStructures.FarmerRegistration memory _data) external payable onlyInitialized notInEmergency {
        stakeholderManager.registerFarmer{value: msg.value}(_data);
        _grantRole(FARMER_ROLE, msg.sender);
    }

    function registerDistributor(DataStructures.DistributorRegistration memory _data) external payable onlyInitialized notInEmergency {
        stakeholderManager.registerDistributor{value: msg.value}(_data);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }

    function registerRetailer(DataStructures.RetailerRegistration memory _data) external payable onlyInitialized notInEmergency {
        stakeholderManager.registerRetailer{value: msg.value}(_data);
        _grantRole(RETAILER_ROLE, msg.sender);
    }

    function registerConsumer() external onlyInitialized notInEmergency {
        _grantRole(CONSUMER_ROLE, msg.sender);
    }

    // ======================== PRODUCT LIFECYCLE MANAGEMENT ========================

    function createProductWithIPFS(DataStructures.ProductCreationData memory _data,string memory _metadataIPFSHash) external onlyInitialized notInEmergency onlyRole(FARMER_ROLE) returns (uint256) {

        uint256 newProductId = productManager.createProduct(_data);
    
        if (bytes(_metadataIPFSHash).length > 0) {
            ipfsStorage.storeProductMetadata(newProductId, _metadataIPFSHash);
        }

        unchecked {
            systemMetrics.totalSystemTransactions++;
            systemMetrics.lastUpdated = uint64(block.timestamp);
        }

        return newProductId;
    }
    
    function updateProductStage(
        uint256 _productId,
        DataStructures.ProductStage _newStage,
        DataStructures.Location memory _newLocation,
        string memory _notes
    ) external onlyInitialized notInEmergency {
        productManager.updateProductStage(_productId, _newStage, _newLocation, _notes);
    }

    function transferProduct(DataStructures.TransferData memory _transferData) external payable onlyInitialized notInEmergency nonReentrant {

        uint256 platformFee;
        assembly {
            let price := mload(add(_transferData, 0x40)) // _transferData.price offset
            let feePercentage := sload(systemConfig.slot)
            platformFee := div(mul(price, and(feePercentage, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 10000)
        }

        if (msg.value < platformFee) revert InsufficientPlatformFee();

        unchecked {
            systemMetrics.totalSystemTransactions++;
            systemMetrics.totalValueTransacted += uint64(_transferData.price);
            systemMetrics.lastUpdated = uint64(block.timestamp);
        }

        if(msg.value > platformFee) {
            payable(msg.sender).transfer(msg.value - platformFee);
        }
    }

    function recordQualityAssessment(uint256 _productId, DataStructures.QualityData memory _qualityData) external onlyInitialized notInEmergency onlyRole(INSPECTOR_ROLE) {
        productManager.recordQualityAssessment(_productId, _qualityData);
    }

    // ============================ IPFS INTEGRATION ===============================

    function uploadProductImages(
        uint256 _productId,
        string[] memory _ipfsHashes
    ) external onlyInitialized {
        ipfsStorage.addProductImages(_productId, msg.sender, _ipfsHashes);
    }
    
    function getProductIPFSData(uint256 _productId) 
        external view onlyInitialized 
        returns (string[] memory images, string memory metadata) {
        return ipfsStorage.getProductIPFSData(_productId);
    }
    
    function uploadDocuments(
        uint256 _productId,
        string[] memory _documentHashes,
        string[] memory _documentTypes
    ) external onlyInitialized {
        require(_documentHashes.length == _documentTypes.length, "Array length mismatch");
        ipfsStorage.addProductDocuments(_productId, msg.sender, _documentHashes, _documentTypes);
    }

    // ====================== CONSUMER INTERFACE =========================

    function getProductInfo(uint256 _productId) external view onlyInitialized returns (DataStructures.Product memory product, string[] memory ipfsImages) {
        product = productManager.getProduct(_productId);
        (ipfsImages,) = ipfsStorage.getProductIPFSData(_productId);
        return (product, ipfsImages);
    }

    function verifyProductAuthenticity(uint256 _productId) 
        external view onlyInitialized 
        returns (bool isAuthentic, string memory verificationDetails) {
        
        DataStructures.Product memory product = productManager.getProduct(_productId);
        
        if (!product.isActive) {
            return (false, "Product not found or inactive");
        }
        
        // Verify using packed data for gas efficiency
        DataStructures.Transaction[] memory transactions = productManager.getProductTransactions(_productId);
        if (transactions.length == 0) {
            return (false, "No transaction history found");
        }
        
        // Use assembly for efficient stage progression check
        assembly {
            let txsPtr := add(transactions, 0x20)
            let txsLen := mload(transactions)
            let lastStage := 0
            
            for { let i := 0 } lt(i, txsLen) { i := add(i, 1) } {
                let txs := mload(add(txsPtr, mul(i, 0x20)))
                let currentStage := mload(add(txs, 0xC0)) // stage offset
                
                if lt(currentStage, lastStage) {
                    // Invalid progression detected
                    mstore(0x00, 0)
                    return(0x00, 0x20)
                }
                lastStage := currentStage
            }
        }
        
        if (!stakeholderManager.isStakeholderVerified(product.farmer)) {
            return (false, "Farmer not verified");
        }
        
        return (true, "Product authenticity verified");
    }

    // ========================== ANALYTICS AND REPORTING ============================

    function getSupplyChainAnalytics() external view onlyInitialized returns (DataStructures.SupplyChainAnalytics memory analytics) {
        (
            analytics.totalProducts,
            analytics.activeProducts,
            analytics.totalTransactions,
            analytics.averageQualityScore,
            analytics.totalCarbonFootprint
        ) = productManager.getSystemStatistics();

        (
            analytics.totalFarmers,
            analytics.totalDistributors,
            analytics.totalRetailers,
            analytics.totalInspectors
        ) = stakeholderManager.getTotalStakeholders();

        analytics.averageSupplyTime = calculateAverageSupplyTime();
        analytics.lastUpdated = block.timestamp;
    }

    function getSustainabilityMetrics() external view onlyInitialized returns (
        uint256 totalCarbonFootprint,
        uint256 organicProductsCount,
        uint256 sustainableFarmsCount,
        uint256 averageCarbonPerProduct
    ) {
        return productManager.getSustainabilityMetrics();
    }
    //========================= ADMIN FUNCTIONS =============================
    
    function verifyStakeholder(address _stakeholder, string memory _stakeholderType) external onlyRole(ADMIN_ROLE) {
        stakeholderManager.verifyStakeholder(_stakeholder,_stakeholderType);

        // Grant inspector role if verfying an inspector
        bytes32 stakeholderHash = keccak256(bytes(_stakeholderType));
        if(stakeholderHash == keccak256("inspector")) {
            _grantRole(INSPECTOR_ROLE, _stakeholder);
        }
    }

    function setPlatformFee(uint128 _newFeePercentage) external onlyRole(ADMIN_ROLE) {
        if(_newFeePercentage > systemConfig.maxPlatformFee) revert InvalidFeePercentage();

        uint256 oldFee = systemConfig.platformFeePercentage;
        systemConfig.platformFeePercentage = _newFeePercentage;

        emit PlatformFeeUpdated(oldFee, _newFeePercentage, msg.sender);
    }

    function toggleEmergencyStop() external onlyEmergencyAdmin {
        systemConfig.emergencyStop = !systemConfig.emergencyStop;
        emit EmergencyStopToggled(systemConfig.emergencyStop, msg.sender);
    }

    function pauseSystem() external onlyRole(ADMIN_ROLE) {
        _pause();
        stakeholderManager.pauseContract();
        productManager.pauseContract();
        ipfsStorage.pauseContract();
    }
    
    function unpauseSystem() external onlyRole(ADMIN_ROLE) {
        _unpause();
        stakeholderManager.unpauseContract();
        productManager.unpauseContract();
        ipfsStorage.unpauseContract();
    }

    function withdrawFees() external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFeesToWithdraw();
        feeRecipient.transfer(balance);
    }
    // ======================== UTILITY FUNCTIONS ===========================
    function getSystemInfo() external view returns (
        string memory version,
        uint256 deploymentTimestamp,
        address admin,
        bool initialized,
        bool paused,
        bool inEmergency,
        uint128 platformFee
    ) {
        return (
            VERSION,
            deploymentTime,
            systemAdmin,
            systemConfig.systemInitialized,
            paused,
            systemConfig.emergencyStop,
            systemConfig.platformFeePercentage
        );
    }
    
    function calculatePlatformFee(uint256 _transactionValue) external view returns (uint256) {
        return (_transactionValue * systemConfig.platformFeePercentage) / 10000;
    }


    //==============================INTERNAL FUNCTION=================================
    function calculateAverageSupplyTime() internal view returns (uint256) {
        uint256[] memory allProducts = productManager.getAllProductIds();
        if (allProducts.length == 0) return 0;
        
        uint256 totalTime;
        uint256 completedProducts;
        
        // Use assembly for gas-efficient calculation
        assembly {
            let productsPtr := add(allProducts, 0x20)
            let productsLen := mload(allProducts)
            
            for { let i := 0 } lt(i, productsLen) { i := add(i, 1) } {
                // This would call productManager.calculateSupplyChainDuration
                // Implementation would depend on specific requirements
            }
        }
        
        return completedProducts > 0 ? totalTime / completedProducts : 0;
    }

    receive() external payable {
        // Accept ETH for platform fees
    }
    
    fallback() external payable {
        revert("Function not found");
    }
}
