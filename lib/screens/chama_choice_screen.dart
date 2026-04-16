import 'package:flutter/material.dart';
import 'package:kaya/widgets/interactive_choice_card.dart';

class ChamaChoicePage extends StatelessWidget {
  const ChamaChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Welcome to Kaya",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Choose how you want to continue",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 40),

                InteractiveChoiceCard(
                  icon: Icons.group_add,
                  title: "Create Chama",
                  subtitle: "Start a new chama with members",
                  color: Colors.white,
                  onTap: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/createChama',
                    );

                    if (context.mounted &&
                        result is Map &&
                        result["created"] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result["message"]?.toString() ?? "Chama created",
                          ),
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 20),

                InteractiveChoiceCard(
                  icon: Icons.login,
                  title: "Join Chama",
                  subtitle: "Join an existing chama",
                  color: Colors.white,
                  onTap: () {
                    Navigator.pushNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
