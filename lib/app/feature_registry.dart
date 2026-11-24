import 'app_scope.dart';

/// One feature of the app. The sidebar, the Edge swipe tabs, Home and Settings read from
/// this list, so adding a page means adding one entry (plus its page widget).
class FeatureDescriptor {
  const FeatureDescriptor(this.page, {this.edgeTab = false});

  final PageId page;

  /// Part of Edge's swipe-tab set. Calendar, Weather, Shortcuts and GitHub are registered
  /// but not Edge tabs yet (not designed).
  final bool edgeTab;

  String get label => page.label;
}

const featureRegistry = <FeatureDescriptor>[
  FeatureDescriptor(PageId.home, edgeTab: true),
  FeatureDescriptor(PageId.claude, edgeTab: true),
  FeatureDescriptor(PageId.music, edgeTab: true),
  FeatureDescriptor(PageId.system, edgeTab: true),
  FeatureDescriptor(PageId.control, edgeTab: true),
  FeatureDescriptor(PageId.timer, edgeTab: true),
  FeatureDescriptor(PageId.calendar),
  FeatureDescriptor(PageId.weather),
  FeatureDescriptor(PageId.shortcuts),
  FeatureDescriptor(PageId.github),
  FeatureDescriptor(PageId.settings, edgeTab: true),
];

/// Edge tabs in order. Settings is always last, wherever the registry lists it.
List<PageId> edgeTabs([List<FeatureDescriptor> registry = featureRegistry]) {
  final tabs = [
    for (final f in registry)
      if (f.edgeTab && f.page != PageId.settings) f.page,
  ];
  if (registry.any((f) => f.edgeTab && f.page == PageId.settings)) tabs.add(PageId.settings);
  return tabs;
}

/// The pages in a sidebar (Color Blocks, Paper): the designed ones in tab order, Settings is pinned apart.
/// Pages that aren't designed yet stay in the registry and are listed under Settings → Sidebar.
List<PageId> sidebarPages([List<FeatureDescriptor> registry = featureRegistry]) => [
  for (final p in edgeTabs(registry))
    if (p != PageId.settings) p,
];

/// Registered pages that aren't designed yet (listed under Settings → Sidebar for future work).
List<PageId> futurePages([List<FeatureDescriptor> registry = featureRegistry]) => [
  for (final f in registry)
    if (!f.edgeTab) f.page,
];
