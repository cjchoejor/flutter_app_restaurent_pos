import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_system_legphel/models/Bill/bill_summary_model.dart';
import 'package:pos_system_legphel/models/Bill/bill_details_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pos_system_legphel/SQL/pending_bill_database.dart';
import 'package:pos_system_legphel/services/network_service.dart';
import 'package:pos_system_legphel/services/sync_service.dart';

part 'bill_event.dart';
part 'bill_state.dart';

class BillBloc extends Bloc<BillEvent, BillState> {
  final String baseUrl = 'http://119.2.105.142:3800';
  final PendingBillDatabaseHelper _dbHelper =
      PendingBillDatabaseHelper.instance;
  final NetworkService _networkService;
  final SyncService _syncService;

  BillBloc(this._networkService, this._syncService) : super(BillInitial()) {
    on<SubmitBill>(_onSubmitBill);
    on<LoadBill>(_onLoadBill);
    on<UpdateBill>(_onUpdateBill);
    on<DeleteBill>(_onDeleteBill);
    on<UpdatePaymentStatus>(_onUpdatePaymentStatus);
  }

  Future<void> _onSubmitBill(SubmitBill event, Emitter<BillState> emit) async {
    try {
      emit(BillLoading());
      print('Submitting bill ${event.billSummary.fnbBillNo}...');

      final isConnected = await _networkService.isConnected();
      print('Network connected: $isConnected');

      final isServerAvailable = await _networkService.isServerAvailable();
      print('Server available: $isServerAvailable');

      // Always store locally first
      print('Storing bill locally...');
      await _dbHelper.insertPendingBill(event.billSummary, event.billDetails);
      print('Successfully stored bill locally');

      // If offline or server unavailable, just emit success
      if (!isConnected || !isServerAvailable) {
        print('Network or server unavailable, keeping bill local only');
        emit(BillSubmitted(event.billSummary.fnbBillNo));
        return;
      }

      // Try to submit online
      print('Attempting to submit bill online...');
      try {
        // Submit bill summary
        final summaryResponse = await http.post(
          Uri.parse('$baseUrl/api/fnb_bill_summary_legphel_eats'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(event.billSummary.toJson()),
        );

        if (summaryResponse.statusCode != 200 &&
            summaryResponse.statusCode != 201) {
          print(
              'Failed to submit bill summary: ${summaryResponse.statusCode} - ${summaryResponse.body}');
          throw Exception(
              'Failed to submit bill summary: ${summaryResponse.body}');
        }
        print('Successfully submitted bill summary');

        // Submit bill details
        for (var detail in event.billDetails) {
          print('Submitting bill detail for ${detail.id}');
          final detailResponse = await http.post(
            Uri.parse('$baseUrl/api/fnb_bill_details_legphel_eats'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(detail.toJson()),
          );

          if (detailResponse.statusCode != 200 &&
              detailResponse.statusCode != 201) {
            print(
                'Failed to submit bill detail: ${detailResponse.statusCode} - ${detailResponse.body}');
            throw Exception(
                'Failed to submit bill detail: ${detailResponse.body}');
          }
          print('Successfully submitted bill detail');
        }

        // Keep bill in local storage for payment status updates and future reference
        print('Successfully submitted all bill data online. Keeping in local storage for payment updates.');
      } catch (e) {
        print('Error submitting bill online: $e');
        // Keep the bill in local storage for later sync
        print('Keeping bill in local storage for later sync');
      }

      emit(BillSubmitted(event.billSummary.fnbBillNo));
    } catch (e) {
      print('Error in _onSubmitBill: $e');
      emit(BillError(e.toString()));
    }
  }

  Future<void> _onLoadBill(LoadBill event, Emitter<BillState> emit) async {
    try {
      emit(BillLoading());

      final isConnected = await _networkService.isConnected();
      final isServerAvailable = await _networkService.isServerAvailable();

      if (!isConnected || !isServerAvailable) {
        // Try to load from local storage - get ALL bills (pending and synced)
        final allBills = await _dbHelper.getAllBillSummaries();
        final bill = allBills.firstWhere(
          (b) => b['fnb_bill_no'] == event.fnbBillNo,
          orElse: () => throw Exception('Bill not found in local database'),
        );

        final summary = BillSummaryModel.fromJson(
          jsonDecode(bill['data'] as String),
        );

        final details = await _dbHelper.getPendingBillDetails(event.fnbBillNo);
        final billDetails = details
            .map((detail) =>
                BillDetailsModel.fromJson(jsonDecode(detail['data'] as String)))
            .toList();

        print('Loaded bill ${event.fnbBillNo} from local database with status: ${summary.paymentStatus}');
        emit(BillLoaded(billSummary: summary, billDetails: billDetails));
        return;
      }

      // Load from server
      final summaryResponse = await http.get(
        Uri.parse(
            '$baseUrl/api/fnb_bill_summary_legphel_eats/${event.fnbBillNo}'),
      ).timeout(const Duration(seconds: 5));

      if (summaryResponse.statusCode != 200) {
        print('Server returned ${summaryResponse.statusCode}, attempting to load from local database');
        // Fall back to local database if server fails
        try {
          final allBills = await _dbHelper.getAllBillSummaries();
          final bill = allBills.firstWhere(
            (b) => b['fnb_bill_no'] == event.fnbBillNo,
            orElse: () => throw Exception('Bill not found in local database'),
          );

          final summary = BillSummaryModel.fromJson(
            jsonDecode(bill['data'] as String),
          );

          final details = await _dbHelper.getPendingBillDetails(event.fnbBillNo);
          final billDetails = details
              .map((detail) =>
                  BillDetailsModel.fromJson(jsonDecode(detail['data'] as String)))
              .toList();

          print('Loaded bill ${event.fnbBillNo} from local database (fallback) with status: ${summary.paymentStatus}');
          emit(BillLoaded(billSummary: summary, billDetails: billDetails));
          return;
        } catch (localError) {
          throw Exception('Failed to load bill summary: ${summaryResponse.body}');
        }
      }

      final summary =
          BillSummaryModel.fromJson(jsonDecode(summaryResponse.body));

      final detailsResponse = await http.get(
        Uri.parse(
            '$baseUrl/api/fnb_bill_details_legphel_eats?fnb_bill_no=${event.fnbBillNo}'),
      ).timeout(const Duration(seconds: 5));

      if (detailsResponse.statusCode != 200) {
        throw Exception('Failed to load bill details: ${detailsResponse.body}');
      }

      final List<dynamic> detailsJson = jsonDecode(detailsResponse.body);
      final details =
          detailsJson.map((json) => BillDetailsModel.fromJson(json)).toList();

      emit(BillLoaded(billSummary: summary, billDetails: details));
    } on http.ClientException catch (e) {
      // Handle network timeouts and connection errors
      print('Network error: $e, attempting to load from local database');
      try {
        final allBills = await _dbHelper.getAllBillSummaries();
        final bill = allBills.firstWhere(
          (b) => b['fnb_bill_no'] == event.fnbBillNo,
          orElse: () => throw Exception('Bill not found in local database'),
        );

        final summary = BillSummaryModel.fromJson(
          jsonDecode(bill['data'] as String),
        );

        final details = await _dbHelper.getPendingBillDetails(event.fnbBillNo);
        final billDetails = details
            .map((detail) =>
                BillDetailsModel.fromJson(jsonDecode(detail['data'] as String)))
            .toList();

        print('Loaded bill ${event.fnbBillNo} from local database (network fallback) with status: ${summary.paymentStatus}');
        emit(BillLoaded(billSummary: summary, billDetails: billDetails));
      } catch (localError) {
        emit(BillError('Network error and unable to load from local database: ${localError.toString()}'));
      }
    } catch (e) {
      emit(BillError(e.toString()));
    }
  }

  Future<void> _onUpdateBill(UpdateBill event, Emitter<BillState> emit) async {
    try {
      emit(BillLoading());

      final isConnected = await _networkService.isConnected();
      final isServerAvailable = await _networkService.isServerAvailable();

      if (!isConnected || !isServerAvailable) {
        // Store update locally
        await _dbHelper.insertPendingBill(event.billSummary, event.billDetails);
        emit(BillSubmitted(event.billSummary.fnbBillNo));
        return;
      }

      // Try to update online
      try {
        // Update bill summary
        final summaryResponse = await http.put(
          Uri.parse(
              '$baseUrl/api/fnb_bill_summary_legphel_eats/${event.billSummary.fnbBillNo}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(event.billSummary.toJson()),
        );

        if (summaryResponse.statusCode != 200) {
          throw Exception(
              'Failed to update bill summary: ${summaryResponse.body}');
        }

        // Delete existing bill details
        await http.delete(
          Uri.parse(
              '$baseUrl/api/fnb_bill_details_legphel_eats/${event.billSummary.fnbBillNo}'),
        );

        // Submit new bill details
        for (var detail in event.billDetails) {
          final detailResponse = await http.post(
            Uri.parse('$baseUrl/api/fnb_bill_details_legphel_eats'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(detail.toJson()),
          );

          if (detailResponse.statusCode != 200 &&
              detailResponse.statusCode != 201) {
            throw Exception(
                'Failed to update bill detail: ${detailResponse.body}');
          }
        }

        emit(BillSubmitted(event.billSummary.fnbBillNo));
      } catch (e) {
        // If online update fails, store locally
        await _dbHelper.insertPendingBill(event.billSummary, event.billDetails);
        emit(BillSubmitted(event.billSummary.fnbBillNo));
      }
    } catch (e) {
      emit(BillError(e.toString()));
    }
  }

  Future<void> _onDeleteBill(DeleteBill event, Emitter<BillState> emit) async {
    try {
      emit(BillLoading());

      final isConnected = await _networkService.isConnected();
      final isServerAvailable = await _networkService.isServerAvailable();

      if (!isConnected || !isServerAvailable) {
        // Mark as deleted locally
        await _dbHelper.updateSyncStatus(event.fnbBillNo, 'deleted');
        emit(BillInitial());
        return;
      }

      // Try to delete online
      try {
        // Delete bill details first
        await http.delete(
          Uri.parse(
              '$baseUrl/api/fnb_bill_details_legphel_eats/${event.fnbBillNo}'),
        );

        // Delete bill summary
        final response = await http.delete(
          Uri.parse(
              '$baseUrl/api/fnb_bill_summary_legphel_eats/${event.fnbBillNo}'),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to delete bill: ${response.body}');
        }

        emit(BillInitial());
      } catch (e) {
        // If online delete fails, mark as deleted locally
        await _dbHelper.updateSyncStatus(event.fnbBillNo, 'deleted');
        emit(BillInitial());
      }
    } catch (e) {
      emit(BillError(e.toString()));
    }
  }

  Future<void> _onUpdatePaymentStatus(
      UpdatePaymentStatus event, Emitter<BillState> emit) async {
    try {
      emit(BillLoading());

      // First, ensure bill exists locally
      final localData = await _dbHelper.getBillSummaryData(event.fnbBillNo);
      if (localData == null) {
        print('Error: Bill not found in local database for ${event.fnbBillNo}');
        emit(BillError('Bill not found. Please ensure the bill has been created.'));
        return;
      }

      final isConnected = await _networkService.isConnected();
      final isServerAvailable = await _networkService.isServerAvailable();

      print('Updating payment status for ${event.fnbBillNo}: Network connected=$isConnected, Server available=$isServerAvailable');

      // Update local database first (always do this)
      try {
        await _dbHelper.updatePaymentStatus(
          event.fnbBillNo,
          event.paymentStatus,
          event.amountSettled,
          event.paymentMode,
        );
        print('Updated local SQLite database with payment status: ${event.paymentStatus}');
      } catch (dbError) {
        print('Error updating local database: $dbError');
        emit(BillError('Failed to update local database: $dbError'));
        return;
      }

      // Try to update on server if connected
      if (isConnected && isServerAvailable) {
        try {
          // First fetch the current bill data to preserve existing fields
          Map<String, dynamic> currentBill;
          
          final fetchResponse = await http.get(
            Uri.parse(
                '$baseUrl/api/fnb_bill_summary_legphel_eats/${event.fnbBillNo}'),
          ).timeout(const Duration(seconds: 5));

          if (fetchResponse.statusCode == 200) {
            currentBill = jsonDecode(fetchResponse.body);
            print('Fetched bill data from server');
          } else {
            print('Bill not found on server (${fetchResponse.statusCode}), using local data');
            currentBill = localData;
          }

          // Create update data with only the payment-related fields (PATCH endpoint)
          final updateData = {
            'payment_status': event.paymentStatus,
            'amount_settled': event.amountSettled,
            'amount_remaing': event.paymentStatus == 'PAID' ? 0.0 : (currentBill['amount_remaing'] as num?)?.toDouble() ?? 0.0,
            'payment_mode': event.paymentMode,
          };

          print('Sending PATCH request to update payment status: $updateData');

          final response = await http.patch(
            Uri.parse(
                '$baseUrl/api/fnb_bill_summary_legphel_eats/${event.fnbBillNo}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updateData),
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode != 200) {
            print('Server PATCH failed (${response.statusCode}): ${response.body}');
            print('Payment status updated locally. Server sync will be retried later.');
          } else {
            print('Successfully updated payment status on server for ${event.fnbBillNo}');
          }
        } catch (e) {
          print('Error updating on server: $e. Payment status updated locally.');
          // Don't emit error - local update succeeded
        }
      } else {
        print('Network unavailable, payment status updated locally only');
      }

      // Delete from pending bills if payment is complete
      if (event.paymentStatus == 'PAID') {
        try {
          await _dbHelper.deleteSyncedBill(event.fnbBillNo);
          print('Removed bill from pending bills');
        } catch (e) {
          print('Error deleting synced bill: $e');
        }
      }

      emit(BillSubmitted(event.fnbBillNo));
    } catch (e) {
      print('Error in _onUpdatePaymentStatus: $e');
      emit(BillError(e.toString()));
    }
  }
}
