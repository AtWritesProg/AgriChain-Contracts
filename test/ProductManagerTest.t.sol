//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StakeholderManager} from "../src/StakeholderManager.sol";
import {DataStructures} from "../src/DataStructures.sol";
import {ProductManager} from "../src/ProductManager.sol";
import {IAgriChainEvents} from "../src/IAgriChainEvents.sol";

contract ProductManagerTest is Test {
    ProductManager public productManager;
    StakeholderManager public stakeholderManager;
    
    // Test addresses
    address public owner;
    address public farmer1;
    address public farmer2;
    address public distributor1;
    address public retailer1;
    address public inspector1;
    
    // Sample data
    DataStructures.Location sampleLocation;
    DataStructures.FarmingPractices samplePractices;
    DataStructures.ProductCreationData sampleProductData;
    DataStructures.TransferData sampleTransferData;
    DataStructures.QualityData sampleQualityData;
    
    // Events
    event ProductCreated(uint256 indexed productId, address indexed farmer, string name, string category, uint256 quantity);
    event ProductStageUpdated(uint256 indexed productId, DataStructures.ProductStage prevStage, DataStructures.ProductStage newStage, address indexed updatedBy, uint256 timestamp);
    event ProductTransferred(uint256 indexed productId, address indexed from, address indexed to, uint256 price, uint256 quantity, DataStructures.ProductStage stage);
    event QualityRecorded(uint256 indexed productId, DataStructures.QualityGrade grade, uint8 score, address indexed inspector, uint256 timestamp);
    event ProductLocationUpdated(uint256 indexed productId, string prevLocation, string newLocation, string coordinates, address indexed updatedBy);
    event PriceUpdated(uint256 indexed productId, string priceType, uint256 oldPrice, uint256 indexed newPrice, address indexed updatedBy);
    
    function setUp() public {
        // Setup test addresses
        owner = address(this);
        farmer1 = makeAddr("farmer1");
        farmer2 = makeAddr("farmer2");
        distributor1 = makeAddr("distributor1");
        retailer1 = makeAddr("retailer1");
        inspector1 = makeAddr("inspector1");
        
        // Deploy contracts
        stakeholderManager = new StakeholderManager();
        productManager = new ProductManager(address(stakeholderManager));
        
        // Fund test addresses
        vm.deal(farmer1, 10 ether);
        vm.deal(farmer2, 10 ether);
        vm.deal(distributor1, 10 ether);
        vm.deal(retailer1, 10 ether);
        vm.deal(inspector1, 10 ether);
        
        // Setup sample location
        sampleLocation = DataStructures.Location({
            name: "Test Farm Location",
            coordinates: "12.34, 56.78",
            farm_address: "123 Farm Road, Test City",
            country: bytes32("IND"),
            region: "Gujarat"
        });
        
        // Setup sample farming practices
        samplePractices = DataStructures.FarmingPractices({
            isOrganic: true,
            usesPesticides: false,
            usesGMO: false,
            waterUsage: 1000,
            soilType: "Loamy",
            fertilizersUsed: new string[](2),
            pesticidesUsed: new string[](0),
            sustainablePractices: new string[](2)
        });
        samplePractices.fertilizersUsed[0] = "Compost";
        samplePractices.fertilizersUsed[1] = "Manure";
        samplePractices.sustainablePractices[0] = "Crop Rotation";
        samplePractices.sustainablePractices[1] = "Cover Cropping";
        
        // Setup sample product creation data
        DataStructures.CertificationType[] memory certifications = new DataStructures.CertificationType[](2);
        certifications[0] = DataStructures.CertificationType.Organic;
        certifications[1] = DataStructures.CertificationType.NonGMO;
        
        sampleProductData = DataStructures.ProductCreationData({
            name: "Organic Tomatoes",
            variety: "Roma",
            category: "Vegetable",
            quantity: 1000,
            unit: "kg",
            plantedDate: uint128(block.timestamp - 90 days),
            harvestDate: uint128(block.timestamp),
            expiryDate: uint128(block.timestamp + 30 days),
            certificationType: certifications,
            description: "Fresh organic Roma tomatoes",
            farmGatePrice: 50, // 50 units per kg
            practices: samplePractices
        });
        
        // Setup sample transfer data
        sampleTransferData = DataStructures.TransferData({
            productId: 1,
            to: distributor1,
            price: 60,
            newStage: DataStructures.ProductStage.ShippedToDistributor,
            transactionHash: "QmTestTransactionHash",
            notes: "Standard transfer to distributor",
            locationIPFS: "QmTestLocationIPFS",
            estimatedDelivery: uint64(block.timestamp + 1 days)
        });
        
        // Setup sample quality data
        string[] memory parameters = new string[](2);
        parameters[0] = "pH: 6.5";
        parameters[1] = "Moisture: 12%";
        
        uint8[] memory parameterScores = new uint8[](2);
        parameterScores[0] = 90;
        parameterScores[1] = 85;
        
        sampleQualityData = DataStructures.QualityData({
            grade: DataStructures.QualityGrade.A_Premium,
            score: 88,
            testResults: "QmTestResultsIPFS",
            parameters: parameters,
            parameterScores: parameterScores
        });
        
        // Register and verify stakeholders for testing
        _registerAndVerifyStakeholders();
    }

    function _registerAndVerifyStakeholders() internal {
        // Register farmer
        DataStructures.FarmerRegistration memory farmerReg = DataStructures.FarmerRegistration({
            name: "John Doe",
            farmName: "Green Valley Farm",
            farmLocation: sampleLocation,
            additionalFarms: new DataStructures.Location[](0),
            certifications: new DataStructures.CertificationType[](2),
            email: "john@example.com",
            phoneNumber: "+1234567890",
            practices: samplePractices
        });
        farmerReg.certifications[0] = DataStructures.CertificationType.Organic;
        farmerReg.certifications[1] = DataStructures.CertificationType.NonGMO;
        
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(farmerReg);
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
        
        // Register distributor
        DataStructures.Location[] memory warehouses = new DataStructures.Location[](1);
        warehouses[0] = sampleLocation;
        string[] memory specializations = new string[](2);
        specializations[0] = "Grains";
        specializations[1] = "Vegetables";
        
        DataStructures.DistributorRegistration memory distributorReg = DataStructures.DistributorRegistration({
            name: "Jane Smith",
            companyName: "Fresh Logistics Inc",
            licenseNumber: "DL12345",
            warehouses: warehouses,
            email: "jane@freshlogistics.com",
            phoneNumber: "+1987654321",
            storageCapacity: 50000,
            specializations: specializations
        });
        
        vm.prank(distributor1);
        stakeholderManager.registerDistributor(distributorReg);
        stakeholderManager.verifyStakeholder(distributor1, "distributor");
        
        // Register retailer
        DataStructures.RetailerRegistration memory retailerReg = DataStructures.RetailerRegistration({
            name: "Bob Wilson",
            storeName: "Fresh Market",
            licenseNumber: "RL67890",
            storeLocation: sampleLocation,
            additionalStores: new DataStructures.Location[](0),
            email: "bob@freshmarket.com",
            phoneNumber: "+1122334455",
            storeType: "Grocery"
        });
        
        vm.prank(retailer1);
        stakeholderManager.registerRetailer(retailerReg);
        stakeholderManager.verifyStakeholder(retailer1, "retailer");
        
        // Register inspector
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](2);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        authorizedFor[1] = DataStructures.CertificationType.NonGMO;
        
        vm.prank(inspector1);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        stakeholderManager.verifyStakeholder(inspector1, "inspector");
        
        // Set high reputation for inspector to allow verification
        stakeholderManager.updateReputation(inspector1, 75, "QmHighScore");
    }
    
    // Add receive function to accept Ether
    receive() external payable {}
}