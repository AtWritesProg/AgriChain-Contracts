//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DataStructures} from "./DataStructures.sol";

/**
 * @title AgriChainEvents Interface
 * @dev Centralized event definitions for AgriChain smart contracts.
 */
interface IAgriChainEvents {
    //  ========================Product Events========================

    /**
     * @dev Emitted when a new product is created by farmer
     * @param productId The Unique ID of product
     * @param farmer Address of Farmer
     * @param name Name of the product
     * @param category Category of the product (Fruit, Vegetable,Grain etc.)
     * @param quantity Quantity of the products
     */
    event ProductCreated(
        uint256 indexed productId, address indexed farmer, string name, string category, uint256 quantity
    );

    /**
     * @dev Emitted when a product moves to a new stage in the supply chain
     * @param productId The Unique ID of product
     * @param prevStage Previous stage of the product
     * @param newStage New Stage of the product
     * @param updatedBy Address of the entity updating the stage
     * @param timestamp Timestamp of the stage update
     */
    event ProductStageUpdated(
        uint256 indexed productId,
        DataStructures.ProductStage prevStage,
        DataStructures.ProductStage newStage,
        address indexed updatedBy,
        uint256 timestamp
    );

    /**
     * @dev Emitted when product location is Updated
     * @param productId The Unique ID of Product
     * @param prevLocation Previous Location of the product
     * @param newLocation New Location of the product
     * @param coordinates Coordinates of the new location
     * @param updatedBy Address of the entity updating the location
     */
    event ProductLocationUpdated(
        uint256 indexed productId,
        string prevLocation,
        string newLocation,
        string coordinates,
        address indexed updatedBy
    );

    /**
     * @dev Emitted when product's quality is Updated
     * @param productId The Unique ID of Product
     * @param grade Quality Grade of the product
     * @param score Quality Score of the product
     * @param inspector Address of the inspector
     * @param timestamp When the quality was updated
     */
    event QualityRecorced(
        uint256 indexed productId,
        DataStructures.QualityGrade grade,
        uint8 score,
        address indexed inspector,
        uint256 timestamp
    );

    // ========================Trasnsaction Events=========================

    /**
     * @dev Emitted when a product is transferred between stakeholders
     * @param productId The Unique ID of Product
     * @param from Address of the sender
     * @param to Address of the receiver
     * @param price Price at which the product is transferred
     * @param quantity Quantity of the product transferred
     * @param stage Stage of the product during transfer
     */
    event ProductTransferred(
        uint256 indexed productId,
        address indexed from,
        address indexed to,
        uint256 price,
        uint256 quantity,
        DataStructures.ProductStage stage
    );

    /**
     * @dev Emitted when product pricing is updated
     * @param productId The Unique ID of Product
     * @param priceType Type of price updated - FarmerPrice, DistributorPrice, RetailPrice
     * @param oldPrice Previous price of the product
     * @param newPrice New price of the product
     * @param updatedBy Address of the entity updating the price
     */
    event PriceUpdated(
        uint256 indexed productId,
        string priceType,
        uint256 oldPrice,
        uint256 indexed newPrice,
        address indexed updatedBy
    );

    // ========================Stakeholder Events========================

    /**
     * @dev Emitted when a new farmer is registered
     * @param farmer Address of wallet of farmer
     * @param name Name of the farmer
     * @param farmName Name of the farm
     * @param location Location of the farm
     */
    event FarmerRegistered(address indexed farmer, string name, string farmName, string location);

    /**
     * @dev Emitted when a new distributor is registered
     * @param distributor Address of the wallet of distributor
     * @param name Name of the distributor
     * @param companyName Name of the company
     * @param warehouseCount Number of warehouses owned by the distributor
     */
    event DistributorRegistered(address indexed distributor, string name, string companyName, uint256 warehouseCount);

    /**
     * @dev Emitted when a new retailer is registered
     * @param retailer Address of the wallet of retailer
     * @param name Name of the retailer
     * @param storeName Name of the shop
     * @param location Location of the shop
     */
    event RetailerRegistered(address indexed retailer, string name, string storeName, string location);

