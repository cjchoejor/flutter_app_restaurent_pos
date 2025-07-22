class CustomerInfoOrderModel {
  final String name;
  final String contact;
  final String orderId;
  final String tableNo;
  final String orderNumber;
  final String? roomNumber; // ADD THIS
  final String? reservationRefNo; // ADD THIS

  CustomerInfoOrderModel({
    required this.name,
    required this.contact,
    required this.orderId,
    required this.tableNo,
    required this.orderNumber,
    this.roomNumber, // ADD THIS
    this.reservationRefNo, // ADD THIS
  });

  // Convert a CustomerInfoOrderModel instance to a map (for database or API purposes)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contact': contact,
      'orderId': orderId,
      'tableNo': tableNo,
      'orderNumber': orderNumber,
      'roomNumber': roomNumber, // ADD THIS
      'reservationRefNo': reservationRefNo, // ADD THIS
    };
  }

  // Create a CustomerInfoOrderModel instance from a map (e.g., when retrieving data from database or API)
  factory CustomerInfoOrderModel.fromMap(Map<String, dynamic> map) {
    return CustomerInfoOrderModel(
      name: map['name'] ?? '',
      contact: map['contact'] ?? '',
      orderId: map['orderId'] ?? '',
      tableNo: map['tableNo'] ?? '',
      orderNumber: map['orderNumber'] ?? '',
      roomNumber: map['roomNumber'], // ADD THIS
      reservationRefNo: map['reservationRefNo'], // ADD THIS
    );
  }

  // Add copyWith method for easy updates
  CustomerInfoOrderModel copyWith({
    String? name,
    String? contact,
    String? orderId,
    String? tableNo,
    String? orderNumber,
    String? roomNumber,
    String? reservationRefNo,
  }) {
    return CustomerInfoOrderModel(
      name: name ?? this.name,
      contact: contact ?? this.contact,
      orderId: orderId ?? this.orderId,
      tableNo: tableNo ?? this.tableNo,
      orderNumber: orderNumber ?? this.orderNumber,
      roomNumber: roomNumber ?? this.roomNumber,
      reservationRefNo: reservationRefNo ?? this.reservationRefNo,
    );
  }

  @override
  String toString() {
    return 'CustomerInfoOrderModel(name: $name, contact: $contact, orderId: $orderId, tableNo: $tableNo, orderNumber: $orderNumber, roomNumber: $roomNumber, reservationRefNo: $reservationRefNo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerInfoOrderModel &&
        other.name == name &&
        other.contact == contact &&
        other.orderId == orderId &&
        other.tableNo == tableNo &&
        other.orderNumber == orderNumber &&
        other.roomNumber == roomNumber &&
        other.reservationRefNo == reservationRefNo;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        contact.hashCode ^
        orderId.hashCode ^
        tableNo.hashCode ^
        orderNumber.hashCode ^
        roomNumber.hashCode ^
        reservationRefNo.hashCode;
  }
}
