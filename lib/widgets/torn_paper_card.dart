import 'dart:math';
import 'package:flutter/material.dart';

class TornPaperCard extends StatelessWidget {
  const TornPaperCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ), // Flatten if tearing edges
      child: ClipPath(
        clipper: DoubleTornEdgeClipper(),
        child: Container(
          color: const Color.fromARGB(255, 242, 207, 156),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class DoubleTornEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    final random = Random(42); // Seeded for visual consistency
    double step = 6.0;         // Width of each jagged tooth
    double tearDepth = 12.0;   // Maximum depth of the rips

    // --- 1. START AT TOP-LEFT & TEAR ACROSS THE TOP (Left to Right) ---
    path.moveTo(0, tearDepth);
    double currentX = 0;
    
    while (currentX < size.width) {
      currentX += step;
      double randomYFluctuation = random.nextDouble() * tearDepth;
      path.lineTo(currentX, randomYFluctuation);
    }
    
    // Ensure it perfectly hits the top-right boundary line down
    path.lineTo(size.width, tearDepth); 

    // --- 2. GO DOWN THE RIGHT SIDE ---
    path.lineTo(size.width, size.height - tearDepth);

    // --- 3. TEAR ACROSS THE BOTTOM (Right to Left) ---
    currentX = size.width;
    while (currentX > 0) {
      currentX -= step;
      double randomYFluctuation = random.nextDouble() * tearDepth;
      // Subtract the fluctuation from the max height to pull it upward
      double currentY = size.height - randomYFluctuation;
      
      path.lineTo(currentX, currentY);
    }

    // --- 4. CLOSE THE PATH ---
    path.lineTo(0, size.height - tearDepth);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}