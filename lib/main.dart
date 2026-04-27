import 'package:flutter/material.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<_HomeCard> _cards = [
    _HomeCard(
      title: 'Balance',
      icon: Icons.account_balance_wallet_outlined,
      color: Colors.deepPurple,
    ),
    _HomeCard(
      title: 'Income',
      icon: Icons.trending_up,
      color: Colors.green,
    ),
    _HomeCard(
      title: 'Expenses',
      icon: Icons.trending_down,
      color: Colors.redAccent,
    ),
    _HomeCard(
      title: 'Budget',
      icon: Icons.savings_outlined,
      color: Colors.orange,
    ),
    _HomeCard(
      title: 'Categories',
      icon: Icons.category_outlined,
      color: Colors.teal,
    ),
    _HomeCard(
      title: 'Transactions',
      icon: Icons.receipt_long_outlined,
      color: Colors.blue,
    ),
    _HomeCard(
      title: 'Reports',
      icon: Icons.bar_chart_outlined,
      color: Colors.indigo,
    ),
    _HomeCard(
      title: 'Settings',
      icon: Icons.settings_outlined,
      color: Colors.blueGrey,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: _cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) => _cards[index],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