    /**
     * @dev Emitted when a new quality inspector is registered
     * @param inspector Address of the wallet of inspector
     * @param name Name of the inspector
     * @param organization Organization the inspector is affliateed with
     * @param licenseNumber License number of the inspector
     */
    event InspectorRegistered(address indexed inspector, string name, string organization, string licenseNumber);

    /**
     * @dev Emitted when a stakeholder is verified by admin
     * @param stakeholder Address of stakeholder
     * @param stakeHolderType Type of Holder - farmer,retailer,distributor
     * @param verifiedBy Admin address that performed verification
     * @param timestamp When verification occurred
     */
    event StakeholderVerified(
        address indexed stakeholder, string stakeHolderType, address verifiedBy, uint256 timestamp
    );

    /**
     * @dev Emitted when a stakeholder's reputation score is updated
     * @param stakeholder Address of stakeholder
     * @param oldScore Prev reputation score
     * @param newScore New reputation score
     * @param reason Reason of update
     * @param updatedBy Address of the entity that updated the score
     */
    event ReputationUpdated(
        address indexed stakeholder, uint8 oldScore, uint8 indexed newScore, string reason, address indexed updatedBy
    );

    // ====================Certification Events======================
    /**
     * @dev Emitted when a product recieves a new certifiaction
     * @param productId Product identifier
     * @param certificationType Type of Certification
     * @param certifiedBy Address that provided certification
     * @param expiryDate When the certification expires
     */
    event ProctuctCertified(
        uint256 indexed productId,
        DataStructures.CertificationType indexed certificationType,
        address indexed certifiedBy,
        uint256 expiryDate
    );

    /**
     * @dev Emitted when a farmer recieves a new certification
     * @param farmer Farmer's address
     * @param certificationType type of certification
     * @param certifiedBy Address that provided certification
     * @param expiryDate When the certification expires
     */
    event FarmerCertified(
        address indexed farmer,
        DataStructures.CertificationType indexed certificationType,
        address indexed certifiedBy,
        uint256 expiryDate
    );

    //======================System Events========================

    /**
     * @dev Emitted when system config is updated
     * @param parameter Parameter that was updated
     * @param oldValue Previous Value
     * @param newValue New Value
     * @param updatedBy Admin address that made the update
     */
    event systemConfigUpdated(string parameter, string oldValue, string newValue, address indexed updatedBy);

    /**
     * @dev Emitted when the contract is paused or unpaused
     * @param paused whether the contract is now paused 0-1
     * @param pausedBy Address od the person that paused it
     * @param timestamp Time when the action occured
     */
    event ContractPausedStatusChanged(bool indexed paused, address indexed pausedBy, uint256 timestamp);

    /**
     * @dev Emitted when Emergency actions are taken
     * @param action description of the emergency action
     * @param affectedEntity Address or ID of affectwed entity
     * @param executedBy Address of Admin that carried the action
     * @param timestamp Time of of   Action
     */
    event EmergencyActionExecuted(string action, string affectedEntity, address indexed executedBy, uint256 timestamp);

    //===================Analytics Events=================

    /**
     * @dev Emitted when supply chain metrics are updated
     * @param totalProducts Current total number of products
     * @param totalStakeholders Current total number of stakeholder
     * @param averageSupplyTime Average time from farm to retail
     * @param updatedAt when metrics were calculated
     */
    event SupplyChainMetricsUpdated(
        uint256 totalProducts, uint256 totalStakeholders, uint256 averageSupplyTime, uint256 updatedAt
    );

    /**
     * @dev Emitted when a sustainability milestone is reached
     * @param milestone Description of the milestone
     * @param value Numerical value of the milestone
     * @param unit Unit of measurement
     * @param achievedAt When the milestone was achieved
     */
    event SustainabilityMilestone(string milestone, uint256 indexed value, string unit, uint256 achievedAt);
}
