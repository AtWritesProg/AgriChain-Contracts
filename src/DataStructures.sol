//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @title Data Structures for AgriChain
 * @dev This contract defines the data structures used in the AgriChain project.
 */
library DataStructures {
    //Enums for states of various entities

    enum ProductStage {
        Planted, //0
        Growing, //1
        Harvested, //2
        Processed, //3
        PackedAtFarm, //4
        ShippedToDistributor, //5
        ReceivedByDistributor, //6
        ShippedToRetailer, //7
        ReceivedByRetailer, //8
        AvailableForSale, //9
        SoldOut //10

    }

    enum QualityGrade {
        A_Premium, //0
        B_Good, //1
        C_Standard, //2
        D_SubStandard //3

    }

    enum CertificationType {
        Organic,
        FairTrade,
        NonGMO,
        Pesticide_Free,
        Local,
        Rainforest,
        GlobalGAP
    }

    // Structs for storing multiple data points of same thing

    struct Location {
        string name;
        string coordinates;
        string farm_address;
        bytes32 country;
        string region;
    }

    struct Quality {
        QualityGrade grade;
        uint8 score; // Score out of 100
        address inspector; //address of the quality inspector
        uint64 timestamp; //Good Until timestamp
        string testResults; //IPFS hash or Url
        string[] parameters; //e.g., ["pH: 6.5", "Moisture: 12%"]
        uint8[] parameterScores; //e.g., [90, 85]
    }

    struct Price {
        uint128 farmGatePrice; //Price at the farm
        uint128 distributorPrice; //Price at the distributor
        uint128 retailerPrice; //Price at the retailer
        uint128 recommendedRetailPrice;
        bytes32 currency; //Currency code INR
        uint64 lastUpdated; //Timestamp of last price update
    }

    struct FarmingPractices {
        bool isOrganic;
        bool usesPesticides;
        bool usesGMO;
        //5 unused bits
        uint32 waterUsage; //Liters per kg of product
        string soilType; // e.g., "Loamy", "Sandy"
        string[] fertilizersUsed; // e.g., ["Compost", "Manure"]
        string[] pesticidesUsed; // e.g., ["Neem Oil", "Pyrethrin"]
        string[] sustainablePractices; // e.g., ["Crop Rotation", "Cover Cropping"]
    }

    struct Product {
        uint256 id; //Unique Identifier for a product batch
        string name; //Name of the product
        string variety; //e.g., "Basmati", "Roma"
        string category; //e.g., "Grain", "Vegetable"
        //Important Dates and Quantity
        uint128 quantity; //Quantity in kg or grams
        uint64 plantedDate; //Time of Planting
        uint64 harvestDate; //Time of Harvesting
        uint64 expiryDate; //Expiry Date for perishable goods
        uint64 lastUpdated; //Timestamp of last update
        string unit; //Unit of measurement e.g., "kg", "grams"
        //Stakeholder Addresses
        address farmer; //Address of the farmer
        address currentOwner; //Current owner of the product batch
        //Locations
        Location farmLocation; //Location of the farm
        Location currentLocation; //Current location of the product
        //State and Quality
        Quality[] qualityHistory; //Array of quality checks
        CertificationType[] certificationType; //Certifications obtained
        //Pricing and Farming Practices
        Price price; // Pricing Structure
        FarmingPractices practices; //Farming Practices
        //Product Lifecycle Stage
        ProductStage stage; //Current stage in the supply chain
        bool isActive; //Check if the product is active in the supply chain
        uint32 carbonFootprint; //Carbon footprint in grams CO2e per kg of product
        // IPFS References for additional data
        string metadataIPFS; //IPFS hash or URL for additional metadata
        string[] imagesIPFS; //IPFS hash or URL for product images
    }

    struct Transaction {
        uint256 productID; //ID of the product batch
        address from; //Sender address
        address to; //Receiver address
        uint128 quantity; //Quantity transferred
        ProductStage stage; //State at the time of transaction
        uint64 timestamp; //Time of transaction
        uint64 estimatedDelivery; //Estimated arrival time for shipments
        string transactionHash; //Extra details or IPFS hash
        string notes; //Additional notes
        // Location stored in IPFS or off-chain for simplicity
        string locationIPFS; //IPFS hash or URL for location data
    }

    struct Farmer {
        address wallet; //Unique wallet address
        string name; //Farmer's name
        string farmName; //Name of the farm
        Location farmLocation; //Location of the farm
        //Important Information
        uint64 registrationDate; //Date of registration
        uint32 totalHarvest; //Total quantity harvested in kg
        uint8 reputationScore; //Reputation score out of 100
        bool isVerified; //Verification status
        //Contact Information
        string email;
        string phoneNumber;
        //Multiple Farm Arrays
        Location[] additionalFarms; //Array of additional farm locations
        CertificationType[] certifications; //Certifications obtained
        uint256[] productIDs; //Array of product batch IDs
        FarmingPractices practices; //Farming practices
        //IPFS References for detailed data
        string profileIPFS; //IPFS hash or URL for profile details
    }

    struct Distributor {
        address wallet; //Unique Wallet Address
        string name; //Distributor's Name
        string companyName; //Company Name
        string licenseNumber; //Business License Number
        //Important Information
        uint64 registrationDate; //Date of Registration
        uint32 storageCapacity; //Storage capacity in kg
        uint8 reputationScore; //Reputation score out of 100
        bool isVerified; //Verification status
        //Contact Information
        string email;
        string phoneNumber;
        //Multiple Warehouse Arrays
        Location[] warehouses; //Array of warehouse locations
        uint256[] handledProducts; //Handled Product
        string[] specializations; //e.g., ["Grains", "Vegetables"]
        //IPFS References for detailed data
        string profileIPFS; //IPFS hash or URL for profile details
    }

    struct Retailer {
        address wallet; //Unique Wallet Address
        string name; //Retailer's Name
        string storeName; //Store Name
        string licenseNumber; //Buisness License Number
        Location storeLocation; //Location of the store
        //Important Information
        uint64 registrationDate; //Date of Registration
        uint8 reputationScore; //Reputation score out of 100
        bool isVerified; //Verification status
        //Contact Information and more
        string email;
        string phoneNumber;
        string storeType; //e.g., "Grocery", "Supermarket"
        // Multiple Store Arrays
        Location[] additionalStores; //Array of additional store locations
        uint256[] soldProducts; //Array of sold product batch IDs
        //Addtional Details
        string profileIPFS; //IPFS hash or URL for profile details
    }

    struct Inspector {
        address wallet;
        string name;
        string organization; //Organization they represent
        string licenseNumber; //Inspection License Number
        //Important Information
        uint64 registrationDate; //Date of Registration
        uint8 reputationScore; //Reputation score out of 100
        bool isActive; //Active status
        //Contact Information
        string email;
        string phoneNumber;
        // Inspection History
        CertificationType[] authorizedFor; //Certifications they can issue
        uint256[] inspectedProducts; //Array of inspected product batch IDs
        //IPFS References for detailed data
        string profileIPFS; //IPFS hash or URL for profile details
    }

    //Registration Structs for initial registration data

    struct FarmerRegistration {
        string name;
        string farmName;
        Location farmLocation;
        Location[] additionalFarms;
        CertificationType[] certifications;
        string email;
        string phoneNumber;
        FarmingPractices practices;
    }

    struct DistributorRegistration {
        string name;
        string companyName;
        string licenseNumber;
        Location[] warehouses;
        string email;
        string phoneNumber;
        uint256 storageCapacity;
        string[] specializations;
    }

    struct RetailerRegistration {
        string name;
        string storeName;
        string licenseNumber;
        Location storeLocation;
        Location[] additionalStores;
        string email;
        string phoneNumber;
        string storeType;
    }

    //Product Creation Struct for initial product creation data
    struct ProductCreationData {
        string name;
        string variety;
        string category;
        uint128 quantity;
        string unit;
        uint128 plantedDate;
        uint128 harvestDate;
        uint128 expiryDate;
        CertificationType[] certifications;
        string description;
        uint128 farmGatePrice;
        FarmingPractices practices;
    }

    //Transfer Data Struct for initial transfer data
    struct TransferData {
        uint256 productId;
        address to;
        uint128 price;
        ProductStage newStage;
        string transactionHash;
        string notes;
        string locationIPFS;
        uint64 estimatedDelivery;
    }

    // Quality Check Data Struct for initial quality check data
    struct QualityData {
        QualityGrade grade;
        uint8 score; // Score out of 100
        string testResults; //IPFS hash or Url
        string[] parameters; //e.g., ["pH: 6.5", "Moisture: 12%"]
        uint8[] parameterScores; //e.g., [
    }

    //Supply Chain analytics struct for various analytics
    struct SupplyChainAnalytics {
        uint64 totalProducts;
        uint64 activeProducts;
        uint64 totalFarmers;
        uint64 totalDistributors;
        uint64 totalRetailers;
        uint64 totalInspectors;
        uint64 totalTransactions;
        uint64 averageSupplyTime; //in seconds
        uint64 totalCarbonFootprint; //in grams CO2e
        uint64 lastUpdated; //Timestamp of last update
    }

    //Sustainability Metrics struct for various sustainability metrics
    struct SustainabilityMetrics {
        uint64 totalCarbonFootprint; //in grams CO2e
        uint32 organicProductCount; //Number of organic products
        uint32 sustainableFarmsCount; //Number of farms using sustainable practices
        uint32 averageCarbonPerProduct;
        uint64 lastUpdated; //Timestamp of last update
    }

    //Gas Optimization Structs for packing data efficiently
    struct BatchTransferData {
        uint256[] productsID;
        address[] recipients;
        uint128[] prices;
        ProductStage[] newStages;
    }

    struct BatchQualityData {
        uint256[] productsID;
        QualityGrade[] grades;
        uint8[] scores; // Scores out of 100
        string[] testResults; //IPFS hash or Url
    }

    //Event Structs for logging events with detailed data
    struct ProductEvent {
        uint256 productId;
        ProductStage stage;
        address actor; //Who performed the action
        uint64 timestamp;
        string detailsIPFS; //IPFS hash or URL for additional details
    }

    struct StakeholderEvent {
        address stakeholder;
        string eventType; //e.g., "Registration", "Verification"
        uint64 timestamp;
        string detailsIPFS; //IPFS hash or URL for additional details
    }
}
