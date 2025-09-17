//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title IPFS Storage Contract 
 * @dev Manages IPFS hash storage for Agricultural supply chain data
 */

contract IPFSStorage is AccessControl,Pausable {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPLOADER_ROLE = keccak256("UPLOADER_ROLE");

    struct IPFSRecord {
        string hash;
        address uploader;
        uint64 timestamp;
        uint32 fileSize;
        bool isActive;
    }

    // Product Metadata and files
    mapping(uint256 => string) public productMetadata;   //Product ID to IPFS hash
    mapping(uint256 => string[]) public productImages;    // Product ID to array of image hash
    mapping(uint256 => mapping(string => string)) public productDocuments;  // Product id to documenttype to ipfs hash
    mapping(uint256 => string[]) public productDocumentTypes;

    // Stakeholder documents
    mapping(address => string) public stakeholderProfiles;    // stakeholder => profile IPFS hash
    mapping(address => mapping(string => string)) public stakeholderDocuments; // stakeholder => docType => IPFS hash
    
    //IPFS pin tracking for cleanup
    mapping(string => IPFSRecord) public ipfsRecords;
    mapping(address => string[]) public uploaderRecords;

    // System statistics
    uint256 public totalFilesStored;
    uint256 public totalStorageUsed;

    //Events 
    event ProductMetadataStored(uint256 indexed productId, string ipfsHash, address indexed uploader);
    event ProductImagesAdded(uint256 indexed productId, uint256 imageCount, address indexed uploader);
    event ProductDocumentAdded(uint256 indexed productId, string documentType, string ipfsHash);
    event ProductDocumentsBatchAdded(uint256 indexed productId, uint256 documentCount, address indexed uploader);
    event StakeholderProfileUpdated(address indexed stakeholder, string ipfsHash);
    event StakeholderDocumentAdded(address indexed stakeholder, string documentType, string ipfsHash);
    event IPFSRecordCreated(string indexed ipfsHash, address indexed uploader, uint32 fileSize);
    event IPFSRecordDeactivated(string indexed ipfsHash, address indexed deactivatedBy);

    //Custom Errors
    error InvalidIPFSHash();
    error RecordNotFound();
    error ArrayLengthMismatch();
    error TooManyItemsAtOnce();
    error NoItemsProvided();
    error Unauthorized();
    
    //Constructor
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPLOADER_ROLE, msg.sender);
    }

    // ====================PRODUCT METADATA MANAGEMENT=========================

    function storeProductMetadata(uint256 _productId, string memory _ipfsHash) external whenNotPaused {
        if (!isValidIPFSHash(_ipfsHash)) revert InvalidIPFSHash();

        productMetadata[_productId] = _ipfsHash;
        
        _createIPFSRecord(_ipfsHash, 50000); // ~50KB for JSON metadata

        emit ProductMetadataStored(_productId, _ipfsHash, msg.sender);
    }

    function addProductImages(
        uint256 _productId,
        address _uploader,
        string[] memory _ipfsHashes
    ) external whenNotPaused onlyRole(UPLOADER_ROLE) {
        uint256 length = _ipfsHashes.length;
        if (length == 0) revert NoItemsProvided();
        if (length > 10) revert TooManyItemsAtOnce();

        for (uint256 i = 0; i < length;) {
            if (!isValidIPFSHash(_ipfsHashes[i])) revert InvalidIPFSHash();

            productImages[_productId].push(_ipfsHashes[i]);
            _createIPFSRecord(_ipfsHashes[i], 2000000); // 2 MB

            unchecked { ++i; }
        }

        emit ProductImagesAdded(_productId, length, _uploader);
    }

    function addProductDocuments(
        uint256 _productId,
        address _uploader,
        string[] memory _documentHashes,
        string[] memory _documentTypes
    ) external whenNotPaused onlyRole(UPLOADER_ROLE) {
        if (_documentHashes.length != _documentTypes.length) revert ArrayLengthMismatch();
        if (_documentHashes.length == 0) revert NoItemsProvided();
        if (_documentHashes.length > 5) revert TooManyItemsAtOnce();

        uint256 length = _documentHashes.length;
        for (uint256 i = 0; i < length;) {
            if (!isValidIPFSHash(_documentHashes[i])) revert InvalidIPFSHash();

            string memory docType = _documentTypes[i];
            productDocuments[_productId][docType] = _documentHashes[i];

            if (!_documentTypeExists(_productId, docType)) {
                productDocumentTypes[_productId].push(docType);
            }

            _createIPFSRecord(_documentHashes[i], 1000000); // ~1MB for documents
            
            emit ProductDocumentAdded(_productId, docType, _documentHashes[i]);
            
            unchecked { ++i; }
        }

        emit ProductDocumentsBatchAdded(_productId, length, _uploader);
    }

    // =======================Stakeholder data management=================
    /**
     * @dev Update stakeholder profile ipfs hash
     */
    function updateStakeholderProfile(
        address _stakeholder,
        string memory _ipfsHash
    ) external whenNotPaused {
        if (msg.sender != _stakeholder && !hasRole(ADMIN_ROLE, msg.sender)) revert Unauthorized();
        if(!isValidIPFSHash(_ipfsHash)) revert InvalidIPFSHash();

        stakeholderProfiles[_stakeholder] = _ipfsHash;
        _createIPFSRecord(_ipfsHash, 10000); // ~10KB for profile

        emit StakeholderProfileUpdated(_stakeholder, _ipfsHash);
    }

    function addStakeholderDocument(
        address _stakeholder, 
        string memory _documentType, 
        string memory _ipfsHash
    ) external whenNotPaused {
        if (msg.sender != _stakeholder && !hasRole(ADMIN_ROLE, msg.sender)) revert Unauthorized();
        if (!isValidIPFSHash(_ipfsHash)) revert InvalidIPFSHash();
        
        stakeholderDocuments[_stakeholder][_documentType] = _ipfsHash;
        _createIPFSRecord(_ipfsHash, 500000); // ~500KB for documents
        
        emit StakeholderDocumentAdded(_stakeholder, _documentType, _ipfsHash);
    }

    // ======================Query Functions=========================
    
    /**
     * @dev Get all IPFS data for a product
     */
    function getProductIPFSData(uint256 _productId) external view returns (
        string[] memory images, 
        string memory metadata
    ) {
        return (productImages[_productId], productMetadata[_productId]);
    }

    /**
     * @dev Get specific document for a product
     */
    function getProductDocument(uint256 _productId, string memory _documentType) external view returns (string memory) {
        return productDocuments[_productId][_documentType];
    }

    /**
     * @dev Get all document types for a product
     */
    function getProductDocumentTypes(uint256 _productId) external view returns (string[] memory) {
        return productDocumentTypes[_productId];
    }

    /**
     * @dev Get all images for a product
     */
    function getProductImages(uint256 _productId) external view returns (string[] memory) {
        return productImages[_productId];
    }

    /**
     * @dev Get stakeholder profile
     */
    function getStakeholderProfile(address _stakeholder) external view returns (string memory) {
        return stakeholderProfiles[_stakeholder];
    }

    /**
     * @dev Get stakeholder document by type
     */
    function getStakeholderDocument(address _stakeholder, string memory _documentType) external view returns (string memory) {
        return stakeholderDocuments[_stakeholder][_documentType];
    }

    /**
     * @dev Get all records uploaded by a specific address
     */
    function getUploaderRecords(address _uploader) external view returns (string[] memory) {
        return uploaderRecords[_uploader];
    }

    /**
     * @dev Get IPFS record details
     */
    function getIPFSRecord(string memory _ipfsHash) external view returns (IPFSRecord memory) {
        return ipfsRecords[_ipfsHash];
    }

    /**
     * @dev Get system statistics
     */
    function getSystemStats() external view returns (uint256 totalFiles, uint256 totalStorage) {
        return (totalFilesStored, totalStorageUsed);
    }

    //=======================Admin Functions========================
    
    /**
     * @dev Deactivate a single IPFS record
     */
    function deactivateIPFSRecord(string memory _ipfsHash) external onlyRole(ADMIN_ROLE) {
        IPFSRecord storage record = ipfsRecords[_ipfsHash];
        if (bytes(record.hash).length == 0) revert RecordNotFound();
        
        record.isActive = false;
        emit IPFSRecordDeactivated(_ipfsHash, msg.sender);
    }

    /**
     * @dev Batch deactivate multiple IPFS records
     */
    function batchDeactivateRecords(string[] memory _ipfsHashes) 
        external onlyRole(ADMIN_ROLE) {
        uint256 length = _ipfsHashes.length;
        if (length > 50) revert TooManyItemsAtOnce();
        
        for (uint256 i = 0; i < length;) {
            IPFSRecord storage record = ipfsRecords[_ipfsHashes[i]];
            if (bytes(record.hash).length > 0) {
                record.isActive = false;
                emit IPFSRecordDeactivated(_ipfsHashes[i], msg.sender);
            }
            unchecked { ++i; }
        }
    }

    /**
     * @dev Grant uploader role to an address
     */
    function grantUploaderRole(address _uploader) external onlyRole(ADMIN_ROLE) {
        _grantRole(UPLOADER_ROLE, _uploader);
    }

    /**
     * @dev Revoke uploader role from an address
     */
    function revokeUploaderRole(address _uploader) external onlyRole(ADMIN_ROLE) {
        _revokeRole(UPLOADER_ROLE, _uploader);
    }

    /**
     * @dev Pause the contract
     */
    function pauseContract() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpauseContract() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // =======================Internal Functions==========================
    
    function isValidIPFSHash(string memory _hash) public pure returns (bool) {
        bytes memory hashBytes = bytes(_hash);
        uint256 length = hashBytes.length;

        // IPFS v0 hash starts with 'Qm' and are 46 characters long
        if (length == 46) {
            return hashBytes[0] == "Q" && hashBytes[1] == "m";
        } 
        // IPFS v1 hashes start with 'b' and are typically 59 characters long
        else if (length == 59) {
            return hashBytes[0] == "b";
        }
        // Other CID formats (base32, base58btc)
        else if (length >= 50 && length <= 62) {
            return hashBytes[0] == "z" || hashBytes[0] == "f";
        }

        return false;
    }

    function _createIPFSRecord(string memory _ipfsHash, uint32 _estimatedSize) internal {
        // Check if already exists
        if (bytes(ipfsRecords[_ipfsHash].hash).length > 0) {
            return;
        }

        ipfsRecords[_ipfsHash] = IPFSRecord({
            hash: _ipfsHash,
            uploader: msg.sender,
            timestamp: uint64(block.timestamp),
            fileSize: _estimatedSize,
            isActive: true
        });

        uploaderRecords[msg.sender].push(_ipfsHash);

        // Update Statistics
        unchecked {
            totalFilesStored++;
            totalStorageUsed += _estimatedSize;
        }

        emit IPFSRecordCreated(_ipfsHash, msg.sender, _estimatedSize);
    }

    function _documentTypeExists(uint256 _productId, string memory _documentType) internal view returns (bool) {
        string[] memory types = productDocumentTypes[_productId];
        uint256 length = types.length;

        for (uint256 i = 0; i < length;) {
            if(keccak256(bytes(types[i])) == keccak256(bytes(_documentType))) {
                return true;
            }
            unchecked { ++i; }
        }
        return false;
    }
}