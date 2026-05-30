import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../main.dart';
import '../../../config/presentation/pages/config_page.dart';
import '../../../download/presentation/pages/download_page.dart';
import '../../../download/presentation/providers/download_provider.dart';
import '../../../upload/presentation/pages/upload_page.dart';

/// Main app shell with bottom navigation.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    pendingUploadTick.addListener(_onPendingUpload);
  }

  @override
  void dispose() {
    pendingUploadTick.removeListener(_onPendingUpload);
    super.dispose();
  }

  void _onPendingUpload() {
    if (_currentIndex != 0 && mounted) {
      setState(() => _currentIndex = 0);
    }
  }

  void _onTabChanged(int index) {
    setState(() => _currentIndex = index);
    // Auto-refresh cloud files when switching to download tab
    if (index == 1) {
      ref.read(downloadProvider.notifier).refreshCloudFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          UploadPage(),
          DownloadPage(),
          ConfigPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_upload_outlined),
            selectedIcon: Icon(Icons.cloud_upload),
            label: '上传',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_download_outlined),
            selectedIcon: Icon(Icons.cloud_download),
            label: '下载',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
