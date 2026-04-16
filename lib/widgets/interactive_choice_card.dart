import 'package:flutter/material.dart';

/// InteractiveChoiceCard
/// ----------------------
/// A clickable, animated card:
/// - Hover: scales up (nice desktop/web effect)
/// - Tap: triggers onTap and shows ripple effect
///
/// IMPORTANT:
/// - InkWell must be inside a Material widget to show ripple
/// - MouseRegion only handles hover; it does NOT handle tap
class InteractiveChoiceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const InteractiveChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<InteractiveChoiceCard> createState() => _InteractiveChoiceCardState();
}

class _InteractiveChoiceCardState extends State<InteractiveChoiceCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),

      // AnimatedScale gives the “comes closer” effect on hover
      child: AnimatedScale(
        scale: isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,

        // AnimatedContainer controls elevation/shadow smoothly
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isHovered ? 0.15 : 0.08),
                blurRadius: isHovered ? 20 : 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),

          // Material is REQUIRED for InkWell ripple + tap detection
          child: Material(
            color: widget.color,
            borderRadius: BorderRadius.circular(18),

            // InkWell makes the card actually clickable
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                debugPrint("Tapped: ${widget.title}");
                widget.onTap();
              },

              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 38, color: Colors.green),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 28,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
