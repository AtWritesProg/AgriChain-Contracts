//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IAgriChainEvents} from "./IAgriChainEvents.sol";
import {DataStructures} from "./DataStructures.sol";

/**
 * @title Stakeholder Contract
 * @dev Manages stakeholder roles and permissions within the AgriChain System. with IPFS integration for storing stakeholder details.
 */
contract StakeholderManager is AccessControl, Pausable, IAgriChainEvents {
    //Role Definitions
    bytes32 constant ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant FARMER_ROLE = 0x9decc540ed7e12dc756a0a33fd30896853d6f3395609286d2d83d03db68fbac9;
    bytes32 constant DISTRIBUTOR_ROLE = 0x7722e3dbdf7a5417dd23d582ff681776bb661e10ab9355388e1d977817a7a1b5;
    bytes32 constant RETAILER_ROLE = 0xc3ca1c550e48f508639854b12b070ee6611457a1fe9df69a92864114bfc0e5cf;
    bytes32 constant INSPECTOR_ROLE = 0x52d54c20deb3c9c90c1e2b1d66f2c5b1c2c839c7563acb76f7b6cc33fcfea88d;

    struct SystemConfig {
        uint64 farmerRegistrationFee;
        uint64 distributorRegistrationFee;
        uint64 retailerRegistrationFee;
        uint64 inspectorRegistrationFee;
        uint8 minReputationForTransaction;
        uint8 minReputationForVerification;
    }

    SystemConfig public systemConfig;

    //Stakeholder Mappings
    mapping(address => DataStructures.Farmer) public farmers;
    mapping(address => DataStructures.Distributor) public distributors;
    mapping(address => DataStructures.Retailer) public retailers;
    mapping(address => DataStructures.Inspector) public inspectors;

    // Packed Array of all stakeholders(farmers, distributors, retailers, inspectors) for enumeration (gas optimization)
    address[] public allFarmers;
    address[] public allDistributors;
    address[] public allRetailers;
    address[] public allInspectors;

    //Verification and Reputation data
    struct VerificationData {
        bool isVerified;
        uint64 verificationDate;
        address verifiedBy;
        uint8 reputationScore;
    }

    mapping(address => VerificationData) public stakeholderData;

    //Reputation History for IPFS
    mapping(address => string) public reputationHistoryIPFS;

    //Custom Errors
    error AlreadyRegistered();
    error InsufficientFunds();
    error InvalidDataInput();
    error NotRegistered();
    error AlreadyVerified();
    error NotVerified();
    error InvalidReputationScore();

    //Events for Optimizations
    event StakeholderRegistered(address indexed stakeholder, string stakeholderType, string name, uint64 timestamp);

    event VerificationStatusChanged(
        address indexed stakeholder, bool verified, address indexed verifier, uint64 timestamp
    );

    event ReputationScoreUpdated(address indexed stakeholder, uint8 oldScore, uint8 newScore, string ipfsReason);

    //Constructor
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        //Intialize system config
        systemConfig = SystemConfig({
            farmerRegistrationFee: 0,
            distributorRegistrationFee: 0,
            retailerRegistrationFee: 0,
            inspectorRegistrationFee: 0,
            minReputationForTransaction: 30,
            minReputationForVerification: 70
        });
    }

    //===================Optimized Modifier======================
    modifier onlyUnregistered(address _address) {
        if (_isRegistered(_address)) {
            revert AlreadyRegistered();
        }
        _;
    }

    modifier onlyRegistered(address _address) {
        if (!_isRegistered(_address)) revert NotRegistered();
        _;
    }

    modifier meetsRegistrationFee(uint64 _reqFee) {
        if (msg.value < _reqFee) {
            revert InsufficientFunds();
        }
        _;
    }

    //===================Farmer Management======================

    function registerFarmer(DataStructures.FarmerRegistration memory _data)
        external
        payable
        whenNotPaused
        onlyUnregistered(msg.sender)
        meetsRegistrationFee(systemConfig.farmerRegistrationFee)
    {
        if (bytes(_data.name).length == 0 || bytes(_data.farmName).length == 0) {
            revert InvalidDataInput();
        }

        //Farmer struct
        DataStructures.Farmer storage farmer = farmers[msg.sender];
        farmer.wallet = msg.sender;
        farmer.name = _data.name;
        farmer.farmName = _data.farmName;
        farmer.farmLocation = _data.farmLocation;
        farmer.registrationDate = uint64(block.timestamp);
        farmer.isVerified = false;
        farmer.reputationScore = 50;
        farmer.email = _data.email;
        farmer.phoneNumber = _data.phoneNumber;
        farmer.practices = _data.practices;

        //Additonal Farm
        uint256 farmsLength = _data.additionalFarms.length;
        for (uint256 i = 0; i < farmsLength;) {
            farmer.additionalFarms.push(_data.additionalFarms[i]);
            unchecked {
                ++i;
            }
        }

        //Add certifications
        uint256 certificationsLength = _data.certifications.length;
        for (uint256 i = 0; i < certificationsLength;) {
            farmer.certifications.push(_data.certifications[i]);
            unchecked {
                ++i;
            }
        }

        //Update tracking data
        allFarmers.push(msg.sender);
        stakeholderData[msg.sender] =
            VerificationData({isVerified: false, verificationDate: 0, verifiedBy: address(0), reputationScore: 50});

        _grantRole(FARMER_ROLE, msg.sender);

        emit StakeholderRegistered(msg.sender, "farmer", _data.name, uint64(block.timestamp));
        emit FarmerRegistered(msg.sender, _data.name, _data.farmName, _data.farmLocation.name);

        // Refund excess Payment
        if (msg.value > systemConfig.farmerRegistrationFee) {
            payable(msg.sender).transfer(msg.value - systemConfig.farmerRegistrationFee);
        }
    }

    //=================Distributor Management==================

    function registerDistributor(DataStructures.DistributorRegistration memory _data)
        external
        payable
        whenNotPaused
        onlyUnregistered(msg.sender)
        meetsRegistrationFee(systemConfig.farmerRegistrationFee)
    {
        if (bytes(_data.name).length == 0 || bytes(_data.companyName).length == 0) {
            revert InvalidDataInput();
        }

        DataStructures.Distributor storage distributor = distributors[msg.sender];
        distributor.wallet = msg.sender;
        distributor.name = _data.name;
        distributor.companyName = _data.companyName;
        distributor.licenseNumber = _data.licenseNumber;
        distributor.registrationDate = uint64(block.timestamp);
        distributor.reputationScore = 50;
        distributor.isVerified = false;
        distributor.email = _data.email;
        distributor.phoneNumber = _data.phoneNumber;
        distributor.storageCapacity = uint32(_data.storageCapacity);

        //Add warehouses
        uint256 warehouseLength = _data.warehouses.length;
        for (uint256 i = 0; i < warehouseLength;) {
            distributor.warehouses.push(_data.warehouses[i]);
        }

        //Add Specializations
        uint256 specializationLength = _data.specializations.length;
        for (uint256 i = 0; i < specializationLength;) {
            distributor.specializations.push(_data.specializations[i]);
        }

        allDistributors.push(msg.sender);
        stakeholderData[msg.sender] = VerificationData({
            isVerified: false,
            verificationDate: uint64(block.timestamp),
            verifiedBy: address(0),
            reputationScore: 50
        });

        _grantRole(DISTRIBUTOR_ROLE, msg.sender);

        emit StakeholderRegistered(msg.sender, "distributor", _data.name, uint64(block.timestamp));
        emit DistributorRegistered(msg.sender, _data.name, _data.companyName, warehouseLength);

        if (msg.value > systemConfig.distributorRegistrationFee) {
            payable(msg.sender).transfer(msg.value - systemConfig.distributorRegistrationFee);
        }
    }

    //===============Retailer Management====================

    function registerRetailer(DataStructures.RetailerRegistration memory _data)
        external
        payable
        whenNotPaused
        onlyUnregistered(msg.sender)
        meetsRegistrationFee(systemConfig.retailerRegistrationFee)
    {
        if (bytes(_data.name).length == 0 || bytes(_data.storeName).length == 0) {
            revert InvalidDataInput();
        }

        //Retailer struct
        DataStructures.Retailer storage retailer = retailers[msg.sender];
        retailer.wallet = msg.sender;
        retailer.name = _data.name;
        retailer.storeName = _data.storeName;
        retailer.licenseNumber = _data.licenseNumber;
        retailer.storeLocation = _data.storeLocation;
        retailer.registrationDate = uint64(block.timestamp);
        retailer.reputationScore = 50;
        retailer.isVerified = false;
        retailer.email = _data.email;
        retailer.phoneNumber = _data.phoneNumber;
        retailer.storeType = _data.storeType;

        //Add authorized certification efficiently
        uint256 storesLength = _data.additionalStores.length;
        for (uint256 i = 0; i < storesLength;) {
            retailer.additionalStores.push(_data.additionalStores[i]);
        }

        allRetailers.push(msg.sender);
        stakeholderData[msg.sender] =
            VerificationData({isVerified: false, verificationDate: 0, verifiedBy: address(0), reputationScore: 50});

        _grantRole(RETAILER_ROLE, msg.sender);

        emit StakeholderRegistered(msg.sender, "retailer", _data.name, uint64(block.timestamp));
        emit RetailerRegistered(msg.sender, _data.name, _data.storeName, _data.storeLocation.name);

        if (msg.value > systemConfig.retailerRegistrationFee) {
            payable(msg.sender).transfer(msg.value - systemConfig.retailerRegistrationFee);
        }
    }

    // =============== Inspector Management ================

    function registerInspector(
        string memory _name,
        string memory _organization,
        string memory _licenseNumber,
        DataStructures.CertificationType[] memory _authorizedFor,
        string memory _email,
        string memory _phoneNumber
    )
        external
        payable
        whenNotPaused
        onlyUnregistered(msg.sender)
        meetsRegistrationFee(systemConfig.inspectorRegistrationFee)
    {
        if (bytes(_name).length == 0 || bytes(_organization).length == 0) {
            revert InvalidDataInput();
        }

        DataStructures.Inspector storage inspector = inspectors[msg.sender];
        inspector.wallet = msg.sender;
        inspector.name = _name;
        inspector.organization = _organization;
        inspector.licenseNumber = _licenseNumber;
        inspector.registrationDate = uint64(block.timestamp);
        inspector.isActive = false; //Require admin approval
        inspector.email = _email;
        inspector.phoneNumber = _phoneNumber;

        // Add authorized certifications efficiently
        uint256 authLength = _authorizedFor.length;
        for (uint256 i = 0; i < authLength;) {
            inspector.authorizedFor.push(_authorizedFor[i]);
        }

        allInspectors.push(msg.sender);
        stakeholderData[msg.sender] =
            VerificationData({isVerified: false, verificationDate: 0, verifiedBy: address(0), reputationScore: 50});

        emit StakeholderRegistered(msg.sender, "inspector", _name, uint64(block.timestamp));
        emit InspectorRegistered(msg.sender, _name, _organization, _licenseNumber);

        if (msg.value > systemConfig.inspectorRegistrationFee) {
            payable(msg.sender).transfer(msg.value - systemConfig.inspectorRegistrationFee);
        }
    }
    //================ Verification System =================

    function verifyStakeholder(address _stakeholder, string memory _stakeholderType)
        external
        onlyRole(ADMIN_ROLE)
        onlyRegistered(_stakeholder)
    {
        VerificationData storage data = stakeholderData[_stakeholder];
        if (data.isVerified) revert AlreadyVerified();

        data.isVerified = true;
        data.verificationDate = uint64(block.timestamp);
        data.verifiedBy = msg.sender;

        // Update specific stakeholder verification status
        bytes32 typeHash = keccak256(abi.encodePacked(bytes(_stakeholderType)));
        if (typeHash == keccak256(abi.encodePacked("farmer"))) {
            farmers[_stakeholder].isVerified = true;
        } else if (typeHash == keccak256(abi.encodePacked("distributor"))) {
            distributors[_stakeholder].isVerified = true;
        } else if (typeHash == keccak256(abi.encodePacked("retailer"))) {
            retailers[_stakeholder].isVerified = true;
        } else if (typeHash == keccak256(abi.encodePacked("inspector"))) {
            inspectors[_stakeholder].isActive = true;
            _grantRole(INSPECTOR_ROLE, _stakeholder);
        }

        emit VerificationStatusChanged(_stakeholder, true, msg.sender, uint64(block.timestamp));
        emit StakeholderVerified(_stakeholder, _stakeholderType, msg.sender, block.timestamp);
    }

    function revokeVerification(address _stakeholder, string memory _reasonIPFS) external onlyRole(ADMIN_ROLE) {
        VerificationData storage data = stakeholderData[_stakeholder];
        if (!data.isVerified) revert NotVerified();

        data.isVerified = false;

        if (farmers[_stakeholder].wallet != address(0)) {
            farmers[_stakeholder].isVerified = false;
        } else if (distributors[_stakeholder].wallet != address(0)) {
            distributors[_stakeholder].isVerified = false;
        } else if (retailers[_stakeholder].wallet != address(0)) {
            retailers[_stakeholder].isVerified = false;
        } else if (inspectors[_stakeholder].wallet != address(0)) {
            inspectors[_stakeholder].isActive = false;
            _revokeRole(INSPECTOR_ROLE, _stakeholder);
        }

        reputationHistoryIPFS[_stakeholder] = _reasonIPFS;
    }

    //===============Reputation System======================

    function updateReputation(address _stakeholder, uint8 _newScore, string memory _reasonIPFS)
        external
        onlyRole(ADMIN_ROLE)
        onlyRegistered(_stakeholder)
    {
        if (_newScore > 100) revert InvalidReputationScore();

        VerificationData storage data = stakeholderData[_stakeholder];
        uint8 oldScore = data.reputationScore;
        data.reputationScore = _newScore;

        if (farmers[_stakeholder].wallet != address(0)) {
            farmers[_stakeholder].reputationScore = _newScore;
        } else if (distributors[_stakeholder].wallet != address(0)) {
            distributors[_stakeholder].reputationScore = _newScore;
        } else if (retailers[_stakeholder].wallet != address(0)) {
            retailers[_stakeholder].reputationScore = _newScore;
        } else if (inspectors[_stakeholder].wallet != address(0)) {
            inspectors[_stakeholder].reputationScore = _newScore;
        }

        reputationHistoryIPFS[_stakeholder] = _reasonIPFS;

        emit ReputationScoreUpdated(_stakeholder, oldScore, _newScore, _reasonIPFS);
        emit ReputationUpdated(_stakeholder, oldScore, _newScore, "", msg.sender);
    }

    function batchUpdateReputation(address[] memory _stakeholders, uint8[] memory _newScores, string memory _reasonIPFS)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_stakeholders.length == _newScores.length, "Array length mismatch");
        require(_stakeholders.length <= 50, "Too many stakeholders for batch operations");

        for (uint256 i = 0; i < _stakeholders.length;) {
            if (_isRegistered(_stakeholders[i]) && _newScores[i] <= 100) {
                VerificationData storage data = stakeholderData[_stakeholders[i]];
                uint8 oldScore = data.reputationScore;
                data.reputationScore = _newScores[i];

                emit ReputationScoreUpdated(_stakeholders[i], oldScore, _newScores[i], _reasonIPFS);
            }

            unchecked {
                ++i;
            }
        }
    }

    //===============Query Functions=======================

    function getStakeholderType(address _stakeholder) external view returns (string memory) {
        if (farmers[_stakeholder].wallet != address(0)) {
            return "farmer";
        } else if (distributors[_stakeholder].wallet != address(0)) {
            return "distributor";
        } else if (retailers[_stakeholder].wallet != address(0)) {
            return "retailer";
        } else if (inspectors[_stakeholder].wallet != address(0)) {
            return "inspector";
        }
        return "unregistered";
    }

    function isStakeholderVerified(address _stakeholder) external view returns (bool) {
        return stakeholderData[_stakeholder].isVerified;
    }

    function getStakeholderReputation(address _stakeholder) external view returns (uint8) {
        return stakeholderData[_stakeholder].reputationScore;
    }

    function canParticipateInTransactions(address _stakeholder) external view returns (bool) {
        VerificationData memory data = stakeholderData[_stakeholder];
        return data.isVerified && data.reputationScore >= systemConfig.minReputationForTransaction;
    }

    function canPerformVerification(address _stakeholder) external view returns (bool) {
        return inspectors[_stakeholder].isActive
            && stakeholderData[_stakeholder].reputationScore >= systemConfig.minReputationForVerification;
    }

    function getFarmerProducts(address _farmer) external view returns (uint256[] memory) {
        return farmers[_farmer].productIDs;
    }

    function getDistributorProducts(address _distributor) external view returns (uint256[] memory) {
        return distributors[_distributor].handledProducts;
    }

    function getRetailerProducts(address _retailer) external view returns (uint256[] memory) {
        return retailers[_retailer].soldProducts;
    }

    function getInspectorProducts(address _inspector) external view returns (uint256[] memory) {
        return inspectors[_inspector].inspectedProducts;
    }

    function getInspectorAuthorizations(address _inspector)
        external
        view
        returns (DataStructures.CertificationType[] memory)
    {
        return inspectors[_inspector].authorizedFor;
    }

    //=====================Statistics===========================

    function getTotalStakeholders() external view returns (uint256, uint256, uint256, uint256) {
        return (allFarmers.length, allDistributors.length, allRetailers.length, allInspectors.length);
    }

    function getVerifiedStakeHolders() external view returns (uint256) {
        uint256 verified = 0;

        assembly {
            let farmersLen := sload(allFarmers.slot)
            let distributorsLen := sload(allDistributors.slot)
            let inspectorsLen := sload(allInspectors.slot)
            let retailersLen := sload(allRetailers.slot)
        }

        for (uint256 i = 0; i < allFarmers.length;) {
            if (stakeholderData[allFarmers[i]].isVerified) {
                verified++;
            }
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < allDistributors.length;) {
            if (stakeholderData[allDistributors[i]].isVerified) {
                verified++;
            }
            unchecked {
                ++i;
            }
        }
        for (uint256 i = 0; i < allRetailers.length;) {
            if (stakeholderData[allRetailers[i]].isVerified) {
                verified++;
            }
            unchecked {
                ++i;
            }
        }
        for (uint256 i = 0; i < allInspectors.length;) {
            if (stakeholderData[allInspectors[i]].isVerified) {
                verified++;
            }
            unchecked {
                ++i;
            }
        }

        return verified;
    }

    function getAvgerageReputation() external view returns (uint256) {
        uint256 totalStakeholders =
            allFarmers.length + allDistributors.length + allRetailers.length + allInspectors.length;

        if (totalStakeholders == 0) {
            return 0;
        }

        uint256 totalReputation = 0;

        for (uint256 i = 0; i < allFarmers.length;) {
            totalReputation += stakeholderData[allFarmers[i]].reputationScore;
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < allDistributors.length;) {
            totalReputation += stakeholderData[allDistributors[i]].reputationScore;
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < allRetailers.length;) {
            totalReputation += stakeholderData[allRetailers[i]].reputationScore;
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < allInspectors.length;) {
            totalReputation += stakeholderData[allFarmers[i]].reputationScore;
            unchecked {
                ++i;
            }
        }

        return totalReputation / totalStakeholders;
    }

    //===================Admin Functions=======================

    function setRegistrationFees(uint64 _farmerFee, uint64 _distributorFee, uint64 _retailerFee, uint64 _inspectorFee)
        external
        onlyRole(ADMIN_ROLE)
    {
        systemConfig.farmerRegistrationFee = _farmerFee;
        systemConfig.distributorRegistrationFee = _distributorFee;
        systemConfig.retailerRegistrationFee = _retailerFee;
        systemConfig.inspectorRegistrationFee = _inspectorFee;
    }

    function setReputationThresholds(uint8 _minForTransactions, uint8 _minForVerification)
        external
        onlyRole(ADMIN_ROLE)
    {
        systemConfig.minReputationForTransaction = _minForTransactions;
        systemConfig.minReputationForVerification = _minForVerification;
    }

    function pauseContract() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpauseContract() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function withdrawFees(address payable _to) external onlyRole(ADMIN_ROLE) {
        require(_to != address(0), "Invalid Address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No Fund to Withdraw");
        _to.transfer(balance);
    }

    //===============Internal Functions=====================
    function _addProductToFarmer(address _farmer, uint256 _productId) external onlyRole(ADMIN_ROLE) {
        farmers[_farmer].productIDs.push(_productId);
        farmers[_farmer].totalHarvest += 1;
    }

    function _addProductToDistributor(address _distributor, uint256 _productId) external onlyRole(ADMIN_ROLE) {
        distributors[_distributor].handledProducts.push(_productId);
    }

    function _addProductToRetailer(address _retailer, uint256 _productId) external onlyRole(ADMIN_ROLE) {
        retailers[_retailer].soldProducts.push(_productId);
    }

    function _addProductToInspector(address _inspector, uint256 _productId) external onlyRole(ADMIN_ROLE) {
        inspectors[_inspector].inspectedProducts.push(_productId);
    }

    function _isRegistered(address _stakeholder) internal view returns (bool) {
        return farmers[_stakeholder].wallet != address(0) || distributors[_stakeholder].wallet != address(0)
            || retailers[_stakeholder].wallet != address(0) || inspectors[_stakeholder].wallet != address(0);
    }

    function getFarmer(address _farmer) external view returns (DataStructures.Farmer memory) {
        return farmers[_farmer];
    }
}
