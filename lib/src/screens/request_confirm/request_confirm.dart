import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos/localization/app_localizations.dart';
import 'package:pos/src/blocs/home/bloc.dart';
import 'package:pos/src/model/payment_request.dart';
import 'package:pos/src/screens/request_confirm/bloc.dart';
import 'package:pos/src/screens/request_confirm/summary_request.dart';
import 'package:pos/src/screens/request_confirm/wom_creation_event.dart';
import 'package:pos/src/screens/request_confirm/wom_creation_state.dart';

class RequestConfirmScreen extends StatefulWidget {
  final PaymentRequest paymentRequest;

  const RequestConfirmScreen({Key key, this.paymentRequest}) : super(key: key);

  @override
  _RequestConfirmScreenState createState() => _RequestConfirmScreenState();
}

class _RequestConfirmScreenState extends State<RequestConfirmScreen> {
  RequestConfirmBloc bloc;
  HomeBloc homeBloc;

  bool isComplete = false;
  bool isWrong = false;
  bool noDataConnection = false;

  @override
  void initState() {
    bloc = RequestConfirmBloc(paymentRequest: widget.paymentRequest);
    super.initState();
  }

  Future<bool> onWillPop() {
    if (isComplete || isWrong || noDataConnection) {
      homeBloc.dispatch(LoadRequest());
      return Future.value(true);
    }
    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    homeBloc = BlocProvider.of<HomeBloc>(context);

    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(bloc.paymentRequest.name),
          centerTitle: true,
          elevation: 0.0,
//          actions: <Widget>[
//            Text("${bloc.paymentRequest.id}"),
//          ],
        ),
        body: BlocBuilder(
          bloc: bloc,
          builder: (_, WomCreationState state) {
            if (state is WomCreationRequestEmpty) {
              return Center(
                child: Text(AppLocalizations.of(context)
                    .translate('starting_creation_request')),
              );
            } else if (state is WomCreationRequestLoading) {
              isWrong = false;
              isComplete = false;
              noDataConnection = false;
              return Center(
                child: CircularProgressIndicator(),
              );
            } else if (state is WomCreationRequestError) {
              isWrong = true;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Text(state.error),
                  FloatingActionButton.extended(
                    onPressed: () => bloc.dispatch(CreateWomRequest()),
                    label: Text(
                        AppLocalizations.of(context).translate('try_again')),
                  ),
                ],
              );
            } else if (state is WomCreationRequestNoDataConnectionState) {
              noDataConnection = true;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      AppLocalizations.of(context)
                          .translate('no_connection_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Text(
                      AppLocalizations.of(context)
                          .translate('no_connection_transaction_desc'),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    RaisedButton(
                        child: Text(AppLocalizations.of(context)
                            .translate('try_again')),
                        onPressed: () {
                          bloc.dispatch(CreateWomRequest());
                        }),
                  ],
                ),
              );
            } else if (state is WomVerifyCreationRequestComplete) {
              isComplete = true;
              return SummaryRequest(
                paymentRequest: bloc.paymentRequest,
              );
            }

            return Center(
                child: Text(AppLocalizations.of(context)
                    .translate('error_screen_state')));
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    homeBloc.dispatch(LoadRequest());
    bloc.dispose();
    super.dispose();
  }
}
