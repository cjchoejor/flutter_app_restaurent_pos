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

        // If online submission succeeds, delete from local storage
        print(
            'Successfully submitted all bill data online, removing from local storage');
        await _dbHelper.deleteSyncedBill(event.billSummary.fnbBillNo);
        print('Successfully removed bill from local storage');
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
      );

      if (summaryResponse.statusCode != 200) {
        throw Exception('Failed to load bill summary: ${summaryResponse.body}');
      }

      final summary =
          BillSummaryModel.fromJson(jsonDecode(summaryResponse.body));

      final detailsResponse = await http.get(
        Uri.parse(
            '$baseUrl/api/fnb_bill_details_legphel_eats?fnb_bill_no=${event.fnbBillNo}'),
      );

      if (detailsResponse.statusCode != 200) {
        throw Exception('Failed to load bill details: ${detailsResponse.body}');
      }

      final List<dynamic> detailsJson = jsonDecode(detailsResponse.body);
      final details =
          detailsJson.map((json) => BillDetailsModel.fromJson(json)).toList();

      emit(BillLoaded(billSummary: summary, billDetails: details));
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

      final isConnected = await _networkService.isConnected();
      final isServerAvailable = await _networkService.isServerAvailable();

      if (!isConnected || !isServerAvailable) {
        print('Network unavailable, cannot update payment status');
        emit(BillError('Network unavailable'));
        return;
      }

      // Try to update payment status online
      try {
        // First fetch the current bill data to preserve existing fields
        Map<String, dynamic> currentBill;
        
        final fetchResponse = await http.get(
          Uri.parse(
              '$baseUrl/api/fnb_bill_summary_legphel_eats/${event.fnbBillNo}'),
        );

        if (fetchResponse.statusCode == 200) {
          // Bill exists on server, use server data
          currentBill = jsonDecode(fetchResponse.body);
          print('Fetched bill data from server');
        } else {
          // Bill doesn't exist on server yet, try to get from local database
          print('Bill not found on server (${fetchResponse.statusCode}), trying local database');
          final localData = await _dbHelper.getBillSummaryData(event.fnbBillNo);
          if (localData == null) {
            throw Exception('Bill not found on server or in local database');
          }
          currentBill = localData;
          print('Using bill data from local database');
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
        );

        if (response.statusCode != 200) {
          throw Exception(
              'Failed to update payment status: ${response.body}');
        }

        print('Successfully updated payment status for ${event.fnbBillNo}');

        // Update local SQLite database with new payment status
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
        }

        // Delete from pending bills if payment is complete
        if (event.paymentStatus == 'PAID') {
          await _dbHelper.deleteSyncedBill(event.fnbBillNo);
          print('Removed bill from pending bills');
        }

        emit(BillSubmitted(event.fnbBillNo));
      } catch (e) {
        print('Error updating payment status: $e');
        emit(BillError(e.toString()));
      }
    } catch (e) {
      print('Error in _onUpdatePaymentStatus: $e');
      emit(BillError(e.toString()));
    }
  }
}
