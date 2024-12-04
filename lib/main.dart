import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EventProvider(),
      child: MaterialApp(
        title: 'Calendar',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: CalendarPage(),
      ),
    );
  }
}

class EventProvider extends ChangeNotifier {
  Map<DateTime, List<String>> events = {};

  EventProvider() {
    _loadEvents();
  }

  // Load events from shared preferences
  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? eventsString = prefs.getString('events');
    if (eventsString != null) {
      final Map<String, dynamic> eventMap = jsonDecode(eventsString);
      eventMap.forEach((key, value) {
        DateTime date = DateTime.parse(key);
        events[date] = List<String>.from(value);
      });
      notifyListeners();
    }
  }

  // Save events to shared preferences
  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> eventMap = {};
    events.forEach((key, value) {
      eventMap[key.toIso8601String()] = value;
    });
    prefs.setString('events', jsonEncode(eventMap));
  }

  // Function to add events
  void addEvent(DateTime date, String event) {
    if (events[date] == null) {
      events[date] = [];
    }
    events[date]?.add(event);
    _saveEvents();
    notifyListeners();
  }



  // Function to remove events
  void removeEvent(DateTime date, String event) {
    events[date]?.remove(event);
    if (events[date]?.isEmpty ?? true) {
      events.remove(date);
    }
    _saveEvents();
    notifyListeners();
  }

  // Function to get events for a specific date
  List<String> getEvents(DateTime date) {
    return events[date] ?? [];
  }

  // Function to get all days with events
  List<DateTime> getDaysWithEvents() {
    return events.keys.toList();
  }

  // Function to check if a date has events
  bool hasEvent(DateTime date) {
    return events[date] != null && events[date]!.isNotEmpty;
  }
}

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Calendar "),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              _showEventDaysDialog(context);
            },
          )
        ],
      ),
      body: Column(
        children: [
          CalendarWidget(
            selectedDay: _selectedDay,
            onDaySelected: (selectedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
            },
          ),
          Expanded(child: EventListWidget(selectedDay: _selectedDay)),

        ],
      ),
    );
  }

  void _showEventDaysDialog(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final daysWithEvents = eventProvider.getDaysWithEvents();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Days with Events'),
        content: SingleChildScrollView(
          child: Column(
            children: daysWithEvents
                .map((day) => ListTile(
                      title: Text(day.toLocal().toString().split(' ')[0]),
                      subtitle: Text(eventProvider.getEvents(day).join(', ')),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}



// // Delete confirmation dialog
  void _showDeleteConfirmationDialog(
      BuildContext context, EventProvider eventProvider, DateTime day) {
    final eventController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event'),
        content: Column(
          children: [
            Text('Are you sure you want to delete this event?'),
            SizedBox(height: 10),
            TextField(
              controller: eventController,
              decoration: InputDecoration(hintText: 'Enter event to delete'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (eventController.text.isNotEmpty) {
                eventProvider.removeEvent(day, eventController.text);
              }
              Navigator.pop(context);
            },
            child: Text('Delete'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }


class CalendarWidget extends StatelessWidget {
  final DateTime selectedDay;
  final Function(DateTime) onDaySelected;

  CalendarWidget({required this.selectedDay, required this.onDaySelected});

  @override
  Widget build(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context);
    return TableCalendar(
      focusedDay: selectedDay,
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      onDaySelected: (selectedDay, focusedDay) {
        onDaySelected(selectedDay);
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          // Custom color for second Saturday and Sunday
          if (_isSecondSaturday(day) || day.weekday == DateTime.sunday) {
            return Container(
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(color: const Color.fromARGB(255, 236, 8, 8)),
                ),
              ),
            );
          }
          // Highlight events only for the selected day
          if (eventProvider.hasEvent(day) && isSameDay(day, selectedDay)) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }
          return null; // Default rendering for days without events
        },
      ),
    );
  }

  bool _isSecondSaturday(DateTime date) {
    // Check if the day is the second Saturday of the month
    DateTime firstDayOfMonth = DateTime(date.year, date.month, 1);
    int firstSaturday = (7 - firstDayOfMonth.weekday + DateTime.saturday) % 7;
    DateTime secondSaturday = firstDayOfMonth.add(Duration(days: firstSaturday + 7));
    return date.isAtSameMomentAs(secondSaturday);
  }
}

class EventListWidget extends StatelessWidget {
  final DateTime selectedDay;

  EventListWidget({required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context);
    return Column(
      children: [
                      SizedBox(height: 50,),

        Text("Events for ${selectedDay.toLocal()}"),
        ...eventProvider.getEvents(selectedDay).map((event) => ListTile(
              title: Text(event),
            )),
                      SizedBox(height: 40,),

        AddEventButton(selectedDay: selectedDay),
      ],
    );
  }
}

class AddEventButton extends StatelessWidget {
  final DateTime selectedDay;

  AddEventButton({required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    TextEditingController eventController = TextEditingController();

    return 

    ElevatedButton(
      onPressed: () async {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Add Event'),
            content: TextField(
              controller: eventController,
              decoration: InputDecoration(hintText: 'Enter event description'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (eventController.text.isNotEmpty) {
                    final eventProvider =
                        Provider.of<EventProvider>(context, listen: false);
                    eventProvider.addEvent(
                      selectedDay, // Add event for selected day
                      eventController.text,
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text('Add'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
      child: Text("Add Event"),
    );
  }
}
