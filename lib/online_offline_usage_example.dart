import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'connection_manager.dart';
import 'screen_status_monitor.dart';


class OnlineOfflineExample extends StatefulWidget {
  const OnlineOfflineExample({super.key});

  @override
  State<OnlineOfflineExample> createState() => _OnlineOfflineExampleState();
}

class _OnlineOfflineExampleState extends State<OnlineOfflineExample> {
  final ScreenStatusMonitor _statusMonitor = ScreenStatusMonitor();
  Map<String, String> _screenStatuses = {};
  String _selectedCategoryId = 'category_1'; // يمكن تغييرها حسب احتياجك

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() {
    _statusMonitor.startMonitoring(_selectedCategoryId, (statuses) {
      setState(() {
        _screenStatuses = statuses;
      });
    });
  }

  @override
  void dispose() {
    _statusMonitor.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراقبة حالة الشاشات'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _statusMonitor.refreshStatuses(_selectedCategoryId),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '🟢 متصل',
                    '${_statusMonitor.onlineScreensCount}',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    '🔴 غير متصل',
                    '${_statusMonitor.offlineScreensCount}',
                    Colors.red,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _screenStatuses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.display_settings, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد شاشات متاحة',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _screenStatuses.length,
                    itemBuilder: (context, index) {
                      String screenId = _screenStatuses.keys.elementAt(index);
                      String status = _screenStatuses[screenId]!;
                      
                      return _buildScreenCard(screenId, status);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              color: color.
              fontWeight 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenCard(String screenId, String status) {
    bool isOnline = status == 'online';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isOnline ? Colors.green : Colors.grey,
              radius: 20,
              child: Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          'الشاشة: $screenId',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isOnline ? 'متصل بالإنترنت' : 'غير متصل',
          style: TextStyle(
            color: isOnline ? Colors.green : Colors.grey,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOnline ? '🟢 متصل' : '🔴 غير متصل',
            style: TextStyle(
              color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

extension on Color {
  get fontWeight => FontWeight.bold;
  
  get shade50 => this.withOpacity(0.1);
  
  get shade200 => this.withOpacity(0.2);
  
  get shade700 => this.withOpacity(0.7);
}

/// كيفية استخدام هذا المثال في main.dart:
/// 
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       home: OnlineOfflineExample(),
///     );
///   }
/// }
/// 
/// أو يمكنك دمج النظام في صفحة موجودة:
/// 
/// class ExistingPage extends StatefulWidget {
///   @override
///   void initState() {
///     super.initState();
///     
///     // بدء مراقبة حالة الشاشات
///     ScreenStatusMonitor().startMonitoring(
///       'your_category_id',
///       (statuses) {
///         setState(() {
///           // تحديث الواجهة
///         });
///       },
///     );
///   }
/// } 