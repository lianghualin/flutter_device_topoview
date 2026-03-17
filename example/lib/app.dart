import 'package:flutter/material.dart';

import 'package:device_topology_view/device_topology_view.dart';

import 'scenarios/scenario.dart';
import 'scenarios/sample_data.dart';
import 'controls/control_panel.dart';
import 'utils/randomizer.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentScenarioIndex = 0;
  late List<PortDevice> _allPortDevices; // full source of truth
  late Map<String, PortStatus> _portStatusMap;
  late Set<int> _baselineConnected;
  late Set<int> _exploreConnected;
  late List<PortDevice> _portDevices; // cached filtered list
  bool _isConfig = false;
  bool _enableAnimations = true;
  bool _fullMismatch = false;
  bool _showPanel = false;
  int _stackedPart = 0;
  List<String> _eventLog = [];

  int _topologyKey = 0;

  Scenario get _currentScenario => allScenarios[_currentScenarioIndex];

  /// Rebuild the cached filtered port devices list from connection state.
  void _rebuildPortDevices() {
    final List<PortDevice> result = [];
    for (int i = 0; i < _allPortDevices.length; i++) {
      if (!_baselineConnected.contains(i)) continue;

      final dev = _allPortDevices[i];
      final bool showExplore = _exploreConnected.contains(i);

      result.add(PortDevice(
        portId: dev.portId,
        deviceName: dev.deviceName,
        portNumber: dev.portNumber,
        deviceType: dev.deviceType,
        deviceIp: dev.deviceIp,
        exploreDevName: showExplore ? dev.exploreDevName : null,
        exploreDevIp: showExplore ? dev.exploreDevIp : null,
        connectionStatus: dev.connectionStatus,
        deviceStatus: dev.deviceStatus,
        exploreUtilization: showExplore ? dev.exploreUtilization : null,
      ));
    }
    _portDevices = result;
  }

  @override
  void initState() {
    super.initState();
    _loadScenario(_currentScenarioIndex);
  }

  void _loadScenario(int index) {
    final scenario = allScenarios[index];
    _currentScenarioIndex = index;
    _allPortDevices = List.of(scenario.portDevices);
    _portStatusMap = Map.of(scenario.portStatusMap);
    _baselineConnected =
        Set<int>.from(List.generate(_allPortDevices.length, (i) => i));
    _exploreConnected =
        Set<int>.from(List.generate(_allPortDevices.length, (i) => i));
    _isConfig = false;
    _eventLog = [];
    _topologyKey++;

    if (scenario.format is SwitchDeviceFormat &&
        (scenario.format as SwitchDeviceFormat).isStacked) {
      _stackedPart = 1;
    } else {
      _stackedPart = 0;
    }

    _rebuildPortDevices();
  }

  void _handleReset() {
    setState(() {
      _loadScenario(_currentScenarioIndex);
    });
  }

  void _handleRandomize() {
    setState(() {
      _portStatusMap = randomizePortStatuses(_portStatusMap);
    });
  }

  void _handleFullMismatchChanged(bool value) {
    setState(() {
      _fullMismatch = value;
      // Regenerate all devices with new mismatch mode
      final scenario = _currentScenario;
      final int count = _allPortDevices.length;
      _allPortDevices = generateDevices(
        deviceType: scenario.deviceType,
        count: count,
        fullMismatch: value,
      );
      _baselineConnected =
          Set<int>.from(List.generate(_allPortDevices.length, (i) => i));
      _exploreConnected =
          Set<int>.from(List.generate(_allPortDevices.length, (i) => i));
      _rebuildPortDevices();
    });
  }

  void _handleDeviceCountChanged(int count) {
    setState(() {
      if (count < _allPortDevices.length) {
        for (int i = count; i < _allPortDevices.length; i++) {
          _baselineConnected.remove(i);
          _exploreConnected.remove(i);
        }
        _allPortDevices = _allPortDevices.sublist(0, count);
      } else if (count > _allPortDevices.length) {
        final scenario = _currentScenario;
        final int existing = _allPortDevices.length;
        final int toAdd = count - existing;
        final List<PortDevice> newDevices = generateDevices(
          deviceType: scenario.deviceType,
          count: count,
          fullMismatch: _fullMismatch,
        ).sublist(existing);
        final added = newDevices.take(toAdd).toList();
        for (int i = 0; i < added.length; i++) {
          _baselineConnected.add(existing + i);
          _exploreConnected.add(existing + i);
        }
        _allPortDevices = [..._allPortDevices, ...added];
      }
      _rebuildPortDevices();
    });
  }

  void _handleBaselineToggled(int index, bool connected) {
    setState(() {
      if (connected) {
        _baselineConnected.add(index);
      } else {
        _baselineConnected.remove(index);
        _exploreConnected.remove(index);
      }
      _rebuildPortDevices();
    });
  }

  void _handleExploreToggled(int index, bool connected) {
    setState(() {
      if (connected) {
        _exploreConnected.add(index);
      } else {
        _exploreConnected.remove(index);
      }
      _rebuildPortDevices();
    });
  }

  void _handleShowAllExplore() {
    setState(() {
      for (int i = 0; i < _allPortDevices.length; i++) {
        if (_baselineConnected.contains(i)) {
          _exploreConnected.add(i);
        }
      }
      _rebuildPortDevices();
    });
  }

  void _handleHideAllExplore() {
    setState(() {
      _exploreConnected.clear();
      _rebuildPortDevices();
    });
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  void _handleDeviceSelected(String name, String type, int? portNum) {
    setState(() {
      _eventLog.add(
        '[${_timestamp()}] onDeviceSelected — name: $name, type: $type, port: $portNum',
      );
    });
  }

  void _handleStackedPartChanged(int part) {
    setState(() {
      _stackedPart = part;
      _eventLog.add(
        '[${_timestamp()}] onStackedSwitchPartChanged — part: $part',
      );
    });
  }

  void _handleStackedPartFromPanel(int part) {
    setState(() {
      _stackedPart = part;
      _topologyKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _currentScenario;
    final bool isStacked = scenario.format is SwitchDeviceFormat &&
        (scenario.format as SwitchDeviceFormat).isStacked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('device_topology_view'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<int>(
              value: _currentScenarioIndex,
              underline: const SizedBox.shrink(),
              items: List.generate(allScenarios.length, (i) {
                return DropdownMenuItem(
                  value: i,
                  child: Text(allScenarios[i].label),
                );
              }),
              onChanged: (index) {
                if (index != null) {
                  setState(() {
                    _loadScenario(index);
                  });
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(_showPanel ? Icons.settings : Icons.settings_outlined),
            tooltip: 'Toggle control panel',
            onPressed: () {
              setState(() {
                _showPanel = !_showPanel;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DeviceTopologyView(
                  key: ValueKey(_topologyKey),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  deviceType: scenario.deviceType,
                  format: scenario.format,
                  portDevices: _portDevices,
                  portStatusMap: _portStatusMap,
                  centerLabel: scenario.centerLabel,
                  isConfig: _isConfig,
                  enableAnimations: _enableAnimations,
                  onDeviceSelected: _handleDeviceSelected,
                  initialStackedSwitchPart: isStacked ? _stackedPart : null,
                  onStackedSwitchPartChanged: isStacked
                      ? _handleStackedPartChanged
                      : null,
                );
              },
            ),
          ),
          if (_showPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showPanel = false),
                child: Container(color: Colors.black26),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _showPanel ? 0 : -300,
            width: 300,
            child: ControlPanel(
              isConfig: _isConfig,
              onIsConfigChanged: (v) => setState(() => _isConfig = v),
              enableAnimations: _enableAnimations,
              onEnableAnimationsChanged: (v) => setState(() => _enableAnimations = v),
              fullMismatch: _fullMismatch,
              onFullMismatchChanged: _handleFullMismatchChanged,
              onRandomize: _handleRandomize,
              deviceCount: _allPortDevices.length,
              maxDevices: scenario.maxDevices,
              onDeviceCountChanged: _handleDeviceCountChanged,
              portDevices: _allPortDevices,
              baselineConnected: _baselineConnected,
              exploreConnected: _exploreConnected,
              onBaselineToggled: _handleBaselineToggled,
              onExploreToggled: _handleExploreToggled,
              onShowAllExplore: _handleShowAllExplore,
              onHideAllExplore: _handleHideAllExplore,
              onReset: _handleReset,
              eventLog: _eventLog,
              onClearLog: () => setState(() => _eventLog = []),
              deviceType: scenario.deviceType,
              isStacked: isStacked,
              stackedPart: _stackedPart,
              onStackedPartChanged: _handleStackedPartFromPanel,
            ),
          ),
        ],
      ),
    );
  }
}
