import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:math';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ClubConnectApp());
}

class ClubConnectApp extends StatelessWidget {
  const ClubConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClubConnect',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101012),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.pinkAccent,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ══════════════════════════════════════════
// UTILITAIRES
// ══════════════════════════════════════════
String generateClubCode() {
  const words = ['WOLF', 'BULL', 'HAWK', 'LION', 'BEAR', 'LYNX', 'FOX', 'PUMA'];
  final rng = Random();
  return '${words[rng.nextInt(words.length)]}-${rng.nextInt(9000) + 1000}';
}

String formatDate(String iso) {
  try {
    final d = DateTime.parse(iso);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return iso;
  }
}

String formatTime(String iso) {
  try {
    final d = DateTime.parse(iso);
    return '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

// Rôles disponibles
const List<String> kPredefinedRoles = [
  'Président',
  'Manager',
  'Coach',
  'Trésorier',
  'Communication',
  'Bénévole',
  'Joueur',
  'Arbitre',
];

Color roleColor(String role) {
  switch (role) {
    case 'Président': return Colors.amber;
    case 'Manager': return Colors.pinkAccent;
    case 'Coach': return Colors.orangeAccent;
    case 'Trésorier': return Colors.greenAccent;
    case 'Communication': return Colors.purpleAccent;
    case 'Bénévole': return Colors.tealAccent;
    case 'Arbitre': return Colors.redAccent;
    default: return Colors.blueAccent;
  }
}

// ══════════════════════════════════════════
// AUTH GATE
// ══════════════════════════════════════════
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnapshot.hasData) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final role = userData['role'] as String?;
            if (role == null || role == 'pending') return const ClubSelectionScreen();
            return const MainShell();
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// LOGIN SCREEN
// ══════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'pending',
          'clubId': null,
          'avatarColor': Random().nextInt(0xFFFFFF) + 0xFF000000,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erreur'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.shield_rounded, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text('ClubConnect', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_isLogin ? 'Connecte-toi à ton club' : 'Crée ton compte',
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 40),
              if (!_isLogin) _field(_nameController, 'Nom complet', Icons.person_outline),
              _field(_emailController, 'Email', Icons.email_outlined),
              _field(_passwordController, 'Mot de passe', Icons.lock_outline, obscure: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(_isLogin ? 'SE CONNECTER' : "S'INSCRIRE",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                    _isLogin ? "Pas de compte ? S'inscrire" : 'Déjà un compte ? Se connecter',
                    style: const TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// CLUB SELECTION SCREEN
// ══════════════════════════════════════════
class ClubSelectionScreen extends StatefulWidget {
  const ClubSelectionScreen({super.key});
  @override
  State<ClubSelectionScreen> createState() => _ClubSelectionScreenState();
}

class _ClubSelectionScreenState extends State<ClubSelectionScreen> {
  final _codeController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _sportController = TextEditingController();
  final _cityController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createClub() async {
    if (_clubNameController.text.trim().isEmpty) {
      _showError('Donne un nom à ton club.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final db = FirebaseFirestore.instance;
      String clubCode;
      bool codeExists = true;
      do {
        clubCode = generateClubCode();
        final existing = await db.collection('clubs').where('clubCode', isEqualTo: clubCode).limit(1).get();
        codeExists = existing.docs.isNotEmpty;
      } while (codeExists);

      final clubRef = await db.collection('clubs').add({
        'name': _clubNameController.text.trim(),
        'sport': _sportController.text.trim(),
        'city': _cityController.text.trim(),
        'description': _descController.text.trim(),
        'clubCode': clubCode,
        'adminId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'channels': ['Général', 'Compétiteurs', 'Loisirs'],
        'customRoles': [],
      });

      await db.collection('users').doc(user.uid).update({
        'role': 'manager',
        'clubId': clubRef.id,
        'customRole': 'Président',
      });
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinClub() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showError("Entre un code d'invitation.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final db = FirebaseFirestore.instance;
      final result = await db.collection('clubs').where('clubCode', isEqualTo: code).limit(1).get();
      if (result.docs.isEmpty) {
        _showError('Code invalide. Vérifie auprès de ton coach.');
        setState(() => _isLoading = false);
        return;
      }
      await db.collection('users').doc(user.uid).update({
        'role': 'player',
        'clubId': result.docs.first.id,
        'customRole': 'Joueur',
      });
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Bienvenue 👋', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: Colors.blueAccent,
            tabs: [Tab(text: 'CRÉER UN CLUB'), Tab(text: 'REJOINDRE')],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_buildCreate(), _buildJoin()]),
      ),
    );
  }

  Widget _buildCreate() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tu es coach ou admin ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Crée ton club et partage le code à tes joueurs.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 32),
        _field(_clubNameController, 'Nom du club *', Icons.shield_outlined),
        _field(_sportController, 'Sport (ex: Badminton)', Icons.sports_tennis),
        _field(_cityController, 'Ville', Icons.location_city),
        _field(_descController, 'Description du club', Icons.info_outline, maxLines: 3),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _createClub,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text('CRÉER MON CLUB',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _buildJoin() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tu es joueur ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Entre le code que ton coach t'a communiqué.", style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 32),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: "Code (ex: WOLF-4829)",
            prefixIcon: const Icon(Icons.key_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.withOpacity(0.15),
              side: const BorderSide(color: Colors.greenAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _joinClub,
            icon: const Icon(Icons.login, color: Colors.greenAccent),
            label: const Text('REJOINDRE LE CLUB',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: maxLines == 1 ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// MAIN SHELL
// ══════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Map<String, dynamic>? _userData;
  String? _clubId;
  String? _role;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        _userData = snap.data!.data() as Map<String, dynamic>;
        _clubId = _userData!['clubId'] as String?;
        _role = _userData!['role'] as String? ?? 'player';

        final isManager = _role == 'manager';
        final screens = [
          HomeTab(clubId: _clubId!, userData: _userData!, isManager: isManager),
          EventsTab(clubId: _clubId!, userData: _userData!, isManager: isManager),
          MessagingTab(clubId: _clubId!, isManager: isManager),
          MembersTab(clubId: _clubId!, isManager: isManager),
          SettingsTab(clubId: _clubId!, userData: _userData!, isManager: isManager),
        ];

        return Scaffold(
          body: screens[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: const Color(0xFF18181B),
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.white38,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Accueil'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Événements'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
              BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: 'Membres'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Paramètres'),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 1 — ACCUEIL
// ══════════════════════════════════════════
class HomeTab extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;
  final bool isManager;
  const HomeTab({super.key, required this.clubId, required this.userData, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return SafeArea(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
        builder: (context, clubSnap) {
          if (!clubSnap.hasData) return const Center(child: CircularProgressIndicator());
          final club = clubSnap.data!.data() as Map<String, dynamic>;
          final clubName = club['name'] as String? ?? 'Mon Club';
          final sport = club['sport'] as String? ?? '';
          final city = club['city'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header : Logo + Nom du club
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2F4A), Color(0xFF0D1B2A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Column(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity(0.15),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        clubName.isNotEmpty ? clubName[0].toUpperCase() : 'C',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(clubName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  if (sport.isNotEmpty || city.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$sport${sport.isNotEmpty && city.isNotEmpty ? ' · ' : ''}$city',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isManager ? Colors.pinkAccent : Colors.blueAccent).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: (isManager ? Colors.pinkAccent : Colors.blueAccent).withOpacity(0.4)),
                    ),
                    child: Text(isManager ? '⚡ Manager' : '🏃 Joueur',
                        style: TextStyle(
                            color: isManager ? Colors.pinkAccent : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // Prochain événement
              const Text('Prochain événement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .where('clubId', isEqualTo: clubId)
                    .orderBy('startDate')
                    .limit(1)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Text('Aucun événement à venir.',
                          style: TextStyle(color: Colors.white54)),
                    );
                  }
                  final doc = snap.data!.docs.first;
                  final data = doc.data() as Map<String, dynamic>;
                  final attendees = data['attendees'] as List? ?? [];
                  return _EventMiniCard(
                      data: data,
                      eventId: doc.id,
                      attendees: attendees,
                      amIPresent: attendees.contains(uid),
                      uid: uid);
                },
              ),
              const SizedBox(height: 24),

              // Stats
              const Text('Aperçu du club', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('clubId', isEqualTo: clubId)
                    .snapshots(),
                builder: (context, snap) {
                  final memberCount = snap.data?.docs.length ?? 0;
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .where('clubId', isEqualTo: clubId)
                        .snapshots(),
                    builder: (context, evSnap) {
                      final eventCount = evSnap.data?.docs.length ?? 0;
                      return Row(children: [
                        _StatCard(
                            icon: Icons.group,
                            label: 'Membres',
                            value: '$memberCount',
                            color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        _StatCard(
                            icon: Icons.calendar_month,
                            label: 'Événements',
                            value: '$eventCount',
                            color: Colors.pinkAccent),
                      ]);
                    },
                  );
                },
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// SYSTÈME DE PRÉSENCE (présent/absent/sais pas)
// ══════════════════════════════════════════

// Statuts possibles
const String kPresent = 'present';
const String kAbsent = 'absent';
const String kMaybe = 'maybe';

String myStatus(Map<String, dynamic> data, String uid) {
  final present = (data['attendees'] as List? ?? []);
  final absent = (data['absentees'] as List? ?? []);
  final maybe = (data['maybes'] as List? ?? []);
  if (present.contains(uid)) return kPresent;
  if (absent.contains(uid)) return kAbsent;
  if (maybe.contains(uid)) return kMaybe;
  return '';
}

Future<void> setStatus(String eventId, String uid, String newStatus) async {
  final ref = FirebaseFirestore.instance.collection('events').doc(eventId);
  // Retirer des 3 listes d'abord
  await ref.update({
    'attendees': FieldValue.arrayRemove([uid]),
    'absentees': FieldValue.arrayRemove([uid]),
    'maybes': FieldValue.arrayRemove([uid]),
  });
  // Puis ajouter dans la bonne liste
  if (newStatus == kPresent) {
    await ref.update({'attendees': FieldValue.arrayUnion([uid])});
  } else if (newStatus == kAbsent) {
    await ref.update({'absentees': FieldValue.arrayUnion([uid])});
  } else if (newStatus == kMaybe) {
    await ref.update({'maybes': FieldValue.arrayUnion([uid])});
  }
}

// Widget 3 boutons style SportEasy
class _PresenceButtons extends StatelessWidget {
  final String eventId, uid, currentStatus;
  const _PresenceButtons(
      {required this.eventId, required this.uid, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatusBtn(
        label: 'Présent', icon: Icons.check_circle_outline,
        color: Colors.greenAccent, isSelected: currentStatus == kPresent,
        onTap: () => setStatus(eventId, uid, currentStatus == kPresent ? '' : kPresent),
      )),
      const SizedBox(width: 8),
      Expanded(child: _StatusBtn(
        label: 'Absent', icon: Icons.cancel_outlined,
        color: Colors.redAccent, isSelected: currentStatus == kAbsent,
        onTap: () => setStatus(eventId, uid, currentStatus == kAbsent ? '' : kAbsent),
      )),
      const SizedBox(width: 8),
      Expanded(child: _StatusBtn(
        label: '?', icon: Icons.help_outline,
        color: Colors.orangeAccent, isSelected: currentStatus == kMaybe,
        onTap: () => setStatus(eventId, uid, currentStatus == kMaybe ? '' : kMaybe),
      )),
    ]);
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _StatusBtn({required this.label, required this.icon, required this.color,
      required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 1.5 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: isSelected ? color : Colors.white38, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
              color: isSelected ? color : Colors.white38,
              fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// Liste des membres par statut (style SportEasy)
class _AttendeesList extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> eventData;
  const _AttendeesList({required this.clubId, required this.eventData});

  @override
  Widget build(BuildContext context) {
    final present = (eventData['attendees'] as List? ?? []).cast<String>();
    final absent = (eventData['absentees'] as List? ?? []).cast<String>();
    final maybe = (eventData['maybes'] as List? ?? []).cast<String>();
    final total = present.length + absent.length + maybe.length;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').where('clubId', isEqualTo: clubId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final users = {for (var d in snap.data!.docs) d.id: d.data() as Map<String, dynamic>};

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Compteurs résumé
          Row(children: [
            _CountChip(count: present.length, color: Colors.greenAccent, label: 'Présents'),
            const SizedBox(width: 8),
            _CountChip(count: absent.length, color: Colors.redAccent, label: 'Absents'),
            const SizedBox(width: 8),
            _CountChip(count: maybe.length, color: Colors.orangeAccent, label: '?'),
            const Spacer(),
            Text('$total réponses', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          const SizedBox(height: 12),

          // Liste présents
          if (present.isNotEmpty) ...[
            _listHeader('✅  Présents', present.length, Colors.greenAccent),
            ...present.map((uid) => _UserTile(userData: users[uid], color: Colors.greenAccent)),
            const SizedBox(height: 8),
          ],

          // Liste absents
          if (absent.isNotEmpty) ...[
            _listHeader('❌  Absents', absent.length, Colors.redAccent),
            ...absent.map((uid) => _UserTile(userData: users[uid], color: Colors.redAccent)),
            const SizedBox(height: 8),
          ],

          // Liste incertains
          if (maybe.isNotEmpty) ...[
            _listHeader('❓  Incertains', maybe.length, Colors.orangeAccent),
            ...maybe.map((uid) => _UserTile(userData: users[uid], color: Colors.orangeAccent)),
          ],
        ]);
      },
    );
  }

  Widget _listHeader(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Text('($count)', style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
      ]),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _CountChip({required this.count, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
      ]),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final Color color;
  const _UserTile({required this.userData, required this.color});

  @override
  Widget build(BuildContext context) {
    final name = userData?['name'] as String? ?? 'Joueur';
    final customRole = userData?['customRole'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.15),
          child: Text(name[0].toUpperCase(),
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (customRole.isNotEmpty)
            Text(customRole, style: TextStyle(color: roleColor(customRole), fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _EventMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String eventId, uid;
  final List attendees;
  final bool amIPresent;
  const _EventMiniCard(
      {required this.data,
      required this.eventId,
      required this.attendees,
      required this.amIPresent,
      required this.uid});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'Autre';
    final status = myStatus(data, uid);
    final color = status == kPresent
        ? Colors.greenAccent
        : status == kAbsent
            ? Colors.redAccent
            : status == kMaybe
                ? Colors.orangeAccent
                : Colors.white38;
    final statusLabel = status == kPresent
        ? '✓ Présent'
        : status == kAbsent
            ? '✗ Absent'
            : status == kMaybe
                ? '? Incertain'
                : 'Répondre';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (type == 'Match' ? Colors.pinkAccent : Colors.blueAccent).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(type == 'Match' ? Icons.emoji_events : Icons.fitness_center,
              color: type == 'Match' ? Colors.pinkAccent : Colors.blueAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text('${formatDate(data['startDate'] ?? '')} · ${formatTime(data['startDate'] ?? '')}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(data['location'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(statusLabel,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 2 — ÉVÉNEMENTS
// ══════════════════════════════════════════
class EventsTab extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;
  final bool isManager;
  const EventsTab(
      {super.key, required this.clubId, required this.userData, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Événements', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: isManager
            ? [
                IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.pinkAccent, size: 28),
                    onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: const Color(0xFF1C1C1E),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                          builder: (_) => CreateEventSheet(clubId: clubId),
                        ))
              ]
            : null,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .orderBy('startDate')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.calendar_today, size: 48, color: Colors.white24),
              SizedBox(height: 12),
              Text('Aucun événement prévu.', style: TextStyle(color: Colors.white54)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              final doc = snap.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _EventCard(
                  data: data,
                  eventId: doc.id,
                  uid: uid,
                  isManager: isManager,
                  clubId: clubId);
            },
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String eventId, uid, clubId;
  final bool isManager;
  const _EventCard(
      {required this.data,
      required this.eventId,
      required this.uid,
      required this.isManager,
      required this.clubId});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'Autre';
    final isMatch = type == 'Match';
    final color = isMatch ? Colors.pinkAccent : Colors.blueAccent;
    final status = myStatus(data, uid);
    final present = (data['attendees'] as List? ?? []);
    final absent = (data['absentees'] as List? ?? []);
    final maybe = (data['maybes'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(isMatch ? Icons.emoji_events : Icons.fitness_center, color: color, size: 18),
              const SizedBox(width: 8),
              Text(type.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            Row(children: [
              // Compteurs rapides
              _miniCount(present.length, Colors.greenAccent, Icons.check_circle, context),
              const SizedBox(width: 6),
              _miniCount(absent.length, Colors.redAccent, Icons.cancel, context),
              const SizedBox(width: 6),
              _miniCount(maybe.length, Colors.orangeAccent, Icons.help, context),
              if (isManager) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF1C1C1E),
                              title: const Text("Supprimer l'événement ?"),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Annuler')),
                                TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Supprimer',
                                        style: TextStyle(color: Colors.redAccent))),
                              ],
                            ));
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
                    }
                  },
                  child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                ),
              ],
            ]),
          ]),
        ),

        // ── Body ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['title'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _infoRow(Icons.calendar_today,
                '${formatDate(data['startDate'] ?? '')} · ${formatTime(data['startDate'] ?? '')} → ${formatTime(data['endDate'] ?? '')}'),
            _infoRow(Icons.location_on, data['location'] ?? 'À définir'),
            if ((data['description'] as String? ?? '').isNotEmpty)
              _infoRow(Icons.info_outline, data['description']),
            if ((data['recurrence'] as String? ?? 'Aucune') != 'Aucune')
              _infoRow(Icons.repeat, data['recurrence']),
            const SizedBox(height: 16),

            // ── 3 boutons de présence ──
            _PresenceButtons(eventId: eventId, uid: uid, currentStatus: status),
            const SizedBox(height: 16),

            // ── Liste des participants ──
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            _AttendeesList(clubId: clubId, eventData: data),
          ]),
        ),
      ]),
    );
  }

  Widget _miniCount(int count, Color color, IconData icon, BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 3),
      Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13))),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// SHEET — CRÉER UN ÉVÉNEMENT
