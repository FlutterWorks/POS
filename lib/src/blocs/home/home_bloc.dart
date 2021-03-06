import 'package:bloc/bloc.dart';
import 'package:dart_wom_connector/dart_wom_connector.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:flutter/material.dart';
import 'package:pos/src/blocs/home/home_event.dart';
import 'package:pos/src/blocs/home/home_state.dart';
import 'package:pos/src/db/app_database/app_database.dart';
import 'package:pos/src/db/payment_database/payment_database.dart';
import 'package:pos/src/model/payment_request.dart';
import 'package:pos/src/services/aim_repository.dart';
import 'package:pos/src/services/user_repository.dart';
import 'package:pos/src/utils.dart';

import '../../../app.dart';
import '../../my_logger.dart';

import '../../extensions.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  TextEditingController amountController = TextEditingController();
  AimRepository _aimRepository;
  PaymentDatabase _requestDb;
  UserRepository userRepository;
  HomeBloc({this.userRepository}) {
    _aimRepository = AimRepository();
    _requestDb = PaymentDatabase.get();
    //TODO spostare aggiornamento aim in appBloc
    _aimRepository.updateAim(database: AppDatabase.get().getDb()).then((aims) {
      logger.i("HomeBloc: updateAim in costructor: $aims");
    });
  }

  clear() {
    _selectedPosId = null;
    _selectedMerchantId = null;
  }

  String _selectedPosId;
  String _selectedMerchantId;

  List<Merchant> get merchants => globalUser?.merchants ?? <Merchant>[];
  List<PointOfSale> get posList => selectedMerchant?.posList ?? <PointOfSale>[];

  bool get isOnlyOneMerchantAndPos =>
      merchants.length == 1 && posList.length <= 1;

  bool get posSelectionEnabled =>
      merchants.isNotEmpty && !isOnlyOneMerchantAndPos;

  Merchant get selectedMerchant => _selectedMerchantId.isNotNullAndNotEmpty
      ? merchants.firstWhere((m) => m.id == _selectedMerchantId,
          orElse: () => null)
      : merchants.isNotEmpty ? merchants.first : null;

  PointOfSale get selectedPos => _selectedPosId.isNotNullAndNotEmpty
      ? posList?.firstWhere((p) => p.id == _selectedPosId, orElse: () => null)
      : posList.isNotEmpty ? posList.first : null;

//String get selectedPosId => selectedPos.id;

  @override
  HomeState get initialState => RequestLoading();

  checkAndSetPreviousSelectedMerchantAndPos() async {
    //Check previous merchant and pos selected
    final lastMerchantAndPosIdUsed =
        await userRepository.readLastMerchantIdAndPosIdUsed();
    if (lastMerchantAndPosIdUsed != null &&
        lastMerchantAndPosIdUsed.length == 2) {
      final merchantId = lastMerchantAndPosIdUsed[0];
      final posId = lastMerchantAndPosIdUsed[1];
      if (merchantId.isNotNullAndNotEmpty) {
        _selectedMerchantId = merchantId;
        if (posId.isNotNullAndNotEmpty) {
          _selectedPosId = posId;
        }
      }
    }
  }

  void setMerchantAndPosId(String merchantId, String posId) {
    if (posId != _selectedPosId) {
      userRepository.saveMerchantAndPosIdUsed(posId, merchantId);
      _selectedMerchantId = merchantId;
      _selectedPosId = posId;
      add(LoadRequest());
    }
  }

  @override
  Stream<HomeState> mapEventToState(event) async* {
    if (event is LoadRequest) {
      if (merchants.isEmpty) {
        yield NoMerchantState();
        return;
      } else if (posList.isEmpty) {
        yield NoPosState();
        return;
      }

      var aims = await _aimRepository.getFlatAimList(
          database: AppDatabase.get().getDb());

      try {
        final lastCheck = await getLastAimCheckDateTime();
        final aimsAreOld = DateTime.now().difference(lastCheck).inHours > 5;
        //Se non ho gli aim salvati nel db o sono vecchi li scarico da internet
        if (aims == null || aims.isEmpty || aimsAreOld) {
          if (await DataConnectionChecker().hasConnection) {
            // final repo = AppRepository();
            logger.i("HomeBloc: trying to update Aim from internet");
            aims = await _aimRepository.updateAim(
                database: AppDatabase.get().getDb());
            await setAimCheckDateTime(DateTime.now());
          } else {
            logger.i("Aims null or empty and No internet connection");
            yield NoDataConnectionState();
            return;
          }
        }

        logger.i('aim letti : ${aims.length}');

        if (selectedPos != null) {
          final List<PaymentRequest> requests =
              await _requestDb.getRequestsByPosId(selectedPos.id);
          for (PaymentRequest r in requests) {
            final Aim aim = aims.firstWhere((a) {
              return a.code == r.aimCode;
            }, orElse: () {
              return null;
            });
            r.aim = aim;
          }
          yield RequestLoaded(requests: requests);
        } else {
          yield NoPosState();
        }
      } catch (ex) {
        logger.i(ex.toString());
        yield RequestsLoadingErrorState('somethings_wrong');
      }
    }
  }

  Future<int> deleteRequest(int id) async {
    return await _requestDb.deleteRequest(id);
  }

  @override
  Future<void> close() {
    amountController.dispose();
    return super.close();
  }
}
