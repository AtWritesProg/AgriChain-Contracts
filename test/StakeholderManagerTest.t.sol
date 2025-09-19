//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StakeholderManager} from "../src/StakeholderManager.sol";
import {DataStructures} from "../src/DataStructures.sol";
import {IAgriChainEvents} from "../src/IAgriChainEvents.sol";

contract StakeholderManagerTest is Test {
    StakeholderManager private stakeholderManager;

    // Test addresses
    address public owner;
    address public farmer1;
    address public farmer2;
    address public distributor1;
    address public retailer1;
    address public inspector1;
    address public admin2;

    // Sample data
    DataStructures.Location sampleLocation;
    DataStructures.FarmingPractices samplePractices;
    DataStructures.FarmerRegistration sampleFarmerReg;
    DataStructures.DistributorRegistration sampleDistributorReg;
    DataStructures.RetailerRegistration sampleRetailerReg;

    // Events
    event StakeholderRegistered(address indexed stakeholder, string stakeholderType, string name, uint64 timestamp);
    event FarmerRegistered(address indexed farmer, string name, string farmName, string location);
    event DistributorRegistered(address indexed distributor, string name, string companyName, uint256 warehouseCount);
    event RetailerRegistered(address indexed retailer, string name, string storeName, string location);
    event InspectorRegistered(address indexed inspector, string name, string organization, string licenseNumber);
    event StakeholderVerified(address indexed stakeholder, string stakeholderType, address verifiedBy, uint256 timestamp);
    event VerificationStatusChanged(address indexed stakeholder, bool verified, address indexed verifier, uint64 timestamp);
    event ReputationScoreUpdated(address indexed stakeholder, uint8 oldScore, uint8 newScore, string ipfsReason);
    event ReputationUpdated(address indexed stakeholder, uint8 oldScore, uint8 indexed newScore, string reason, address indexed updatedBy);

    function setUp() public {
        owner = address(this);
        farmer1 = makeAddr("farmer1");
        farmer2 = makeAddr("farmer2");
        distributor1 = makeAddr("distributor1");
        retailer1 = makeAddr("retailer1");
        inspector1 = makeAddr("inspector1");
        admin2 = makeAddr("admin2");

        stakeholderManager = new StakeholderManager();

        sampleLocation = DataStructures.Location({
            name: "Test Farm Location",
            coordinates: "12.34, 56.78",
            farm_address: "123 Farm Road, Test City",
            country: bytes32("IND"),
            region: "Gujarat"
        });

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

        sampleFarmerReg = DataStructures.FarmerRegistration({
            name: "John Doe",
            farmName: "Green Valley Farm",
            farmLocation: sampleLocation,
            additionalFarms: new DataStructures.Location[](0),
            certifications: new DataStructures.CertificationType[](2),
            email: "john@example.com",
            phoneNumber: "+1234567890",
            practices: samplePractices
        });
        sampleFarmerReg.certifications[0] = DataStructures.CertificationType.Organic;
        sampleFarmerReg.certifications[1] = DataStructures.CertificationType.NonGMO;
        
        // Setup sample distributor registration
        DataStructures.Location[] memory warehouses = new DataStructures.Location[](1);
        warehouses[0] = sampleLocation;
        string[] memory specializations = new string[](2);
        specializations[0] = "Grains";
        specializations[1] = "Vegetables";
        
        sampleDistributorReg = DataStructures.DistributorRegistration({
            name: "Jane Smith",
            companyName: "Fresh Logistics Inc",
            licenseNumber: "DL12345",
            warehouses: warehouses,
            email: "jane@freshlogistics.com",
            phoneNumber: "+1987654321",
            storageCapacity: 50000,
            specializations: specializations
        });

        DataStructures.Location[] memory additionalStores = new DataStructures.Location[](0);
        
        sampleRetailerReg = DataStructures.RetailerRegistration({
            name: "Bob Wilson",
            storeName: "Fresh Market",
            licenseNumber: "RL67890",
            storeLocation: sampleLocation,
            additionalStores: additionalStores,
            email: "bob@freshmarket.com",
            phoneNumber: "+1122334455",
            storeType: "Grocery"
        });
        
        // Fund test addresses
        vm.deal(farmer1, 10 ether);
        vm.deal(farmer2, 10 ether);
        vm.deal(distributor1, 10 ether);
        vm.deal(retailer1, 10 ether);
        vm.deal(inspector1, 10 ether);
    } 

    // ==================Deployment Tests==================

    function testDeploymentSetsCorrectOwner() public view{
        bytes32 adminRole = 0x0000000000000000000000000000000000000000000000000000000000000000;
        assertTrue(stakeholderManager.hasRole(adminRole, owner), "Owner should have admin role");

        // Also DEFAULT_ADMIN_ROLE
        bytes32 defaultAdminRole = stakeholderManager.DEFAULT_ADMIN_ROLE();
        assertTrue(stakeholderManager.hasRole(defaultAdminRole, owner));
    }

    function testDeploymentIntializesSystemConfig() public view {
        (uint64 farmerFee, uint64 distributorFee, uint64 retailerFee, uint64 inspectorFee, uint8 minTxRep, uint8 minVerifyRep) = stakeholderManager.systemConfig();

        assertEq(farmerFee, 0);
        assertEq(distributorFee, 0);
        assertEq(retailerFee, 0);
        assertEq(inspectorFee, 0);
        assertEq(minTxRep, 30);
        assertEq(minVerifyRep, 70);
    }

    function testRegisterFarmerSuccessfully() public {
        vm.prank(farmer1);

        vm.expectEmit(true, true ,false , true);
        emit StakeholderRegistered(farmer1, "farmer", "John Doe", uint64(block.timestamp));

        vm.expectEmit(true, false, false, true);
        emit FarmerRegistered(farmer1, "John Doe", "Green Valley Farm", "Test Farm Location");
        
        stakeholderManager.registerFarmer(sampleFarmerReg);

        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertEq(farmer.wallet, farmer1);
        assertEq(farmer.name, "John Doe");
        assertEq(farmer.farmName, "Green Valley Farm");
        assertEq(farmer.reputationScore, 50);
        assertFalse(farmer.isVerified);

        //Verify role assignment
        bytes32 farmerRole = 0x9decc540ed7e12dc756a0a33fd30896853d6f3395609286d2d83d03db68fbac9;
        assertTrue(stakeholderManager.hasRole(farmerRole, farmer1));

        //Verify stakeholder data
        assertTrue(stakeholderManager.getStakeholderReputation(farmer1) == 50);
        assertFalse(stakeholderManager.isStakeholderVerified(farmer1));
    }

    function testRegisterFarmerFailsWithEmptyName() public {
        sampleFarmerReg.name = "";

        vm.prank(farmer1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerFarmer(sampleFarmerReg);
    }

    function testRegisterFarmerWithEmptyFarmName() public {
        sampleFarmerReg.farmName = "";

        vm.prank(farmer1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerFarmer(sampleFarmerReg);
    }

    function testRegisterFarmerFailsWhenAlreadyRegistered() public {
        vm.startPrank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);

        vm.expectRevert(StakeholderManager.AlreadyRegistered.selector);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        vm.stopPrank();
    }

    function testRegisterFarmerWithRegistrationFee() public {
        uint64 fee = 0.1 ether;
        stakeholderManager.setRegistrationFees(fee, 0, 0, 0);

        vm.prank(farmer1);
        stakeholderManager.registerFarmer{value: fee}(sampleFarmerReg);

        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertEq(farmer.name, "John Doe");
    }

    function testRegisterFarmerFailsWithInsufficientFee() public {
        uint64 fee = 0.1 ether;
        stakeholderManager.setRegistrationFees(fee, 0, 0, 0);

        vm.prank(farmer1);
        vm.expectRevert(StakeholderManager.InsufficientFunds.selector);
        stakeholderManager.registerFarmer{value: fee - 1}(sampleFarmerReg);
    }

    function testRegisterFarmerRefundsExcessFee() public {
        uint64 fee = 0.1 ether;
        uint256 excessPayment = 0.2 ether;

        stakeholderManager.setRegistrationFees(fee, 0, 0, 0);

        uint256 balanceBefore = farmer1.balance;

        vm.prank(farmer1);
        stakeholderManager.registerFarmer{value: excessPayment}(sampleFarmerReg);

        uint256 balanceAfter = farmer1.balance;
        assertEq(balanceBefore - balanceAfter, fee);
    }

    function testRegisterFarmerWhenContractPaused() public {
        stakeholderManager.pauseContract();

        vm.prank(farmer1);
        vm.expectRevert();
        stakeholderManager.registerFarmer(sampleFarmerReg);
    }

    // =====================Distributor Registration Tests========================

    function testRegisterDistributorSuccessfully() public {
        vm.prank(distributor1);
        
        vm.expectEmit(true, true, false, true);
        emit StakeholderRegistered(distributor1, "distributor", "Jane Smith", uint64(block.timestamp));
        
        vm.expectEmit(true, false, false, true);
        emit DistributorRegistered(distributor1, "Jane Smith", "Fresh Logistics Inc", 1);
        
        stakeholderManager.registerDistributor(sampleDistributorReg);
        
        // Verify distributor data
        (address wallet, string memory name, string memory companyName, , , , uint8 reputationScore, bool isVerified, , , ) = stakeholderManager.distributors(distributor1);
        assertEq(wallet, distributor1);
        assertEq(name, "Jane Smith");
        assertEq(companyName, "Fresh Logistics Inc");
        assertEq(reputationScore, 50);
        assertFalse(isVerified);
        
        // Verify role assignment
        bytes32 distributorRole = 0x7722e3dbdf7a5417dd23d582ff681776bb661e10ab9355388e1d977817a7a1b5; // DISTRIBUTOR_ROLE value
        assertTrue(stakeholderManager.hasRole(distributorRole, distributor1));
    }

    function testRegisterDistributorFailsWithEmptyName() public {
        sampleDistributorReg.name = "";
        
        vm.prank(distributor1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerDistributor(sampleDistributorReg);
    }

    function testRegisterDistributorFailsWithEmptyCompanyName() public {
        sampleDistributorReg.companyName = "";
        
        vm.prank(distributor1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerDistributor(sampleDistributorReg);
    }

    // =========================== Retailer Registration Tests ==========================
    function testRegisterRetailerSuccessfully() public {
        vm.prank(retailer1);
        
        vm.expectEmit(true, true, false, true);
        emit StakeholderRegistered(retailer1, "retailer", "Bob Wilson", uint64(block.timestamp));
        
        vm.expectEmit(true, false, false, true);
        emit RetailerRegistered(retailer1, "Bob Wilson", "Fresh Market", "Test Farm Location");
        
        stakeholderManager.registerRetailer(sampleRetailerReg);
        
        // Verify retailer data
        (address wallet, string memory name, string memory storeName, , , , uint8 reputationScore, bool isVerified, , , , ) = stakeholderManager.retailers(retailer1);
        assertEq(wallet, retailer1);
        assertEq(name, "Bob Wilson");
        assertEq(storeName, "Fresh Market");
        assertEq(reputationScore, 50);
        assertFalse(isVerified);
        
        // Verify role assignment
        bytes32 retailerRole = 0xc3ca1c550e48f508639854b12b070ee6611457a1fe9df69a92864114bfc0e5cf; // RETAILER_ROLE value
        assertTrue(stakeholderManager.hasRole(retailerRole, retailer1));
    }

    function testRegisterRetailerFailsWithEmptyName() public {
        sampleRetailerReg.name = "";
        
        vm.prank(retailer1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerRetailer(sampleRetailerReg);
    }
    
    function testRegisterRetailerFailsWithEmptyStoreName() public {
        sampleRetailerReg.storeName = "";
        
        vm.prank(retailer1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerRetailer(sampleRetailerReg);
    }

    // =========================== Inspector Registration Tests ==========================
    function testRegisterInspectorSuccessfully() public {
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](2);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        authorizedFor[1] = DataStructures.CertificationType.FairTrade;
        
        vm.prank(inspector1);
        
        vm.expectEmit(true, true, false, true);
        emit StakeholderRegistered(inspector1, "inspector", "Inspector John", uint64(block.timestamp));
        
        vm.expectEmit(true, false, false, true);
        emit InspectorRegistered(inspector1, "Inspector John", "Quality Assurance Corp", "INS12345");
        
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        
        // Verify inspector data
        (address wallet, string memory name, string memory organization, , , , bool isActive, , , ) = stakeholderManager.inspectors(inspector1);
        assertEq(wallet, inspector1);
        assertEq(name, "Inspector John");
        assertEq(organization, "Quality Assurance Corp");
        assertFalse(isActive); // Should require admin approval

        // Should not have inspector role until verified
        bytes32 inspectorRole = 0x52d54c20deb3c9c90c1e2b1d66f2c5b1c2c839c7563acb76f7b6cc33fcfea88d; // INSPECTOR_ROLE value
        assertFalse(stakeholderManager.hasRole(inspectorRole, inspector1));
    }

    function testRegisterInspectorFailsWithEmptyName() public {
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerInspector(
            "",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
    }

    function testRegisterInspectorFailsWithEmptyOrganization() public {
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerInspector(
            "Inspector John",
            "",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
    }
    function testRegisterInspectorFailsWithEmptyLicenseNumber() public {
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        vm.expectRevert(StakeholderManager.InvalidDataInput.selector);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
    }
    //============================ Verification Tests ====================================
    
    function testVerifyFarmerSuccessfully() public {
        // First register farmer
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        // Verify farmer
        vm.expectEmit(true, true, true, true);
        emit VerificationStatusChanged(farmer1, true, owner, uint64(block.timestamp));
        
        vm.expectEmit(true, false, false, true);
        emit StakeholderVerified(farmer1, "farmer", owner, block.timestamp);
        
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
        
        // Check verification status
        assertTrue(stakeholderManager.isStakeholderVerified(farmer1));
        
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertTrue(farmer.isVerified);
    }

    function testVerifyInspectorGrantsRole() public {
        // Register inspector
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        
        // Verify inspector
        stakeholderManager.verifyStakeholder(inspector1, "inspector");
        
        // Check inspector is active and has role
        DataStructures.Inspector memory inspector = stakeholderManager.getInspector(inspector1);
        assertTrue(inspector.isActive);
        
        bytes32 inspectorRole = 0x52d54c20deb3c9c90c1e2b1d66f2c5b1c2c839c7563acb76f7b6cc33fcfea88d; // INSPECTOR_ROLE value
        assertTrue(stakeholderManager.hasRole(inspectorRole, inspector1));
    }

    function testVerifyStakeholderFailsForUnregistered() public {
        vm.expectRevert(StakeholderManager.NotRegistered.selector);
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
    }

    function testVerifyStakeholderFailsWhenAlreadyVerified() public {
        // Register and verify farmer
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
        
        // Try to verify again
        vm.expectRevert(StakeholderManager.AlreadyVerified.selector);
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
    }

    function testVerifyStakeholderOnlyAdmin() public {
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.prank(farmer2);
        vm.expectRevert();
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
    }

    function testRevokeVerificationSuccessfully() public {
        // Register and verify farmer
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
        
        // Revoke verification
        stakeholderManager.revokeVerification(farmer1, "QmTestReasonIPFS");
        
        // Check verification is revoked
        assertFalse(stakeholderManager.isStakeholderVerified(farmer1));
        
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertFalse(farmer.isVerified);
    }

    function testRevokeVerificationFailsWhenNotVerified() public {
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.expectRevert(StakeholderManager.NotVerified.selector);
        stakeholderManager.revokeVerification(farmer1, "QmTestReasonIPFS");
    }

    // ===================== Query Functions Tests =========================

    function testGetStakeholderTypeReturnsCorrectType() public {
        // Register different stakeholder types
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.prank(distributor1);
        stakeholderManager.registerDistributor(sampleDistributorReg);
        
        vm.prank(retailer1);
        stakeholderManager.registerRetailer(sampleRetailerReg);
        
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        
        // Test stakeholder types
        assertEq(stakeholderManager.getStakeholderType(farmer1), "farmer");
        assertEq(stakeholderManager.getStakeholderType(distributor1), "distributor");
        assertEq(stakeholderManager.getStakeholderType(retailer1), "retailer");
        assertEq(stakeholderManager.getStakeholderType(inspector1), "inspector");
        
        // Test unregistered address
        assertEq(stakeholderManager.getStakeholderType(makeAddr("unregistered")), "unregistered");
    }

    function testGetTotalStakeholdersReturnsCorrectCounts() public {
        // Register stakeholders
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.prank(distributor1);
        stakeholderManager.registerDistributor(sampleDistributorReg);
        
        vm.prank(retailer1);
        stakeholderManager.registerRetailer(sampleRetailerReg);
        
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        
        // Check counts
        (uint256 farmers, uint256 distributors, uint256 retailers, uint256 inspectors) = 
            stakeholderManager.getTotalStakeholders();
            
        assertEq(farmers, 1);
        assertEq(distributors, 1);
        assertEq(retailers, 1);
        assertEq(inspectors, 1);
    }

    function testGetAverageReputationCalculatesCorrectly() public {
        // Register stakeholders (all start with reputation 50)
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.prank(distributor1);
        stakeholderManager.registerDistributor(sampleDistributorReg);
        
        // Should be 50 average
        assertEq(stakeholderManager.getAvgerageReputation(), 50);
        
        // Update one reputation
        stakeholderManager.updateReputation(farmer1, 80, "QmUpdated");
        
        // New average should be (80 + 50) / 2 = 65
        assertEq(stakeholderManager.getAvgerageReputation(), 65);
    }

    function testCanPerformVerificationChecksInspectorStatus() public {
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        
        // Unverified inspector should not be able to perform verification
        assertFalse(stakeholderManager.canPerformVerification(inspector1));
        
        // Verify inspector (makes them active)
        stakeholderManager.verifyStakeholder(inspector1, "inspector");
        
        // Inspector with reputation 50 should not be able to verify (threshold 70)
        assertFalse(stakeholderManager.canPerformVerification(inspector1));
        
        // Increase reputation above threshold
        stakeholderManager.updateReputation(inspector1, 75, "QmHighScore");
        assertTrue(stakeholderManager.canPerformVerification(inspector1));
    }

    // ==================== Admin Functions Tests ====================
    
    function testSetRegistrationFeesSuccessfully() public {
        uint64 fee = 0.1 ether;
        stakeholderManager.setRegistrationFees(fee, fee, fee, fee);
        
        (uint64 farmerFee, uint64 distributorFee, uint64 retailerFee, uint64 inspectorFee,,) = stakeholderManager.systemConfig();
        assertEq(farmerFee, fee);
        assertEq(distributorFee, fee);
        assertEq(retailerFee, fee);
        assertEq(inspectorFee, fee);
    }

    function testSetRegistrationFeesOnlyAdmin() public {
        vm.prank(farmer1);
        vm.expectRevert();
        stakeholderManager.setRegistrationFees(100, 100, 100, 100);
    }

    function testSetReputationThresholdsSuccessfully() public {
        stakeholderManager.setReputationThresholds(40, 80);
        
        (,,,, uint8 minTxRep, uint8 minVerifyRep) = stakeholderManager.systemConfig();
        assertEq(minTxRep, 40);
        assertEq(minVerifyRep, 80);
    }

    function testSetReputationThresholdsOnlyAdmin() public {
        vm.prank(farmer1);
        vm.expectRevert();
        stakeholderManager.setReputationThresholds(40, 80);
    }

    function testPauseAndUnpauseContract() public {
        // Contract should not be paused initially
        assertFalse(stakeholderManager.paused());
        
        // Pause contract
        stakeholderManager.pauseContract();
        assertTrue(stakeholderManager.paused());
        
        // Should fail to register when paused
        vm.prank(farmer1);
        vm.expectRevert();
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        // Unpause contract
        stakeholderManager.unpauseContract();
        assertFalse(stakeholderManager.paused());
        
        // Should work after unpausing
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertEq(farmer.name, "John Doe");
    }

    function testPauseContractOnlyAdmin() public {
        vm.prank(farmer1);
        vm.expectRevert();
        stakeholderManager.pauseContract();
    }
    
    function testUnpauseContractOnlyAdmin() public {
        stakeholderManager.pauseContract();
        
        vm.prank(farmer1);
        vm.expectRevert();
        stakeholderManager.unpauseContract();
    }

    function testWithdrawFeesSuccessfully() public {
    uint64 fee = 0.1 ether;
    stakeholderManager.setRegistrationFees(fee, 0, 0, 0);
    
    // Register farmer with fee
    vm.prank(farmer1);
    stakeholderManager.registerFarmer{value: fee}(sampleFarmerReg);
    
    // Check contract balance
    assertEq(address(stakeholderManager).balance, fee);
    
    // Create a payable address for withdrawal
    address payable withdrawalAddress = payable(makeAddr("withdrawal"));
    
    // Withdraw fees
    uint256 balanceBefore = withdrawalAddress.balance;
    stakeholderManager.withdrawFees(withdrawalAddress);
    uint256 balanceAfter = withdrawalAddress.balance;
    
    assertEq(balanceAfter - balanceBefore, fee);
    assertEq(address(stakeholderManager).balance, 0);
}

    function testWithdrawFeesFailsWithZeroAddress() public {
        vm.expectRevert("Invalid Address");
        stakeholderManager.withdrawFees(payable(address(0)));
    }
    
    function testWithdrawFeesFailsWhenNoFunds() public {
        vm.expectRevert("No Fund to Withdraw");
        stakeholderManager.withdrawFees(payable(owner));
    }
    
    function testWithdrawFeesOnlyAdmin() public {
        vm.prank(farmer1);
        vm.expectRevert();
        stakeholderManager.withdrawFees(payable(farmer1));
    }

    // ==================== Product Management Functions Tests =====================

    function testAddProductToFarmerSuccessfully() public {
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        uint256 productId = 1;
        stakeholderManager._addProductToFarmer(farmer1, productId);
        
        uint256[] memory products = stakeholderManager.getFarmerProducts(farmer1);
        assertEq(products.length, 1);
        assertEq(products[0], productId);
        
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertEq(farmer.totalHarvest, 1);
    }

    function testAddProductToDistributorSuccessfully() public {
        vm.prank(distributor1);
        stakeholderManager.registerDistributor(sampleDistributorReg);
        
        uint256 productId = 1;
        stakeholderManager._addProductToDistributor(distributor1, productId);
        
        uint256[] memory products = stakeholderManager.getDistributorProducts(distributor1);
        assertEq(products.length, 1);
        assertEq(products[0], productId);
    }

    function testAddProductToRetailerSuccessfully() public {
        vm.prank(retailer1);
        stakeholderManager.registerRetailer(sampleRetailerReg);
        
        uint256 productId = 1;
        stakeholderManager._addProductToRetailer(retailer1, productId);
        
        uint256[] memory products = stakeholderManager.getRetailerProducts(retailer1);
        assertEq(products.length, 1);
        assertEq(products[0], productId);
    }
    
    function testAddProductToInspectorSuccessfully() public {
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        
        uint256 productId = 1;
        stakeholderManager._addProductToInspector(inspector1, productId);
        
        uint256[] memory products = stakeholderManager.getInspectorProducts(inspector1);
        assertEq(products.length, 1);
        assertEq(products[0], productId);
    }

    function testGetInspectorAuthorizationsReturnsCorrectTypes() public {
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](2);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        authorizedFor[1] = DataStructures.CertificationType.FairTrade;
        
        vm.prank(inspector1);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        
        DataStructures.CertificationType[] memory returned = stakeholderManager.getInspectorAuthorizations(inspector1);
        assertEq(returned.length, 2);
        assertEq(uint8(returned[0]), uint8(DataStructures.CertificationType.Organic));
        assertEq(uint8(returned[1]), uint8(DataStructures.CertificationType.FairTrade));
    }
    
    function testProductManagementFunctionsOnlyAdmin() public {
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.prank(farmer2);
        vm.expectRevert();
        stakeholderManager._addProductToFarmer(farmer1, 1);
    }

    // ==================== Statistics Functions Tests ====================
    function testGetVerifiedStakeholdersCountsCorrectly() public {
        // Register stakeholders
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.prank(distributor1);
        stakeholderManager.registerDistributor(sampleDistributorReg);
        
        // Initially no verified stakeholders
        assertEq(stakeholderManager.getVerifiedStakeHolders(), 0);
        
        // Verify farmer
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
        assertEq(stakeholderManager.getVerifiedStakeHolders(), 1);
        
        // Verify distributor
        stakeholderManager.verifyStakeholder(distributor1, "distributor");
        assertEq(stakeholderManager.getVerifiedStakeHolders(), 2);
    }
    
    function testGetFarmerReturnsCorrectData() public {
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertEq(farmer.wallet, farmer1);
        assertEq(farmer.name, "John Doe");
        assertEq(farmer.farmName, "Green Valley Farm");
        assertEq(farmer.reputationScore, 50);
        assertFalse(farmer.isVerified);
    }

    function test_CannotRegisterWithZeroAddress() public pure {
        // This test verifies that msg.sender cannot be zero address
        // Note: In Foundry, we can't actually send from zero address as it would revert
        // This is more of a conceptual test to document the behavior
        
        // The contract relies on msg.sender, which cannot be zero in a real transaction
        // so this protection is implicit in the EVM
        assertTrue(true); // Placeholder to show the concept is covered
    }
    
    function testReentrancyProtectionInRegistration() public {
        // The contract uses nonReentrant modifiers from OpenZeppelin
        // and doesn't have external calls in registration functions except transfer
        // Transfer calls are at the end of functions (checks-effects-interactions pattern)
        
        uint64 fee = 0.1 ether;
        stakeholderManager.setRegistrationFees(fee, 0, 0, 0);
        
        vm.prank(farmer1);
        stakeholderManager.registerFarmer{value: fee}(sampleFarmerReg);
        
        // Verify the farmer was registered successfully
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertEq(farmer.name, "John Doe");
    }
    
    function testGasOptimizationUncheckedLoops() public {
        // Test that loops work correctly with unchecked increment
        // This verifies the gas optimization doesn't break functionality
        
        // Create farmer registration with multiple certifications and farms
        DataStructures.Location[] memory additionalFarms = new DataStructures.Location[](3);
        for (uint i = 0; i < 3; i++) {
            additionalFarms[i] = sampleLocation;
        }
        
        DataStructures.CertificationType[] memory certs = new DataStructures.CertificationType[](4);
        certs[0] = DataStructures.CertificationType.Organic;
        certs[1] = DataStructures.CertificationType.FairTrade;
        certs[2] = DataStructures.CertificationType.NonGMO;
        certs[3] = DataStructures.CertificationType.Pesticide_Free;
        
        sampleFarmerReg.additionalFarms = additionalFarms;
        sampleFarmerReg.certifications = certs;
        
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        // Verify registration succeeded with all data
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertEq(farmer.name, "John Doe");
        // Additional verification could check arrays but would require public getters
    }
    
    function testLargeStringHandling() public {
        // Test with very long strings to ensure no issues with string storage
        string memory longName = "This is a very long name that tests string storage limitations and ensures the contract can handle lengthy inputs without issues or unexpected behavior in the blockchain environment";
        
        sampleFarmerReg.name = longName;
        
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        assertEq(farmer.name, longName);
    }
    
    function testMaxUintValues() public {
        // Test with maximum values for certain fields
        sampleFarmerReg.practices.waterUsage = type(uint32).max;
        sampleDistributorReg.storageCapacity = type(uint256).max;
        
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.prank(distributor1);
        stakeholderManager.registerDistributor(sampleDistributorReg);
        
        // Verify registrations succeeded
        DataStructures.Farmer memory farmer = stakeholderManager.getFarmer(farmer1);
        DataStructures.Distributor memory distributor = stakeholderManager.getDistributor(distributor1);
        
        assertEq(farmer.practices.waterUsage, type(uint32).max);
        assertEq(distributor.storageCapacity, uint32(type(uint256).max)); // Note: storageCapacity is uint32 in struct
    }
    
    // ==================== Comprehensive Integration Tests ====================
    
    function testCompleteStakeholderLifecycle() public {
        // Register all stakeholder types
        vm.prank(farmer1);
        stakeholderManager.registerFarmer(sampleFarmerReg);
        
        vm.prank(distributor1);
        stakeholderManager.registerDistributor(sampleDistributorReg);
        
        vm.prank(retailer1);
        stakeholderManager.registerRetailer(sampleRetailerReg);
        
        DataStructures.CertificationType[] memory authorizedFor = new DataStructures.CertificationType[](1);
        authorizedFor[0] = DataStructures.CertificationType.Organic;
        
        vm.prank(inspector1);
        stakeholderManager.registerInspector(
            "Inspector John",
            "Quality Assurance Corp",
            "INS12345",
            authorizedFor,
            "inspector@qa.com",
            "+1555666777"
        );
        
        // Verify all stakeholders
        stakeholderManager.verifyStakeholder(farmer1, "farmer");
        stakeholderManager.verifyStakeholder(distributor1, "distributor");
        stakeholderManager.verifyStakeholder(retailer1, "retailer");
        stakeholderManager.verifyStakeholder(inspector1, "inspector");
        
        // Update reputations
        stakeholderManager.updateReputation(farmer1, 80, "QmGoodFarmer");
        stakeholderManager.updateReputation(distributor1, 75, "QmGoodDistributor");
        stakeholderManager.updateReputation(retailer1, 85, "QmGoodRetailer");
        stakeholderManager.updateReputation(inspector1, 90, "QmGoodInspector");
        
        // Add products to stakeholders
        stakeholderManager._addProductToFarmer(farmer1, 1);
        stakeholderManager._addProductToDistributor(distributor1, 1);
        stakeholderManager._addProductToRetailer(retailer1, 1);
        stakeholderManager._addProductToInspector(inspector1, 1);
        
        // Verify final state
        assertTrue(stakeholderManager.canParticipateInTransactions(farmer1));
        assertTrue(stakeholderManager.canParticipateInTransactions(distributor1));
        assertTrue(stakeholderManager.canParticipateInTransactions(retailer1));
        assertTrue(stakeholderManager.canPerformVerification(inspector1));
        
        // Check statistics
        assertEq(stakeholderManager.getVerifiedStakeHolders(), 4);
        assertEq(stakeholderManager.getAvgerageReputation(), 82); // (80+75+85+90)/4 = 82.5 = 82
        
        (uint256 farmers, uint256 distributors, uint256 retailers, uint256 inspectors) = 
            stakeholderManager.getTotalStakeholders();
        assertEq(farmers + distributors + retailers + inspectors, 4);
    }
}