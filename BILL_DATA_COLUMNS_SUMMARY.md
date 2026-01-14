# Bill Data Columns - Complete Summary for Receipt Page

## Quick Answer: Where Data Comes From in _buildReceiptListItem

```
ProceedOrderModel (local storage)
        ↓
User clicks order
        ↓
_loadBillData() → BillBloc.LoadBill(orderNumber)
        ↓
BillBloc fetches from SERVER or LOCAL DATABASE
        ↓
BlocListener catches BillLoaded state
        ↓
BillSummaryModel.toJson() → _billDataCache[orderNumber]
        ↓
_buildReceiptListItem reads from _billDataCache
```

---

## All Columns Being Pulled

### From `BillSummaryModel.toJson()`:

| Category | Model Field | JSON Key | Data Type | Usage |
|----------|-------------|----------|-----------|-------|
| **Identity** | fnbBillNo | fnb_bill_no | String | Bill ID / Order Number |
| | outlet | outlet | String | Branch/Restaurant name |
| **Customer** | primaryCustomerName | primary_customer_name | String | Customer name |
| | phoneNo | phone_no | String | Customer phone |
| | tableNo | table_no | String | Table number |
| | pax | pax | int | Number of people |
| **Location** | roomNo | room_no | String? | Hotel room number |
| | reservationRefNo | reservation_ref_no | String? | Reservation ref |
| **Order** | orderType | order_type | String | Dine In/Takeaway/Delivery |
| **Financial** | subTotal | sub_total | double | Amount before tax |
| | bst | bst | double | Business Sales Tax % |
| | serviceCharge | service_charge | double | Service charge $ |
| | discount | discount | double | Discount $ |
| | totalAmount | total_amount | double | Final total $ |
| **Payment** ⭐ | paymentStatus | payment_status | String | PAID/CREDIT/COMPLIMENTARY/PENDING |
| ⭐ | amountSettled | amount_settled | double | $ already paid |
| ⭐ | amountRemaining | amount_remaing | double | $ still due (typo in key!) |
| ⭐ | paymentMode | payment_mode | String | CASH/CARD/SCAN/COMPLIMENTARY |
| **Metadata** | journalNo | journal_no | int? | Optional accounting ref |
| | imageFnbBill | image_fnb_bill | String? | Optional bill image URL |
| | date | date | String | Bill date (YYYY-MM-DD) |
| | time | time | String | Bill time (HH:MM:SS) |

---

## What _buildReceiptListItem Actually Uses

```dart
Widget _buildReceiptListItem(ProceedOrderModel proceedOrder) {
  // From ProceedOrderModel:
  proceedOrder.orderNumber          // "20250128163000-BRANCH-1000"
  proceedOrder.orderDateTime        // DateTime object
  
  // From BillSummaryModel (cached):
  billData['payment_status']        // "PAID" / "CREDIT" / "COMPLIMENTARY" / "PENDING"
  
  // That's it! The list item is simple.
}
```

**Minimal columns displayed:**
- Order Number (from ProceedOrderModel)
- Order Date/Time (from ProceedOrderModel)  
- Payment Status Badge (from billData['payment_status'])

---

## Three Separate Caches

### 1. `_billDataCache` (Main Cache)
```dart
Map<String, Map<String, dynamic>> _billDataCache = {}; 
// Key: orderNumber
// Value: BillSummaryModel.toJson() - ALL 20+ columns
```

### 2. `_paymentStatusCache` (Quick Access)
```dart
Map<String, String> _paymentStatusCache = {};
// Key: orderNumber
// Value: payment_status string only
// Used for fast lookup in list items
```

### 3. `_wasCreditCache` (History Flag)
```dart
Map<String, bool> _wasCreditCache = {};
// Key: orderNumber
// Value: boolean (was bill originally CREDIT/PENDING?)
// Used to show "Print Bill" button after payment
```

---

## When Data Gets Loaded

### Trigger: `_loadBillData(String orderNumber)`
```dart
void _loadBillData(String orderNumber) {
  context.read<BillBloc>().add(LoadBill(orderNumber));
}
```

This is called when:
1. First order is auto-selected on page load (line 167)
2. User clicks on an order in the list (line 735)
3. After payment is processed (line 558)

### BillBloc Fetch Logic (`_onLoadBill`):
1. Check if network connected
2. If connected → GET from server: `/api/fnb_bill_summary_legphel_eats/{orderNumber}`
3. If not connected → Get from local DB: `pending_bill_database`
4. Emit `BillLoaded(billSummary, billDetails)`

### BlocListener Receives:
```dart
if (state is BillLoaded) {
  setState(() {
    _billDataCache[selectedReceiptItem!.orderNumber] = 
      state.billSummary.toJson();  // Store ALL fields
      
    _paymentStatusCache[selectedReceiptItem!.orderNumber] = 
      state.billSummary.paymentStatus;  // Cache separately
      
    // Track if was originally credit
    if (state.billSummary.paymentStatus == 'PENDING' || 
        state.billSummary.paymentStatus == 'CREDIT') {
      _wasCreditCache[selectedReceiptItem!.orderNumber] = true;
    }
  });
}
```

---

## Payment Update Process

When user clicks "Pay Now" → Select payment method → `_processPayment()`:

1. **Validates bill data exists:**
   ```dart
   if (billData == null) {
     // Show "Loading..." message and reload
     _loadBillData(orderNumber);
     return;
   }
   ```

2. **Updates UI cache (optimistic):**
   ```dart
   _billDataCache[orderNumber] = {
     ...billData,
     'payment_status': 'PAID',      // Update
     'amount_settled': amountToSettle,  // Update
     'amount_remaing': 0.0,         // Update
   };
   ```

3. **Sends PATCH request:**
   ```
   PATCH /api/fnb_bill_summary_legphel_eats/{orderNumber}
   Body: {
     'payment_status': 'PAID',
     'amount_settled': amount,
     'amount_remaing': 0.0,
     'payment_mode': method
   }
   ```

4. **Updates local database:**
   ```
   UPDATE pending_bill_summaries
   SET data = {...updated with payment status...}
   WHERE fnb_bill_no = orderNumber
   ```

5. **Deletes if PAID:**
   ```
   DELETE FROM pending_bill_summaries
   WHERE fnb_bill_no = orderNumber
   ```

6. **Reloads bill data:**
   ```
   Future.delayed(500ms) → _loadBillData(orderNumber)
   ```

---

## Important Note ⚠️

The JSON field is `'amount_remaing'` (missing 'i') not `'amount_remaining'`.
This is a typo in the API that must be matched exactly:
```dart
'amount_remaing': 0.0  // Correct (matches server API)
'amount_remaining': 0.0  // Wrong!
```

---

## Summary Table

| What | Where From | Cache Key | Fields Used |
|-----|-----------|-----------|------------|
| List display | ProceedOrderModel + BillSummaryModel | orderNumber | order number, date, payment_status |
| Detail view | BillSummaryModel cached | orderNumber | ALL fields |
| Payment button | BillSummaryModel cached | orderNumber | total_amount |
| Payment status update | BillBloc PATCH | orderNumber | 4 fields |
| Deletion flag | BillSummaryModel cached | orderNumber | payment_status (was CREDIT?) |

