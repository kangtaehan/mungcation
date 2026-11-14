class Cosmetic {
  final String id, name, emoji, category;
  final int price, minLevel;
  const Cosmetic(
    this.id,
    this.name,
    this.emoji,
    this.category,
    this.price, {
    this.minLevel = 1,
  });
}

const cosmetics = [
  Cosmetic('ribbon', '핑크 리본', '🎀', '액세서리', 30),
  Cosmetic('cap', '산책 모자', '🧢', '모자', 50),
  Cosmetic('glasses', '선글라스', '🕶️', '액세서리', 70),
  Cosmetic('necklace', '산책 목걸이', '📿', '액세서리', 40),
  Cosmetic('crown', '꼬마 왕관', '👑', '모자', 100, minLevel: 2),
];
String slotFor(String id) => ['cap', 'crown'].contains(id) ? 'head' : id;

class FurnitureItem {
  final String id, name;
  final int price;
  const FurnitureItem(this.id, this.name, this.price);
}

const furnitureCatalog = [
  FurnitureItem('plant', '초록 화분', 40),
  FurnitureItem('bed', '포근 침대', 60),
  FurnitureItem('ball', '놀이 공', 20),
];