// ══════════════════════════════════════════
class CreateEventSheet extends StatefulWidget {
  final String clubId;
  const CreateEventSheet({super.key, required this.clubId});
  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'Entraînement';
  String _recurrence = 'Aucune';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1, hours: 2));
  bool _loading = false;

  Future<void> _pickStart() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _startDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startDate));
    if (time == null) return;
    setState(() =>
        _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _endDate,
        firstDate: _startDate,
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_endDate));
    if (time == null) return;
    setState(
        () => _endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('events').add({
      'title': _titleController.text.trim(),
      'type': _type,
      'location': _locationController.text.trim(),
      'description': _descController.text.trim(),
      'startDate': _startDate.toIso8601String(),
      'endDate': _endDate.toIso8601String(),
      'recurrence': _recurrence,
      'attendees': [],
      'absentees': [],
      'maybes': [],
      'clubId': widget.clubId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Nouvel événement',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                    labelText: 'Titre *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _typeChip('Entraînement', Icons.fitness_center, Colors.blueAccent)),
                const SizedBox(width: 10),
                Expanded(child: _typeChip('Match', Icons.emoji_events, Colors.pinkAccent)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateTile('Début', _startDate, _pickStart)),
                const SizedBox(width: 10),
                Expanded(child: _dateTile('Fin', _endDate, _pickEnd)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                    labelText: 'Lieu',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _recurrence,
                decoration: InputDecoration(
                    labelText: 'Récurrence',
                    prefixIcon: const Icon(Icons.repeat),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05)),
                items: ['Aucune', 'Hebdomadaire', 'Bimensuelle', 'Mensuelle']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _recurrence = v!),
                dropdownColor: const Color(0xFF1C1C1E),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('CRÉER L\'ÉVÉNEMENT',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ]),
      ),
    );
  }

  Widget _typeChip(String label, IconData icon, Color color) {
    final selected = _type == label;
    return GestureDetector(
      onTap: () => setState(() => _type = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.white12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? color : Colors.white38, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? color : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _dateTile(String label, DateTime dt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 4),
          Text(formatDate(dt.toIso8601String()), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(formatTime(dt.toIso8601String()),
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 3 — MESSAGERIE (style WhatsApp)
// ══════════════════════════════════════════

// Modèle d'un canal Firestore
// Structure dans Firestore collection 'channels' (sous-collection du club) :
// { name, type: 'public'|'private', members: [uid...], lastMessage, lastMessageAt, createdBy }

class MessagingTab extends StatefulWidget {
  final String clubId;
  final bool isManager;
  const MessagingTab({super.key, required this.clubId, required this.isManager});
  @override
  State<MessagingTab> createState() => _MessagingTabState();
}

class _MessagingTabState extends State<MessagingTab> {
  // ignore unused field warning — kept for compatibility
  String _selectedChannel = 'Général';

  Future<void> _createChannel() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    // Charger les membres du club
    final membersSnap = await FirebaseFirestore.instance
        .collection('users').where('clubId', isEqualTo: widget.clubId).get();
    final others = membersSnap.docs.where((d) => d.id != currentUid).toList();

    if (!mounted) return;

    // Sheet de création de canal avec nom + sélection des membres
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CreateChannelSheet(members: others, currentUid: currentUid),
    );

    if (result != null) {
      final name = result['name'] as String;
      final selectedMembers = result['members'] as List<String>;
      // Inclure le créateur
      final allMembers = [...selectedMembers, currentUid];
      await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('channels').add({
        'name': name,
        'type': 'group',
        'members': allMembers,
        'createdBy': currentUid,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        elevation: 0,
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (widget.isManager)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 28),
              onPressed: _createChannel,
            ),
        ],
      ),
      // Liste style WhatsApp de toutes les conversations
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs').doc(widget.clubId)
            .collection('channels')
            .where('members', arrayContains: uid)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.chat_bubble_outline, size: 56, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 16),
              const Text('Aucune conversation', style: TextStyle(color: Colors.white38, fontSize: 16)),
              const SizedBox(height: 8),
              if (widget.isManager)
                const Text('Crée un canal avec le bouton +',
                    style: TextStyle(color: Colors.white24, fontSize: 13)),
            ]));
          }

          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final ch = docs[i].data() as Map<String, dynamic>;
              final chId = docs[i].id;
              final chName = ch['name'] as String? ?? 'Canal';
              final lastMsg = ch['lastMessage'] as String? ?? '';
              final isPrivate = ch['type'] == 'private';
              final members = (ch['members'] as List? ?? []).cast<String>();

              return _ChannelListTile(
                channelId: chId,
                channelData: ch,
                channelName: chName,
                lastMessage: lastMsg,
                isPrivate: isPrivate,
                memberCount: members.length,
                clubId: widget.clubId,
                uid: uid,
              );
            },
          );
        },
      ),
    );
  }
}

