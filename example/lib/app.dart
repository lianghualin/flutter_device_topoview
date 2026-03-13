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
  late List<PortDevice> _portDevices;
  late Map<String, PortStatus> _portStatusMap;
  bool _isConfig = false;
  bool _showPanel = false;
  int _stackedPart = 0;
  List<String> _eventLog = [];

  int _topologyKey = 0;

  Scenario get _currentScenario => allScenarios[_currentScenarioIndex];

  @override
  void initState() {
    super.initState();
    _loadScenario(_currentScenarioIndex);
  }

  void _loadScenario(int index) {
    final scenario = allScenarios[index];
    _currentScenarioIndex = index;
    _portDevices = List.of(scenario.portDevices);
    _portStatusMap = Map.of(scenario.portStatusMap);
    _isConfig = false;
    _eventLog = [];
    _topologyKey++;

    if (scenario.format is SwitchDeviceFormat &&
        (scenario.format as SwitchDeviceFormat).isStacked) {
      _stackedPart = 1;
    } else {
      _stackedPart = 0;
    }
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

  void _handleDeviceCountChanged(int count) {
    setState(() {
      if (count < _portDevices.length) {
        _portDevices = _portDevices.sublist(0, count);
      } else if (count > _portDevices.length) {
        final scenario = _currentScenario;
        final int existing = _portDevices.length;
        final int toAdd = count - existing;
        List<PortDevice> newDevices;
        switch (scenario.deviceType) {
          case DeviceType.host:
            newDevices = generateHostDevices(count).sublist(existing);
            break;
          case DeviceType.dpu:
            newDevices = generateDpuDevices(count).sublist(existing);
            break;
          case DeviceType.switch_:
            newDevices = generateSwitchDevices(count).sublist(existing);
            break;
        }
        _portDevices = [..._portDevices, ...newDevices.take(toAdd)];
      }
    });
  }

  void _handleDeviceStatusChanged(int index, bool status) {
    setState(() {
      final dev = _portDevices[index];
      _portDevices[index] = PortDevice(
        portId: dev.portId,
        deviceName: dev.deviceName,
        portNumber: dev.portNumber,
        deviceType: dev.deviceType,
        deviceIp: dev.deviceIp,
        exploreDevName: dev.exploreDevName,
        exploreDevIp: dev.exploreDevIp,
        connectionStatus: dev.connectionStatus,
        deviceStatus: status,
      );
    });
  }

  void _handleDeviceSelected(String name, String type, int? portNum) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _eventLog.add(
        '[$timestamp] onDeviceSelected — name: $name, type: $type, port: $portNum',
      );
    });
  }

  void _handleStackedPartChanged(int part) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _stackedPart = part;
      _eventLog.add(
        '[$timestamp] onStackedSwitchPartChanged — part: $part',
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
              onRandomize: _handleRandomize,
              deviceCount: _portDevices.length,
              maxDevices: scenario.maxDevices,
              onDeviceCountChanged: _handleDeviceCountChanged,
              portDevices: _portDevices,
              onDeviceStatusChanged: _handleDeviceStatusChanged,
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
