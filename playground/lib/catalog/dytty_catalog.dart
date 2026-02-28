import 'package:genui/genui.dart';

import 'category_card.dart';
import 'progress_card.dart';
import 'entry_tile.dart';
import 'empty_banner.dart';

/// All Dytty-specific catalog items for the AI to use.
final dyttyCatalogItems = [
  categoryCardItem,
  progressCardItem,
  entryTileItem,
  emptyBannerItem,
];

/// Core catalog extended with Dytty widgets.
Catalog get dyttyCatalog =>
    CoreCatalogItems.asCatalog().copyWith(dyttyCatalogItems);
