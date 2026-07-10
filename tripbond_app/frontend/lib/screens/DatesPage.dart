import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../frontend/lib/screens/TripInfo.dart';

const List<String> _days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class DatesPage extends StatefulWidget {
  const DatesPage({super.key});

  @override
  State<DatesPage> createState() => _DatesPageState();
}

class _DatesPageState extends State<DatesPage> {
  // Useing late to initialize based on current date
  late int _currentMonth;
  late int _currentYear;
  int? _startDate;
  int? _endDate;

  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    //  to match the Dropdown items
    _currentMonth = _today.month - 1;
    _currentYear = _today.year;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _firstDayOfMonth(int year, int month) {
    return DateTime(year, month + 1, 1).weekday % 7;
  }

  bool _isPast(int day) {
    final cellDate = DateTime(_currentYear, _currentMonth + 1, day);
    return cellDate.isBefore(DateTime(_today.year, _today.month, _today.day));
  }

  void _handleDayTap(int day) {
    if (_isPast(day)) return;

    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = day;
        _endDate = null;
      } else if (day < _startDate!) {
        _endDate = _startDate;
        _startDate = day;
      } else {
        _endDate = day;
      }
    });
  }

  bool _isInRange(int day) {
    if (_startDate == null || _endDate == null) return false;
    return day >= _startDate! && day <= _endDate!;
  }

  bool _isEdge(int day) {
    return day == _startDate || day == _endDate;
  }

  bool _canGoBack() {
    if (_currentYear > _today.year) return true;
    return _currentMonth > (_today.month - 1);
  }

  void _prevMonth() {
    if (!_canGoBack()) return;
    setState(() {
      if (_currentMonth == 0) {
        _currentMonth = 11;
        _currentYear--;
      } else {
        _currentMonth--;
      }
      _startDate = null;
      _endDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 11) {
        _currentMonth = 0;
        _currentYear++;
      } else {
        _currentMonth++;
      }
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _daysInMonth(_currentYear, _currentMonth);
    final firstDay = _firstDayOfMonth(_currentYear, _currentMonth);
    final prevMonthDays = _currentMonth == 0
        ? _daysInMonth(_currentYear - 1, 11)
        : _daysInMonth(_currentYear, _currentMonth - 1);

    final totalCells = ((firstDay + daysInMonth + 6) ~/ 7) * 7;

    final cells = <_CalendarCell>[];
    for (int i = 0; i < totalCells; i++) {
      if (i < firstDay) {
        cells.add(
          _CalendarCell(
            day: prevMonthDays - firstDay + i + 1,
            isCurrentMonth: false,
          ),
        );
      } else if (i - firstDay < daysInMonth) {
        cells.add(_CalendarCell(day: i - firstDay + 1, isCurrentMonth: true));
      } else {
        cells.add(
          _CalendarCell(
            day: i - firstDay - daysInMonth + 1,
            isCurrentMonth: false,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(27, 50, 27, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const Text(
            'Choose Your Dates',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1, end: 0),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child:
                Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildMonthYearHeader(),
                          const SizedBox(height: 20),
                          _buildDayHeaders(),
                          const SizedBox(height: 8),
                          _buildCalendarGrid(cells),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.0, 1.0),
                    ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 24, 30, 40),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (_startDate != null) {
                    String monthName = _months[_currentMonth];
                    String range;
                    final startDate = DateTime(
                      _currentYear,
                      _currentMonth + 1,
                      _startDate!,
                    );
                    final endDate = _endDate != null
                        ? DateTime(_currentYear, _currentMonth + 1, _endDate!)
                        : startDate;
                    if (_endDate != null) {
                      range = "$_startDate-$_endDate $monthName";
                    } else {
                      range = "$_startDate $monthName";
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripInfo(
                          selectedDates: range,
                          startDate: startDate,
                          endDate: endDate,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4675B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Choose Dates',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _canGoBack() ? _prevMonth : null,
          child: Icon(
            Icons.chevron_left,
            color: _canGoBack() ? Colors.black : Colors.grey.shade300,
          ),
        ),
        Row(
          children: [
            _customDropdown<int>(
              value: _currentMonth,
              items: List.generate(
                12,
                (i) => DropdownMenuItem(value: i, child: Text(_months[i])),
              ),
              onChanged: (val) {
                if (val != null) {
                  if (_currentYear == _today.year && val < _today.month - 1) {
                    return;
                  }
                  setState(() {
                    _currentMonth = val;
                    _startDate = null;
                    _endDate = null;
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            _customDropdown<int>(
              value: _currentYear,
              // Generate years starting from the current year (2026+)
              items: List.generate(5, (i) {
                int year = _today.year + i;
                return DropdownMenuItem(value: year, child: Text('$year'));
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _currentYear = val;
                    if (_currentYear == _today.year &&
                        _currentMonth < _today.month - 1) {
                      _currentMonth = _today.month - 1;
                    }
                    _startDate = null;
                    _endDate = null;
                  });
                }
              },
            ),
          ],
        ),
        GestureDetector(
          onTap: _nextMonth,
          child: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _customDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down, size: 14),
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDayHeaders() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _days
          .map(
            (day) => SizedBox(
              width: 36,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid(List<_CalendarCell> cells) {
    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      final rowCells = cells.sublist(i, i + 7);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: rowCells.map((cell) {
              if (!cell.isCurrentMonth) {
                return const SizedBox(width: 36, height: 36);
              }

              final isPast = _isPast(cell.day);
              final inRange = _isInRange(cell.day);
              final isEdge = _isEdge(cell.day);

              return GestureDetector(
                onTap: () => _handleDayTap(cell.day),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isEdge
                        ? const Color(0xFF2D2D2D)
                        : (inRange
                              ? const Color(0xFF4675B8)
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${cell.day}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: isEdge || inRange
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isPast
                          ? Colors.grey.shade300
                          : (isEdge || inRange ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _CalendarCell {
  final int day;
  final bool isCurrentMonth;
  const _CalendarCell({required this.day, required this.isCurrentMonth});
}
