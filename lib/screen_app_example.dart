import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'connection_manager.dart';

class ScreenAppExample extends StatefulWidget {
  const ScreenAppExample({super.key});

  @override
  State<ScreenAppExample> createState() => _ScreenAppExampleState();
}

class _ScreenAppExampleState extends State<ScreenAppExample> {
  final ConnectionManager _connectionManager = ConnectionManager();
  bool _isOnline = false;
  String _screenId = 'screen_example_001'; // معرف الشاشة

  @override
  void initState() {
    super.initState();
    _initializeConnectionManager();
  }

  Future<void> _initializeConnectionManager() async {
   
    await _connectionManager.initialize(_screenId);
    
    
    bool hasConnection = await _connectionManager.checkConnection();
    setState(() {
      _isOnline = hasConnection;
    });
  }

  @override
  void dispose() {
    _connectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('screen_app_title'.tr()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.wifi : Icons.wifi_off),
            onPressed: () async {
             
              await _connectionManager.forceUpdate();
              bool hasConnection = await _connectionManager.checkConnection();
              setState(() {
                _isOnline = hasConnection;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isOnline ? Colors.green : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (_isOnline ? Colors.green : Colors.red).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                size: 80,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 30),
            
            Text(
              _isOnline ? 'online_status'.tr() : 'offline_status'.tr(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isOnline ? Colors.green : Colors.red,
              ),
            ),
            
            const SizedBox(height: 10),
            
            Text(
              _isOnline ? 'connected'.tr() : 'not_connected'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 30),
            
            Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'screen_info'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('screen_id'.tr() + ': $_screenId'),
                    Text('last_update'.tr() + ': ${DateTime.now().toString()}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: () async {
                await _connectionManager.forceUpdate();
                bool hasConnection = await _connectionManager.checkConnection();
                setState(() {
                  _isOnline = hasConnection;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('status_updated'.tr()),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: Text('refresh_status'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 