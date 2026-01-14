# Bill Data Flow Analysis for Receipt Page

## 1. WHERE BILL DATA COMES FROM

### Flow Diagram:
```
ProceedOrderModel (from ProceedOrderBloc)
    ↓ (user clicks order in receipt list)
_buildReceiptListItem() called
    ↓
selectedReceiptItem set
    ↓
_loadBillData() triggered
    ↓
BillBloc.add(LoadBill(orderNumber))
    ↓
BillBloc._onLoadBill() fetches:
  - From Server: GET /api/fnb_bill_summary_legphel_eats/{orderNumber}
  - From Local DB: pending_bill_database (SQLite)
    ↓
BillLoaded state emitted with BillSummaryModel
    ↓
BlocListener in receipt_page catches BillLoaded
    ↓
state.billSummary.toJson() stored in _billDataCache[orderNumber]
    ↓
_buildReceiptListItem reads from _billDataCache
```

## 2. COLUMNS BEING PULLED

### BillSummaryModel Properties (from bill_summary_model.dart):

#### Identity Fields:
- `fnb_bill_no` → 'fnb_bill_no' (Order number/Bill ID)
- `outlet` → 'outlet' (Branch/Restaurant name)

#### Customer Information:
- `primaryCustomerName` → 'primary_customer_name'
- `phoneNo` → 'phone_no'
- `tableNo` → 'table_no'
- `pax` → 'pax' (Number of people)

#### Room/Reservation Fields:
- `roomNo` → 'room_no' (Hotel room number)
- `reservationRefNo` → 'reservation_ref_no' (Reservation reference)

#### Order Details:
- `orderType` → 'order_type' (Dine In / Takeaway / Delivery / Room Service)

#### Financial Calculations:
- `subTotal` → 'sub_total' (Amount before taxes/charges)
- `bst` → 'bst' (Business Sales Tax %)
- `serviceCharge` → 'service_charge' (Service charge amount)
- `discount` → 'discount' (Discount amount)
- `totalAmount` → 'total_amount' (Final total)

#### Payment Status Fields (CRITICAL):
- `paymentStatus` → 'payment_status' (PAID / CREDIT / COMPLIMENTARY / PENDING)
- `amountSettled` → 'amount_settled' (Amount already paid)
- `amountRemaining` → 'amount_remaing' (Amount still due) ⚠️ NOTE: Typo in JSON key!
- `paymentMode` → 'payment_mode' (CASH / CARD / SCAN / COMPLIMENTARY / CREDIT)

#### Metadata:
- `journalNo` → 'journal_no' (Optional journal entry number)
- `imageFnbBill` → 'image_fnb_bill' (Optional bill image)
- `date` → 'date' (Bill date)
- `time` → 'time' (Bill time)

## 3. DATA RETRIEVAL METHODS IN RECEIPT_PAGE

### Method 1: `_getSelectedBillData()`
```dart
Map<String, dynamic>? _getSelectedBillData() {
  if (selectedReceiptItem == null) return null;
  return _billDataCache[selectedReceiptItem!.orderNumber];
}
```
- Returns the cached bill data dictionary
- Used to get all columns at once

### Method 2: `_getSelectedPaymentStatus()`
```dart
String? _getSelectedPaymentStatus() {
  if (selectedReceiptItem == null) return null;
  return _paymentStatusCache[selectedReceiptItem!.orderNumber];
}
```
- Returns only the payment_status field
- Cached separately for quick access

### Method 3: `_getWasCredit()`
```dart
bool _getWasCredit() {
  if (selectedReceiptItem == null) return false;
  return _wasCreditCache[selectedReceiptItem!.orderNumber] ?? false;
}
```
- Boolean flag tracking if bill was originally CREDIT/PENDING
- Used to show "Print Bill" button after payment

## 4. HOW DATA IS LOADED IN BLOCLISTENER

```dart
child: BlocListener<BillBloc, BillState>(
  listener: (context, state) {
    if (state is BillLoaded) {
      // Cache the entire bill summary as JSON
      _billDataCache[selectedReceiptItem!.orderNumber] = 
        state.billSummary.toJson();  // ← All fields converted to JSON
      
      // Cache payment status separately for quick access
      _paymentStatusCache[selectedReceiptItem!.orderNumber] = 
        state.billSummary.paymentStatus;
      
      // Track if was originally credit/pending
      if (state.billSummary.paymentStatus == 'PENDING' || 
          state.billSummary.paymentStatus == 'CREDIT') {
        _wasCreditCache[selectedReceiptItem!.orderNumber] = true;
      }
    }
  },
)
```

## 5. USAGE IN _buildReceiptListItem

```dart
Widget _buildReceiptListItem(ProceedOrderModel proceedOrder) {
  // Source 1: ProceedOrderModel (from local storage)
  proceedOrder.orderNumber  // Used as cache key
  proceedOrder.orderDateTime  // Used for UI display
  proceedOrder.totalPrice  // Fallback amount if bill data missing
  
  // Source 2: Bill Summary Cache (from BillBloc)
  final billData = _getSelectedBillData();
  billData?['payment_status']  // Display payment badge
  
  // Source 3: Payment Status Cache
  final paymentStatus = _getSelectedPaymentStatus();
}
```

## 6. KEY POINTS

⚠️ **Important Note**: There's a typo in the JSON conversion:
- Model field: `amountRemaining`
- JSON key: `'amount_remaing'` (missing 'i')
- This matches the server API, so don't change it!

✅ **Data Flow is Correct**:
1. Bills are fetched via BillBloc from server or local DB
2. Entire BillSummaryModel is converted to JSON and cached
3. Cache is read when building UI
4. Payment status updates go through `_onUpdatePaymentStatus` in BillBloc
5. Bill is reloaded after payment to show updated status

✅ **All Required Columns Present**:
- Payment status fields: ✓
- Customer info: ✓
- Financial data: ✓
- Room/Reservation data: ✓
- Metadata: ✓
