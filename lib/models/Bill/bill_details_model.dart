import 'package:equatable/equatable.dart';

class BillDetailsModel extends Equatable {
  final String id;
  final String menuName;
  final double rate;
  final int quantity;
  final double amount;
  final String fnbBillNo;
  final DateTime date;
  final DateTime time;
  final String? roomNumber; // ADD THIS
  final String? reservationRefNo; // ADD THIS

  const BillDetailsModel({
    required this.id,
    required this.menuName,
    required this.rate,
    required this.quantity,
    required this.amount,
    required this.fnbBillNo,
    required this.date,
    required this.time,
    this.roomNumber, // ADD THIS
    this.reservationRefNo, // ADD THIS
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_name': menuName,
      'rate': rate,
      'quanity': quantity,
      'amount': amount,
      'fnb_bill_no': fnbBillNo,
      'date': date.toIso8601String().split('T')[0],
      'time': time.toIso8601String().split('T')[1].substring(0, 8),
      'room_no': roomNumber, // ADD THIS
      'reservation_ref_no': reservationRefNo, // ADD THIS
    };
  }

  factory BillDetailsModel.fromJson(Map<String, dynamic> json) {
    return BillDetailsModel(
      id: json['id'],
      menuName: json['menu_name'],
      rate: json['rate'].toDouble(),
      quantity: json['quanity'],
      amount: json['amount'].toDouble(),
      fnbBillNo: json['fnb_bill_no'],
      date: DateTime.parse(json['date']),
      time: DateTime.parse('2000-01-01T${json['time']}'),
      roomNumber: json['room_no'], // ADD THIS
      reservationRefNo: json['reservation_ref_no'], // ADD THIS
    );
  }

  @override
  List<Object?> get props => [
        id,
        menuName,
        rate,
        quantity,
        amount,
        fnbBillNo,
        date,
        time,
        roomNumber,
        reservationRefNo,
      ];
}
