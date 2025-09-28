import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../l10n/app_localizations.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, dynamic>? _exportSummary;
  bool _isLoadingSummary = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // Pre-select current month as default range
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(
      now.year,
      now.month + 1,
      0,
    ); // Last day of current month
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (_startDate == null || _endDate == null) {
      setState(() {
        _exportSummary = null;
      });
      return;
    }

    setState(() {
      _isLoadingSummary = true;
    });

    try {
      final transactions = await DatabaseHelper.instance
          .getTransactionsByDateRange(_startDate!, _endDate!);

      double totalIncome = 0;
      double totalExpenses = 0;

      for (final transaction in transactions) {
        if (transaction.isIncome) {
          totalIncome += transaction.amount;
        } else {
          totalExpenses += transaction.amount;
        }
      }

      final summary = {
        'totalTransactions': transactions.length,
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'netBalance': totalIncome - totalExpenses,
        'dateRange':
            '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
      };

      setState(() {
        _exportSummary = summary;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorLoadingSummary(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _exportCSV() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectDates),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.endDateAfterStart),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      await _exportAndShareTransactions(_startDate!, _endDate!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.csvExportedSuccessfully,
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.exportFailed(e.toString()),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.exportData)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Export summary card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assessment, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.exportSummary,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isLoadingSummary)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_exportSummary != null) ...[
                    _SummaryRow(
                      label: AppLocalizations.of(context)!.period,
                      value: _exportSummary!['dateRange'],
                      icon: Icons.date_range,
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: AppLocalizations.of(context)!.totalTransactions,
                      value: _exportSummary!['totalTransactions'].toString(),
                      icon: Icons.receipt_long,
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: AppLocalizations.of(context)!.totalIncome,
                      value: currencyFormatter.format(
                        _exportSummary!['totalIncome'],
                      ),
                      icon: Icons.trending_up,
                      valueColor: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: AppLocalizations.of(context)!.totalExpenses,
                      value: currencyFormatter.format(
                        _exportSummary!['totalExpenses'],
                      ),
                      icon: Icons.trending_down,
                      valueColor: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: AppLocalizations.of(context)!.netBalance,
                      value: currencyFormatter.format(
                        _exportSummary!['netBalance'],
                      ),
                      icon: Icons.account_balance,
                      valueColor: _exportSummary!['netBalance'] >= 0
                          ? Colors.blue
                          : Colors.orange,
                    ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          AppLocalizations.of(context)!.selectDateRangeToSee,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Date range selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.selectDateRange,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start Date
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.startDate,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _startDate = picked;
                                  });
                                  _loadSummary();
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _startDate != null
                                          ? DateFormat(
                                              'MMM dd, yyyy',
                                            ).format(_startDate!)
                                          : AppLocalizations.of(
                                              context,
                                            )!.selectStartDate,
                                      style: TextStyle(
                                        color: _startDate != null
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // End Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.endDate,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: _startDate ?? DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _endDate = picked;
                                  });
                                  _loadSummary();
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _endDate != null
                                          ? DateFormat(
                                              'MMM dd, yyyy',
                                            ).format(_endDate!)
                                          : AppLocalizations.of(
                                              context,
                                            )!.selectEndDate,
                                      style: TextStyle(
                                        color: _endDate != null
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Export button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _startDate != null && _endDate != null && !_isExporting
                      ? _exportCSV
                      : null,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.file_download),
                  label: Text(
                    _isExporting
                        ? AppLocalizations.of(context)!.exporting
                        : AppLocalizations.of(context)!.exportAndShareCSV,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAndShareTransactions(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Get transactions for date range
      final transactions = await DatabaseHelper.instance
          .getTransactionsByDateRange(startDate, endDate);

      if (transactions.isEmpty) {
        throw Exception('No transactions found for selected date range');
      }

      // Sort transactions by date
      transactions.sort((a, b) => a.date.compareTo(b.date));

      // Generate CSV content
      final csvContent = _generateCSVContent(transactions);

      // Generate filename
      final fileName = _generateFileName(startDate, endDate);

      // Write to file and share
      await _writeAndShareCSV(csvContent, fileName);
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  String _generateCSVContent(List<Transaction> transactions) {
    final List<List<String>> rows = [];

    // Add header
    rows.add(['Date', 'Title', 'Amount', 'Type', 'Category', 'Description']);

    // Add transaction data
    for (final transaction in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(transaction.date),
        transaction.title,
        transaction.amount.toStringAsFixed(2),
        transaction.type.name.toUpperCase(),
        transaction.category.displayName,
        transaction.description ?? '',
      ]);
    }

    // Convert to CSV string using csv package
    return const ListToCsvConverter().convert(rows);
  }

  String _generateFileName(DateTime startDate, DateTime endDate) {
    return 'expense_tracker_${DateFormat('yyyy_MM_dd').format(startDate)}_to_${DateFormat('yyyy_MM_dd').format(endDate)}.csv';
  }

  Future<void> _writeAndShareCSV(String csvContent, String fileName) async {
    try {
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');

      // Write CSV content to file
      await file.writeAsString(csvContent, encoding: utf8);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Expense Tracker Export - $fileName',
        subject: 'Financial Data Export',
      );
    } catch (e) {
      // Fallback to showing content in dialog if sharing fails
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.exportContent),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.failedToShareFile(e.toString()),
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.csvContent),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: SelectableText(csvContent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
        );
      }
      throw Exception('Failed to share CSV file: $e');
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
