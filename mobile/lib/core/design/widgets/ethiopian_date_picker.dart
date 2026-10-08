import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/utils/ethiopian_calendar.dart';
import 'package:fikir/core/utils/ethiopic_numerals.dart';
import 'package:flutter/material.dart';

class EthiopianDatePickerDialog extends StatefulWidget {
  const EthiopianDatePickerDialog({
    required this.initialDate, super.key,
    this.useEthiopicNumerals = false,
  });

  final DateTime initialDate;
  final bool useEthiopicNumerals;

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    bool useEthiopicNumerals = false,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => EthiopianDatePickerDialog(
        initialDate: initialDate,
        useEthiopicNumerals: useEthiopicNumerals,
      ),
    );
  }

  @override
  State<EthiopianDatePickerDialog> createState() => _EthiopianDatePickerDialogState();
}

class _EthiopianDatePickerDialogState extends State<EthiopianDatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final ethDate = EthiopianDate.fromGregorian(widget.initialDate);
    _selectedYear = ethDate.year;
    _selectedMonth = ethDate.month;
    _selectedDay = ethDate.day;
  }

  int get _maxDays {
    if (_selectedMonth < 13) return 30;
    return (_selectedYear % 4 == 3) ? 6 : 5;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDay > _maxDays) {
      _selectedDay = _maxDays;
    }

    final currentEth = EthiopianDate(
      year: _selectedYear,
      month: _selectedMonth,
      day: _selectedDay,
    );
    final gregorian = currentEth.toGregorian();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'የኢትዮጵያ ቀን መቁጠሪያ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            '${currentEth.monthNameAmharic} ${_formatNum(_selectedDay)}፣ ${_formatNum(_selectedYear)} ዓ.ም.',
            style: const TextStyle(
              color: FikirColors.primaryCoral,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          Text(
            'Gregorian: ${gregorian.year}-${gregorian.month.toString().padLeft(2, '0')}-${gregorian.day.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month Dropdown
            DropdownButtonFormField<int>(
              initialValue: _selectedMonth,
              decoration: const InputDecoration(labelText: 'ወር / Month'),
              items: List.generate(13, (index) {
                final m = index + 1;
                final name = EthiopianDate.monthNamesAmharic[index];
                return DropdownMenuItem(
                  value: m,
                  child: Text('$name (${EthiopianDate.monthNamesEnglish[index]})'),
                );
              }),
              onChanged: (val) {
                if (val != null) setState(() => _selectedMonth = val);
              },
            ),
            const SizedBox(height: 12),
            // Day Dropdown
            DropdownButtonFormField<int>(
              initialValue: _selectedDay,
              decoration: const InputDecoration(labelText: 'ቀን / Day'),
              items: List.generate(_maxDays, (index) {
                final d = index + 1;
                return DropdownMenuItem(
                  value: d,
                  child: Text(_formatNum(d)),
                );
              }),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDay = val);
              },
            ),
            const SizedBox(height: 12),
            // Year Dropdown
            DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              decoration: const InputDecoration(labelText: 'ዓመት / Year'),
              items: List.generate(80, (index) {
                final y = 2025 - index; // Covers 1945 to 2025 EC
                return DropdownMenuItem(
                  value: y,
                  child: Text(_formatNum(y)),
                );
              }),
              onChanged: (val) {
                if (val != null) setState(() => _selectedYear = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ሰርዝ / Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FikirColors.primaryCoral,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop(gregorian);
          },
          child: const Text('አረጋግጥ / Select'),
        ),
      ],
    );
  }

  String _formatNum(int n) {
    if (widget.useEthiopicNumerals) {
      return EthiopicNumerals.toEthiopic(n);
    }
    return n.toString();
  }
}
