import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_crypto_wallet/providers/base_view_model.dart';
import 'package:my_crypto_wallet/providers/wallet_provider.dart';

final walletPageViewModel =
    ChangeNotifierProvider((ref) => WalletPageViewModel(ref.read));

mixin WalletPageView {
  showAlertDialog(String message, String url);
}

class WalletPageViewModel extends BaseViewModel<WalletPageView> {
  final Reader _reader;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController toController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  final FocusNode toFocusNode = FocusNode();
  final FocusNode amountFocusNode = FocusNode();

  WalletPageViewModel(this._reader) {
    FocusManager.instance.addListener(_focusListener);
  }

  Future<void> send() async {
    if (formKey.currentState!.validate()) {
      toFocusNode.unfocus();
      amountFocusNode.unfocus();
      loading = true;

      String txBlockHash =
          await _reader(walletProvider).sendToken(toController.text, amountController.text);
      toController.clear();
      amountController.clear();

      loading = false;

      print(txBlockHash);
      String url = "https://testnet.bscscan.com/tx/$txBlockHash";
      String message =
          "Tx block hash: $txBlockHash\nIt might take a while for transaction to complete. You can track the progress on BscScan.";

      view!.showAlertDialog(message, url);
    }
  }

  String? addressValidator(String? val) {
    if (val!.isEmpty) return "Add receiver's address.";
    return null;
  }

  String? amountValidator(String? val) {
    if (val!.isEmpty) return "Add integer amount.";
    return null;
  }

  void _focusListener() {
    notifyListeners();
  }

  @override
  void dispose() {
    toFocusNode.dispose();
    toController.dispose();
    FocusManager.instance.removeListener(_focusListener);
    super.dispose();
  }
}
