import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:table_calendar/table_calendar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DiaryApp());
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const ProfilePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
  }

  Future<void> _signInWithGitHub(BuildContext context) async {
    try {
      final provider = GithubAuthProvider();
      await FirebaseAuth.instance.signInWithProvider(provider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GitHub sign-in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Login to continue', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: () => _signInWithGoogle(context),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('Sign in with GitHub'),
                onPressed: () => _signInWithGitHub(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot> getEntries() {
    return FirebaseFirestore.instance
        .collection('diary_entries')
        .where('userEmail', isEqualTo: user?.email)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> _createEntry() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String feeling = "😊";

    await showDialog(
      context: context,
      builder: (context) {
        String localFeeling = feeling;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('New Entry'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: contentController, decoration: const InputDecoration(labelText: 'Content')),
                DropdownButton<String>(
                  value: localFeeling,
                  items: ["😊", "😢", "😡", "😴", "😍"].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setState(() => localFeeling = v ?? "😊"),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('diary_entries').add({
                      'userEmail': user?.email,
                      'date': DateTime.now(),
                      'title': titleController.text,
                      'feeling': localFeeling,
                      'content': contentController.text,
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEntry(DocumentSnapshot entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Feeling: ${entry['feeling']}"),
            const SizedBox(height: 8),
            Text(entry['content']),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _deleteEntry(String id) async {
    await FirebaseFirestore.instance.collection('diary_entries').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      Future.microtask(() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      ));
      return const SizedBox();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AgendaPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data?.docs ?? [];
          final total = entries.length;
          final Map<String, int> feelingCounts = {};
          for (var entry in entries) {
            final feeling = entry['feeling'] as String? ?? '';
            feelingCounts[feeling] = (feelingCounts[feeling] ?? 0) + 1;
          }
          final feelingsList = feelingCounts.entries.toList();
          feelingsList.sort((a, b) => b.value.compareTo(a.value));
          final last2 = entries.take(2).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        user?.displayName ?? user?.email ?? "User",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text("Total entries: $total", style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                if (feelingsList.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Feelings usage:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ...feelingsList.map((e) {
                        final percent = (e.value / total * 100).toStringAsFixed(1);
                        return Text("${e.key} - $percent%");
                      }),
                    ],
                  ),
                const SizedBox(height: 16),
                const Text("Last 2 entries:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ...last2.map((entry) {
                  final date = (entry['date'] as Timestamp).toDate();
                  return Card(
                    child: ListTile(
                      leading: Text(entry['feeling'], style: const TextStyle(fontSize: 24)),
                      title: Text(entry['title']),
                      subtitle: Text('${date.toLocal().toString().split(' ')[0]}'),
                      onTap: () => _showEntry(entry),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text("All entries:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ...entries.map((entry) {
                  final date = (entry['date'] as Timestamp).toDate();
                  return ListTile(
                    leading: Text(entry['feeling'], style: const TextStyle(fontSize: 24)),
                    title: Text(entry['title']),
                    subtitle: Text('${date.toLocal().toString().split(' ')[0]}'),
                    onTap: () => _showEntry(entry),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEntry(entry.id),
                    ),
                  );
                }),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEntry,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final user = FirebaseAuth.instance.currentUser;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Stream<QuerySnapshot> getEntriesForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return FirebaseFirestore.instance
        .collection('diary_entries')
        .where('userEmail', isEqualTo: user?.email)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .orderBy('date', descending: true)
        .snapshots();
  }

  void _showEntry(DocumentSnapshot entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Feeling: ${entry['feeling']}"),
            const SizedBox(height: 8),
            Text(entry['content']),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('diary_entries').doc(entry.id).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                _selectedDay != null &&
                day.year == _selectedDay!.year &&
                day.month == _selectedDay!.month &&
                day.day == _selectedDay!.day,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getEntriesForDay(_selectedDay ?? DateTime.now()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snapshot.data?.docs ?? [];
                if (entries.isEmpty) {
                  return const Center(child: Text('No entries for this day.'));
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    final date = (entry['date'] as Timestamp).toDate();
                    return ListTile(
                      leading: Text(entry['feeling'], style: const TextStyle(fontSize: 24)),
                      title: Text(entry['title']),
                      subtitle: Text('${date.toLocal().toString().split(' ')[0]}'),
                      onTap: () => _showEntry(entry),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('diary_entries').doc(entry.id).delete();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}