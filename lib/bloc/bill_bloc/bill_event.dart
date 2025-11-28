part of 'bill_bloc.dart';

abstract class BillEvent extends Equatable {
  const BillEvent();

  @override
  List<Object?> get props => [];
}

class SubmitBill extends BillEvent {
  final BillSummaryModel billSummary;
  final List<BillDetailsModel> billDetails;

  const SubmitBill({
    required this.billSummary,
    required this.billDetails,
  });

  @override
  List<Object?> get props => [billSummary, billDetails];
}

class LoadBill extends BillEvent {
  final String fnbBillNo;

  const LoadBill(this.fnbBillNo);

  @override
  List<Object?> get props => [fnbBillNo];
}

class UpdateBill extends BillEvent {
  final BillSummaryModel billSummary;
  final List<BillDetailsModel> billDetails;

  const UpdateBill({
    required this.billSummary,
    required this.billDetails,
  });

  @override
  List<Object?> get props => [billSummary, billDetails];
}

class DeleteBill extends BillEvent {
  final String fnbBillNo;

  const DeleteBill(this.fnbBillNo);

  @override
  List<Object?> get props => [fnbBillNo];
}

class UpdatePaymentStatus extends BillEvent {
  final String fnbBillNo;
  final String paymentStatus;
  final double amountSettled;
  final String paymentMode;

  const UpdatePaymentStatus({
    required this.fnbBillNo,
    required this.paymentStatus,
    required this.amountSettled,
    required this.paymentMode,
  });

  @override
  List<Object?> get props => [fnbBillNo, paymentStatus, amountSettled, paymentMode];
}
