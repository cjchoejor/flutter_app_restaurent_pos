import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:pos_system_legphel/models/Menu%20Model/menu_bill_model.dart';

class ProceedOrderModel extends Equatable {
  final String holdOrderId;
  final String tableNumber;
  final String customerName;
  final String phoneNumber;
  final String restaurantBranchName;
  final DateTime orderDateTime;
  final String orderNumber;
  final List<MenuBillModel> menuItems;
  final double totalAmount;
  final String? roomNumber; // ADD THIS
  final String? reservationRefNo; // ADD THIS
  final String? paymentStatus;
  final String? paymentMode;

  const ProceedOrderModel({
    required this.orderNumber,
    required this.holdOrderId,
    required this.tableNumber,
    required this.customerName,
    required this.phoneNumber,
    required this.restaurantBranchName,
    required this.orderDateTime,
    required this.menuItems,
    required this.totalAmount,
    this.roomNumber, // ADD THIS
    this.reservationRefNo, // ADD THIS
    this.paymentStatus,
    this.paymentMode,
  });

  /// Computes total from menuItems if needed elsewhere
  double get totalPrice {
    return double.parse(
      menuItems
          .fold(0.0, (sum, item) => sum + item.totalPrice)
          .toStringAsFixed(2),
    );
  }

  ProceedOrderModel copyWith({
    String? holdOrderId,
    String? tableNumber,
    String? customerName,
    String? orderNumber,
    String? phoneNumber,
    String? restaurantBranchName,
    DateTime? orderDateTime,
    List<MenuBillModel>? menuItems,
    double? totalAmount,
    String? roomNumber, // ADD THIS
    String? reservationRefNo, // ADD THIS
    String? paymentStatus,
    String? paymentMode,
  }) {
    return ProceedOrderModel(
      holdOrderId: holdOrderId ?? this.holdOrderId,
      tableNumber: tableNumber ?? this.tableNumber,
      customerName: customerName ?? this.customerName,
      orderNumber: orderNumber ?? this.orderNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      restaurantBranchName: restaurantBranchName ?? this.restaurantBranchName,
      orderDateTime: orderDateTime ?? this.orderDateTime,
      menuItems: menuItems ?? this.menuItems,
      totalAmount: totalAmount ?? this.totalAmount,
      roomNumber: roomNumber ?? this.roomNumber, // ADD THIS
      reservationRefNo: reservationRefNo ?? this.reservationRefNo, // ADD
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMode: paymentMode ?? this.paymentMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'holdOrderId': holdOrderId,
      'tableNumber': tableNumber,
      'customerName': customerName,
      'orderNumber': orderNumber,
      'phoneNumber': phoneNumber,
      'restaurantBranchName': restaurantBranchName,
      'orderDateTime': orderDateTime.toIso8601String(),
      'menuItems': jsonEncode(menuItems.map((item) => item.toMap()).toList()),
      'totalAmount': totalAmount,
      'roomNumber': roomNumber, // ADD THIS
      'reservationRefNo': reservationRefNo, // ADD THIS
      'paymentStatus': paymentStatus,
      'paymentMode': paymentMode,
    };
  }

  factory ProceedOrderModel.fromMap(Map<String, dynamic> map) {
    // Guard against null/corrupt JSON so a single bad row doesn't crash the
    // whole order/receipt screen when it loads.
    List<MenuBillModel> menuItems = [];
    try {
      final rawItems = map['menuItems'];
      if (rawItems is String && rawItems.isNotEmpty) {
        menuItems = List<MenuBillModel>.from(
          jsonDecode(rawItems).map((item) => MenuBillModel.fromMap(item)),
        );
      }
    } catch (e) {
      menuItems = [];
    }

    double calculatedTotal = double.parse(
      menuItems
          .fold(0.0, (sum, item) => sum + item.totalPrice)
          .toStringAsFixed(2),
    );

    return ProceedOrderModel(
      holdOrderId: map['holdOrderId'],
      tableNumber: map['tableNumber'],
      customerName: map['customerName'],
      phoneNumber: map['phoneNumber'],
      orderNumber: map['orderNumber'],
      restaurantBranchName: map['restaurantBranchName'],
      orderDateTime: DateTime.parse(map['orderDateTime']),
      menuItems: menuItems,
      totalAmount: map['totalAmount'] != null
          ? double.parse(map['totalAmount'].toString())
          : calculatedTotal,
      roomNumber: map['roomNumber'], // ADD THIS
      reservationRefNo: map['reservationRefNo'], // ADD THIS
      paymentStatus: map['paymentStatus'] as String?,
      paymentMode: map['paymentMode'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        holdOrderId,
        orderNumber,
        tableNumber,
        customerName,
        phoneNumber,
        restaurantBranchName,
        orderDateTime,
        menuItems,
        totalAmount,
        roomNumber, // ADD THIS
        reservationRefNo, // ADD THIS
        paymentStatus,
        paymentMode,
      ];
}
