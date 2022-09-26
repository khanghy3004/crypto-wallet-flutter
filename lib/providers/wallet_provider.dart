
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

List<String> contractAddress  = ['0x280b2e8b297e15467bc1929941b5439ec67fc145', '0xc56e3b597856333a2ccd37c4a77421da141ff3be'];

final walletProvider = ChangeNotifierProvider((ref) => WalletProvider());

class WalletProvider extends ChangeNotifier {
  late final Web3Client _web3client;
  late final Credentials _credentials;
  late DeployedContract _contract;
  late final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  // Contract RPC API
  ContractEvent _transferEvent() => _contract.event('Transfer');
  ContractFunction _balanceFunction() => _contract.function('balanceOf');
  ContractFunction _sendFunction() => _contract.function('transfer');

  // TODO: Replace publicAddress with Wallet model in future.
  late final String _publicAddress;
  late final EthereumAddress _ethereumAddress;

  late BigInt _ethBalance;
  late BigInt _tokenBalance;

  bool _loading = false;

  String get publicAddress => _publicAddress;

  bool get loading => _loading;

  BigInt get ethBalance => _ethBalance;

  BigInt get tokenBalance => _tokenBalance;

  Future<void> initialiseWallet() async {
    setBusy(true);

    await _initialiseClient();
    await _initialiseCredentials();
    await initialiseContract();
    await refreshBalance();

    setBusy(false);
  }

  Future<void> refreshBalance() async {
    setBusy(true);

    await _getEthBalance(_ethereumAddress);
    await _getTokenBalance(_ethereumAddress);

    setBusy(false);
  }

  Future<String> sendToken(String to, String val) async {
    EthereumAddress toAddress = EthereumAddress.fromHex(to);
    BigInt amount = BigInt.from(int.parse(val) * pow(10, 18));

    String txBlockHash = await _web3client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: _sendFunction(),
        parameters: [toAddress, amount],
      ),
      chainId: 97,
    );
    return txBlockHash;
  }

  Future<void> addToken(String address) async { 
    contractAddress[0] = address;
    _prefs.then((prefs) => prefs.setString('contractAddress', address));
  }

  void setBusy(bool val) {
    if (_loading == val) return;
    _loading = val;
    notifyListeners();
  }

  Future<void> _getEthBalance(EthereumAddress from) async {
    EtherAmount etherAmount = await _web3client.getBalance(from);
    _ethBalance = etherAmount.getInWei;
  }

  Future<void> _getTokenBalance(EthereumAddress from) async {
    final response = await _web3client.call(
        contract: _contract, function: _balanceFunction(), params: [from]);
    _tokenBalance = response.first;
  }

  Future<void> _initialiseClient() async {
    // Initialse Web3 client
    _web3client = Web3Client(
      dotenv.env['RPC_URL']!,
      http.Client(),
    );
  }

  Future<void> _initialiseCredentials() async {
    // Initialise Credentials
    _credentials = EthPrivateKey.fromHex(dotenv.env['WALLET_PRIVATE_KEY']!);
    await _updatePublicAddress();
  }

  Future<void> initialiseContract() async {
    // Initialise Deployed Contract
    final abiString = await rootBundle.loadString('assets/abi/abi.json');
    final ContractAbi abi = ContractAbi.fromJson(abiString, 'BUSD');
    var pref = await _prefs;
    String _contractAddress = pref.getString('contractAddress').toString().length == 42 ? pref.getString('contractAddress').toString() : contractAddress[0];
    developer.log(pref.getString('contractAddress').toString().length.toString());
    _contract = DeployedContract(abi, EthereumAddress.fromHex(_contractAddress));
  }

  Future<void> _updatePublicAddress() async {
    EthereumAddress address = await _credentials.extractAddress();
    _ethereumAddress = address;
    _publicAddress = address.hex;
  }

  @override
  dispose() async {
    await _web3client.dispose();
    super.dispose();
  }
}