// Tuile de conversation style WhatsApp
class _ChannelListTile extends StatelessWidget {
  final String channelId, channelName, lastMessage, clubId, uid;
  final Map<String, dynamic> channelData;
  final bool isPrivate;
  final int memberCount;

  const _ChannelListTile({
    required this.channelId, required this.channelName, required this.lastMessage,
    required this.isPrivate, required this.memberCount, required this.clubId,
    required this.uid, required this.channelData,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPrivate ? Colors.purpleAccent : Colors.blueAccent;
    final icon = isPrivate ? Icons.person : Icons.tag;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(
          clubId: clubId, channelId: channelId,
          channelName: channelName, isPrivate: isPrivate, uid: uid,
        ),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: Row(children: [
          // Avatar du canal
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Center(child: Icon(icon, color: color, size: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(channelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (!isPrivate)
                Text('$memberCount membres',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
            const SizedBox(height: 3),
            Text(
              lastMessage.isEmpty ? 'Aucun message' : lastMessage,
              style: TextStyle(
                color: lastMessage.isEmpty ? Colors.white24 : Colors.white54,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
        ]),
      ),
    );
  }
}

// Sheet de création de canal
class _CreateChannelSheet extends StatefulWidget {
  final List<DocumentSnapshot> members;
  final String currentUid;
  const _CreateChannelSheet({required this.members, required this.currentUid});
  @override
  State<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<_CreateChannelSheet> {
  final _nameController = TextEditingController();
  final Set<String> _selectedUids = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Nouveau canal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nom du canal (ex: U13, Seniors...)',
              prefixIcon: const Icon(Icons.tag),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true, fillColor: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(alignment: Alignment.centerLeft,
              child: Text('Inviter des membres', style: TextStyle(color: Colors.white54, fontSize: 13))),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.members.length,
            itemBuilder: (context, i) {
              final data = widget.members[i].data() as Map<String, dynamic>;
              final uid = widget.members[i].id;
              final name = data['name'] as String? ?? 'Joueur';
              final selected = _selectedUids.contains(uid);
              return CheckboxListTile(
                value: selected,
                onChanged: (v) => setState(() {
                  if (v == true) _selectedUids.add(uid);
                  else _selectedUids.remove(uid);
                }),
                title: Text(name),
                subtitle: Text(data['customRole'] as String? ?? '',
                    style: TextStyle(color: roleColor(data['customRole'] as String? ?? ''), fontSize: 11)),
                secondary: CircleAvatar(
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
                activeColor: Colors.blueAccent,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context, {'name': name, 'members': _selectedUids.toList()});
              },
              child: const Text('CRÉER LE CANAL',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }
}

// Écran de chat (ouvert en navigation)
class ChatScreen extends StatefulWidget {
  final String clubId, channelId, channelName, uid;
  final bool isPrivate;
  const ChatScreen({super.key, required this.clubId, required this.channelId,
      required this.channelName, required this.isPrivate, required this.uid});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  String? _myName;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('users').doc(widget.uid).get().then((d) {
      if (mounted) setState(() => _myName = (d.data() as Map?)?['name'] as String? ?? 'Joueur');
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _myName == null) return;
    _msgController.clear();
    final ref = FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('channels').doc(widget.channelId);
    // Envoyer le message
    await ref.collection('messages').add({
      'text': text,
      'senderId': widget.uid,
      'senderName': _myName,
      'sentAt': FieldValue.serverTimestamp(),
    });
    // Mettre à jour le dernier message sur le canal
    await ref.update({
      'lastMessage': '${_myName!} : $text',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (widget.isPrivate ? Colors.purpleAccent : Colors.blueAccent).withOpacity(0.2),
            ),
            child: Center(child: Icon(
              widget.isPrivate ? Icons.person : Icons.tag,
              color: widget.isPrivate ? Colors.purpleAccent : Colors.blueAccent,
              size: 18,
            )),
          ),
          const SizedBox(width: 10),
          Text(widget.channelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clubs').doc(widget.clubId)
                .collection('channels').doc(widget.channelId)
                .collection('messages')
                .orderBy('sentAt')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 12),
                  Text('Commence la conversation dans ${widget.isPrivate ? widget.channelName : "#${widget.channelName}"}',
                      style: const TextStyle(color: Colors.white38), textAlign: TextAlign.center),
                ]));
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(_scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                }
              });
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final msg = docs[i].data() as Map<String, dynamic>;
                  final isMe = msg['senderId'] == widget.uid;
                  final showName = !widget.isPrivate && (i == 0 ||
                      (docs[i - 1].data() as Map)['senderId'] != msg['senderId']);
                  return _MessageBubble(msg: msg, isMe: isMe, showName: showName);
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ignore: unused_element
class ChatView extends StatefulWidget {
  final String clubId, channel;
  const ChatView({super.key, required this.clubId, required this.channel});
  @override
  State<ChatView> createState() => _ChatViewState();
}

// ignore: unused_element
class _ChatViewState extends State<ChatView> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe, showName;
  const _MessageBubble({required this.msg, required this.isMe, required this.showName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: showName ? 10 : 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            showName
                ? CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blueAccent.withOpacity(0.3),
                    child: Text((msg['senderName'] as String? ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)))
                : const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(msg['senderName'] ?? '',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blueAccent : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(msg['text'] ?? '', style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 4 — MEMBRES
// ══════════════════════════════════════════
class MembersTab extends StatelessWidget {
  final String clubId;
  final bool isManager;
  const MembersTab({super.key, required this.clubId, required this.isManager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Membres', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('clubId', isEqualTo: clubId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          final staff = docs.where((d) => (d.data() as Map)['role'] == 'manager').toList();
          final players = docs.where((d) => (d.data() as Map)['role'] == 'player').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader('Staff', staff.length),
              ...staff.map((d) => _MemberTile(
                  data: d.data() as Map<String, dynamic>,
                  isManager: isManager,
                  docId: d.id,
                  clubId: clubId)),
              const SizedBox(height: 16),
              _sectionHeader('Joueurs', players.length),
              ...players.map((d) => _MemberTile(
                  data: d.data() as Map<String, dynamic>,
                  isManager: isManager,
                  docId: d.id,
                  clubId: clubId)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ),
      ]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isManager;
  final String docId, clubId;
  const _MemberTile(
      {required this.data,
      required this.isManager,
      required this.docId,
      required this.clubId});

  Future<void> _changeRole(BuildContext context) async {
    final clubDoc =
        await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
    final clubData = clubDoc.data() as Map<String, dynamic>;
    final customRoles = (clubData['customRoles'] as List?)?.cast<String>() ?? [];
    final allRoles = [...kPredefinedRoles, ...customRoles];

    if (!context.mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RolePickerSheet(
          allRoles: allRoles,
          clubId: clubId,
          currentRole: data['customRole'] as String?),
    );

    if (selected != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .update({'customRole': selected});
    }
  }

  Future<void> _openPrivateChat(BuildContext context) async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final name = data['name'] as String? ?? 'Joueur';

    // Chercher si une discussion privée existe déjà entre ces deux utilisateurs
    final existing = await db
        .collection('clubs').doc(clubId)
        .collection('channels')
        .where('type', isEqualTo: 'private')
        .where('members', arrayContains: currentUid)
        .get();

    String? channelId;
    for (final doc in existing.docs) {
      final members = (doc.data()['members'] as List? ?? []).cast<String>();
      if (members.contains(docId)) {
        channelId = doc.id;
        break;
      }
    }

    // Créer la discussion privée si elle n'existe pas
    if (channelId == null) {
      final ref = await db
          .collection('clubs').doc(clubId)
          .collection('channels').add({
        'name': name,
        'type': 'private',
        'members': [currentUid, docId],
        'createdBy': currentUid,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      channelId = ref.id;
    }

    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        clubId: clubId, channelId: channelId!,
        channelName: name, isPrivate: true, uid: currentUid,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Joueur';
    final firestoreRole = data['role'] as String? ?? 'player';
    final customRole =
        data['customRole'] as String? ?? (firestoreRole == 'manager' ? 'Manager' : 'Joueur');
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final isCurrentUser = docId == currentUid;
    final color = roleColor(customRole);

    return GestureDetector(
      onTap: isCurrentUser ? null : () => _showMemberProfile(context, name, customRole, color),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isCurrentUser ? Colors.blueAccent.withOpacity(0.4) : Colors.white10),
        ),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Text(name[0].toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (isCurrentUser) ...[
                const SizedBox(width: 6),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Moi',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 10))),
              ],
            ]),
            Text(data['email'] ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ])),
          GestureDetector(
            onTap: isManager ? () => _changeRole(context) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(customRole,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                if (isManager) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 10, color: color.withOpacity(0.6)),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _showMemberProfile(BuildContext context, String name, String role, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: color.withOpacity(0.2),
            child: Text(name[0].toUpperCase(),
                style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(role, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          Text(data['email'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _openPrivateChat(context);
              },
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: const Text('Envoyer un message',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _RolePickerSheet extends StatefulWidget {
  final List<String> allRoles;
  final String clubId;
  final String? currentRole;
  const _RolePickerSheet(
      {required this.allRoles, required this.clubId, this.currentRole});

  @override
  State<_RolePickerSheet> createState() => _RolePickerSheetState();
}

class _RolePickerSheetState extends State<_RolePickerSheet> {
  final _customController = TextEditingController();
  bool _showCustomField = false;

  Future<void> _addCustomRole(String role) async {
    if (role.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).update({
      'customRoles': FieldValue.arrayUnion([role.trim()]),
    });
    if (mounted) Navigator.pop(context, role.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 24,
          left: 20,
          right: 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Changer le rôle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.allRoles.map((role) {
            final color = roleColor(role);
            final isSelected = role == widget.currentRole;
            return GestureDetector(
              onTap: () => Navigator.pop(context, role),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? color : Colors.white12),
                ),
                child: Text(role,
                    style: TextStyle(
                        color: isSelected ? color : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_showCustomField) ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: _customController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nom du rôle personnalisé',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => _addCustomRole(_customController.text),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 8),
        ] else
          TextButton.icon(
            onPressed: () => setState(() => _showCustomField = true),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Créer un rôle personnalisé'),
            style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 5 — PARAMÈTRES
// ══════════════════════════════════════════
class SettingsTab extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;
  final bool isManager;
  const SettingsTab(
      {super.key, required this.clubId, required this.userData, required this.isManager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final club = snap.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Mon profil
              _SettingsSection(title: 'Mon profil', children: [
                _InfoTile(label: 'Nom', value: userData['name'] ?? ''),
                _InfoTile(label: 'Email', value: userData['email'] ?? ''),
              ]),
              const SizedBox(height: 16),

              // Code d'invitation
              _SettingsSection(title: "Code d'invitation", children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text(
                        "Partage ce code à tes membres pour qu'ils rejoignent le club.",
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(club['clubCode'] ?? '',
                            style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4)),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Code copié !'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 1)));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.copy, color: Colors.amber, size: 20),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),

              // Infos du club
              _SettingsSection(title: 'Mon club', children: [
                _InfoTile(label: 'Nom', value: club['name'] ?? ''),
                _InfoTile(label: 'Sport', value: club['sport'] ?? ''),
                _InfoTile(label: 'Ville', value: club['city'] ?? ''),
                if ((club['description'] as String? ?? '').isNotEmpty)
                  _InfoTile(label: 'Description', value: club['description']),
              ]),
              const SizedBox(height: 16),

              // Gestion (manager seulement)
              if (isManager) ...[
                _SettingsSection(title: 'Gestion du club', children: [
                  _ActionTile(
                    icon: Icons.edit,
                    label: 'Modifier les infos du club',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF1C1C1E),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (_) => EditClubSheet(clubId: clubId, clubData: club),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
              ],

              // Déconnexion
              _SettingsSection(title: 'Compte', children: [
                _ActionTile(
                  icon: Icons.logout,
                  label: 'Se déconnecter',
                  color: Colors.redAccent,
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ]),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
      ),
      Container(
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10)),
        child: Column(children: children),
      ),
    ]);
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Flexible(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 18),
        ]),
      ),
    );
  }
}

// Sheet — Modifier le club
class EditClubSheet extends StatefulWidget {
  final String clubId;
  final Map<String, dynamic> clubData;
  const EditClubSheet({super.key, required this.clubId, required this.clubData});
  @override
  State<EditClubSheet> createState() => _EditClubSheetState();
}

class _EditClubSheetState extends State<EditClubSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _sportController;
  late final TextEditingController _cityController;
  late final TextEditingController _descController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clubData['name'] ?? '');
    _sportController = TextEditingController(text: widget.clubData['sport'] ?? '');
    _cityController = TextEditingController(text: widget.clubData['city'] ?? '');
    _descController = TextEditingController(text: widget.clubData['description'] ?? '');
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).update({
      'name': _nameController.text.trim(),
      'sport': _sportController.text.trim(),
      'city': _cityController.text.trim(),
      'description': _descController.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Modifier le club',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _field(_nameController, 'Nom du club'),
              _field(_sportController, 'Sport'),
              _field(_cityController, 'Ville'),
              _field(_descController, 'Description', maxLines: 3),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('ENREGISTRER',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05)),
      ),
    );
  }
}