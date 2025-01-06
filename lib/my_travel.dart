// my_travel.dart

import 'package:flutter/material.dart';

class MyTravelPage extends StatelessWidget {
  const MyTravelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Travel'),
        backgroundColor: Colors.deepOrange, // Adjust color as needed
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // Align children to the start
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Travel Plans',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Example Travel Entry - Replace with dynamic data
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.flight, color: Colors.deepOrange),
                title: const Text('Business Trip to New York'),
                subtitle:
                    const Text('Dates: Sep 10 - Sep 15\nStatus: Confirmed'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to Travel Details Page (to be implemented)
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => const TravelDetailsPage()));
                },
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.flight, color: Colors.deepOrange),
                title: const Text('Vacation to Hawaii'),
                subtitle: const Text(
                    'Dates: Dec 20 - Dec 30\nStatus: Pending Approval'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to Travel Details Page (to be implemented)
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => const TravelDetailsPage()));
                },
              ),
            ),
            // Add more travel entries as needed
          ],
        ),
      ),
    );
  }
}
