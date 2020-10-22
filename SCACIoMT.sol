pragma solidity ^0.4.26;

contract SCACIoMT {
    
    address administrator;
    
    struct IoMTProperties {
        bytes1 Organization; // the manufacturers of the IoMT devices.
        address[] EOA_MN; // address of the manufacturer nodes managed by a certain organization.
        bytes1[] IoMT_PUF; // hash of the hardware-based Physical Unclonable Function of the IoMT devices used as unique IDs.
    }
    
    struct IoMTDevice {
        address EOA_P; // address of the owner used for ownership verification.
        address EOA_P_D; // address of the IoMT device.
        bytes1 Manuf; // the manufacturer of the device
        bytes1 IoMTPUF; // the hardware-based Physical Unclonable Function of the IoMT device used as a unique ID.
        string data; // encryption of the data generated from the device.
        bytes1 HashFW; // hash of the compiled firmware to ensure the integrity of the device.
        bool isHash_UtoD; // boolean used to check periodically whether the firmware is up to date.
    }

    IoMTDevice[] private IoMTdevices; // array for storing devices managed in the consortium blockchain. 

    IoMTProperties[] private ListofCD; // array for storing certified manufacturers and their devices properties.
    
    address[] private auth_nodes; // list of authorized nodes
    
    mapping (address => address) private Patient_Device;  // mapping between patients and devices.

    // to ensure that the the address of the message sender is the administrator
    modifier onlybyA() {
        require(msg.sender == administrator, "Not the administrator");
        _;
    }

    // to ensure that the address of the message sender is indeed the address of one of the authorized sealers.
    modifier onlyByAN() {
        uint tmp = 0;
        for (uint i = 0; i < auth_nodes.length; i++) {
            if (auth_nodes[i] == msg.sender)
            tmp = 1;
        }
        if (tmp == 0)
        revert('Not an authorized node');
        _; 
    }
    
     modifier onlybyMN(bytes1 org) {
        uint tmp = 0;
        for (uint i = 0; i < ListofCD.length; i++) {
            if (ListofCD[i].Organization == org){
                for (uint j=0; j < ListofCD[i].EOA_MN.length; j++){
                    if (msg.sender == ListofCD[i].EOA_MN[j])
                    tmp = 1;
                }    
            }
        }
        if (tmp == 0)
        revert('Not a manufacturer node');
        _; 
    }
    
    // to ensure that the device firmware is valid before accepting any data.
    modifier ifUp_to_date(uint _IoMTdeviceId) {
        require(IoMTdevices[_IoMTdeviceId].isHash_UtoD == true, "Device has not been validated");
        _;
    }

    // to ensure that the address of the message sender is indeed the address associated to the IoMT device.
    modifier onlyby(uint _IoMTdeviceId) {
        require(IoMTdevices[_IoMTdeviceId].EOA_P_D == msg.sender, "Only by device EOA");
        _;
    }
    
    // the administrator is the node who deployed the smart contract at first
    constructor() public {
        administrator = msg.sender;
    }

    // to update the list of AN
    function update_ListOfAN(address AN_add) public onlybyA() {
        auth_nodes.push(AN_add);
    }
    function update_ListOfOrg(bytes1 _org) public onlybyA(){
        address[] memory a = new address[](1);
        bytes1[] memory b = new bytes1[](1);
        a[0]=0x00;
        b[0]=0x00;
        IoMTProperties memory newCD = IoMTProperties(_org, a, b);
        ListofCD.push(newCD);
        }
    
    // to update the list of MN
    function update_ListOfMN(bytes1 _org, address MN_add) public onlybyA() {
        for (uint i = 0; i < ListofCD.length; i++) {
                if (ListofCD[i].Organization == _org) {
                ListofCD[i].EOA_MN.push(MN_add);
                }
        }
        
    }
    
    // to update the list of certified devices
    function update_ListOfCIoMT(bytes1 _org, bytes1 _PUF) public onlybyMN(_org) {
        for (uint i = 0; i < ListofCD.length; i++) {
            if (ListofCD[i].Organization == _org)
                ListofCD[i].IoMT_PUF.push(_PUF);
        }
    }
    
    function update_MapOfPIoMT(address D_add, address U_add) public onlyByAN(){
        Patient_Device[D_add] = U_add; 
    }
    
    // upon the registration of a new device.
    event Device_auth(uint indexed IoMTID, address indexed PD_EOA, address P_EOA, bytes1 IoMTPUF, bytes1 Hashfirmware, bool ValidHash);

    // used to register the MIoT devices on-chain and saves all paremeters into the storage 
    function auth_Device(address _PEOA, bytes1 _manuf, bytes1 _IoMTPUF, bytes1 _HashFW) public returns (uint) {
        require(Patient_Device[msg.sender] == _PEOA, "Not the right owner");
        uint tmp =0 ;
        for(uint i = 0; i < ListofCD.length; i++){
          if (ListofCD[i].Organization == _manuf){
                for (uint j=0; j < ListofCD[i].IoMT_PUF.length; j++)
                    if (ListofCD[i].IoMT_PUF[j] == _IoMTPUF)
                        tmp = 1;
          }            
        }
        
        if(tmp == 0)
        revert("uncertifed device");
       
        else{
        IoMTDevice memory newIoMTDevice = IoMTDevice(_PEOA, msg.sender, _manuf, _IoMTPUF, "0", _HashFW, false);
        uint IoMTdeviceId = IoMTdevices.push(newIoMTDevice) - 1;

        emit Device_auth(IoMTdeviceId, msg.sender, _PEOA, _IoMTPUF, _HashFW, false);
        return IoMTdeviceId;
        }
    }

    // used to query data from a IoMT device, it's a call function which doesn't change the state of the EVM hence it doesn't require any fees
    function query_Data(uint _IoMTdeviceID) public view onlyByAN() returns(string) {
        return IoMTdevices[_IoMTdeviceID].data;
    }
    
    // emitted if the IoMT firmware hash is valide.
    event Valid(address indexed _DEOA, uint indexed _ID, bytes32 _msg, bool newValue);
    
    // emitted if the IoMT firmware hash is invalide.
    event NotValid(address indexed _DEOA, uint indexed _ID, bytes32 _msg, string url);    
    
    // used to Check if the firmware is up to date.
    function Validate_HashFW(uint _IoMTdeviceID, bytes1 _HashFW, string url) public onlybyMN(IoMTdevices[_IoMTdeviceID].Manuf){
        if (IoMTdevices[_IoMTdeviceID].HashFW == _HashFW) {
        IoMTdevices[_IoMTdeviceID].isHash_UtoD = true;
        emit Valid(IoMTdevices[_IoMTdeviceID].EOA_P_D, _IoMTdeviceID, "Firmware up to date", true);
        }
        else {
        emit NotValid(IoMTdevices[_IoMTdeviceID].EOA_P_D, _IoMTdeviceID, "Invalid Firmware", url);
        }
    }

    // upon each new update of the data
    event IoMTDataUpdated(uint indexed deviceId, bytes32 indexed msg, string newValue);
    
    // upon each update of the IoMT device firmware 
    event FirmwareUpdated(uint indexed deviceId, bytes32 indexed msg, bytes1 newValue);

    function update_Data(uint _IoMTdeviceID, string _newIoMTdata) public onlyby(_IoMTdeviceID) ifUp_to_date(_IoMTdeviceID){
        IoMTdevices[_IoMTdeviceID].data = _newIoMTdata;

        emit IoMTDataUpdated(_IoMTdeviceID, "data updated", _newIoMTdata);
    }

    function update_HashFW(uint _IoMTdeviceID, bytes1 _newHashFW) public onlyby(_IoMTdeviceID) {
        IoMTdevices[_IoMTdeviceID].HashFW = _newHashFW;
        IoMTdevices[_IoMTdeviceID].isHash_UtoD = false;

        emit FirmwareUpdated(_IoMTdeviceID, "firmware updated", _newHashFW);
    }
}