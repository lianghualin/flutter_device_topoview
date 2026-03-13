import 'package:flutter/material.dart';

import 'package:device_topology_view/device_topology_view.dart';

import 'event_log.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    required this.isConfig,
    required this.onIsConfigChanged,
    required this.onRandomize,
    required this.deviceCount,
    required this.maxDevices,
    required this.onDeviceCountChanged,
    required this.portDevices,
    required this.onDeviceStatusChanged,
    required this.onReset,
    required this.eventLog,
    required this.onClearLog,
    this.deviceType,
    this.isStacked = false,
    this.stackedPart = 1,
    this.onStackedPartChanged,
    super.key,
  });

  final bool isConfig;
  final ValueChanged<bool> onIsConfigChanged;
  final VoidCallback onRandomize;
  final int deviceCount;
  final int maxDevices;
  final ValueChanged<int> onDeviceCountChanged;
  final List<PortDevice> portDevices;
  final void Function(int index, bool status) onDeviceStatusChanged;
  final VoidCallback onReset;
  final List<String> eventLog;
  final VoidCallback onClearLog;
  final DeviceType? deviceType;
  final bool isStacked;
  final int stackedPart;
  final ValueChanged<int>? onStackedPartChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 300,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Controls',
                      style: Theme.of(context).textTheme.titleMedium),
                  OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            // Scrollable controls
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionHeader(title: 'Mode'),
                  SwitchListTile(
                    title: const Text('isConfig'),
                    subtitle: const Text('Configuration mode'),
                    value: isConfig,
                    onChanged: onIsConfigChanged,
                    dense: true,
                  ),
                  const SizedBox(height: 8),

                  _SectionHeader(title: 'Port Statuses'),
                  ElevatedButton.icon(
                    onPressed: onRandomize,
                    icon: const Icon(Icons.shuffle, size: 16),
                    label: const Text('Randomize'),
                  ),
                  const SizedBox(height: 16),

                  _SectionHeader(title: 'Device Count: $deviceCount'),
                  Slider(
                    value: deviceCount.toDouble(),
                    min: 0,
                    max: maxDevices.toDouble(),
                    divisions: maxDevices > 0 ? maxDevices : 1,
                    label: deviceCount.toString(),
                    onChanged: (v) => onDeviceCountChanged(v.round()),
                  ),
                  const SizedBox(height: 8),

                  if (deviceType == DeviceType.switch_ && isStacked) ...[
                    _SectionHeader(title: 'Stacked Part'),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('Part 1')),
                        ButtonSegment(value: 2, label: Text('Part 2')),
                      ],
                      selected: {stackedPart},
                      onSelectionChanged: (set) {
                        onStackedPartChanged?.call(set.first);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  _SectionHeader(title: 'Device Status'),
                  if (portDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No devices',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ...List.generate(portDevices.length, (i) {
                    final dev = portDevices[i];
                    return SwitchListTile(
                      title: Text(dev.deviceName, overflow: TextOverflow.ellipsis),
                      subtitle: Text(dev.deviceType, style: const TextStyle(fontSize: 11)),
                      value: dev.deviceStatus,
                      onChanged: (v) => onDeviceStatusChanged(i, v),
                      dense: true,
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: EventLog(
                entries: eventLog,
                onClear: onClearLog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
