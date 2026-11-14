import 'saved_place.dart';
import 'walk_data.dart';

class WalletEntry {
  final String title;
  final int amount;
  final DateTime date;
  WalletEntry(this.title, this.amount, this.date);
  Map<String, dynamic> toJson() => {
    'title': title,
    'amount': amount,
    'date': date.toIso8601String(),
  };
  factory WalletEntry.fromJson(Map<String, dynamic> json) => WalletEntry(
    json['title'] as String,
    json['amount'] as int,
    DateTime.parse(json['date'] as String),
  );
}

class DemoWalk {
  final DateTime date;
  final int seconds, points;
  final List<String> visits;
  DemoWalk(this.date, this.seconds, this.points, this.visits);
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'seconds': seconds,
    'points': points,
    'visits': visits,
  };
  factory DemoWalk.fromJson(Map<String, dynamic> json) => DemoWalk(
    DateTime.parse(json['date'] as String),
    json['seconds'] as int,
    json['points'] as int,
    List<String>.from(json['visits'] as List),
  );
}

class PetProfile {
  final String name, breed, size, temperament, photo, pixelPhoto, character;
  final int age;
  final double weight;
  const PetProfile({
    required this.name,
    this.breed = '',
    this.photo = '',
    this.pixelPhoto = '',
    this.character = 'original',
    this.age = 0,
    this.weight = 0,
    this.size = '소형견',
    this.temperament = '보통',
  });
  PetProfile copyWith({String? photo, String? pixelPhoto}) => PetProfile(
    name: name,
    breed: breed,
    size: size,
    temperament: temperament,
    photo: photo ?? this.photo,
    pixelPhoto: pixelPhoto ?? this.pixelPhoto,
    character: character,
    age: age,
    weight: weight,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'photo': photo,
    'pixelPhoto': pixelPhoto,
    'character': character,
    'breed': breed,
    'age': age,
    'weight': weight,
    'size': size,
    'temperament': temperament,
  };
  factory PetProfile.fromJson(Map<String, dynamic> json) => PetProfile(
    name: json['name'] as String,
    photo: json['photo'] as String? ?? '',
    pixelPhoto: json['pixelPhoto'] as String? ?? '',
    character: json['character'] as String? ?? 'original',
    breed: json['breed'] as String,
    age: json['age'] as int,
    weight: (json['weight'] as num).toDouble(),
    size: json['size'] as String,
    temperament: json['temperament'] as String,
  );
}

class AppData {
  final PetProfile? pet;
  final int coins, xp;
  final Set<String> owned, equipment;
  final Map<String, List<double>> furniture;
  final List<WalletEntry> wallet;
  final List<DemoWalk> walks;
  final List<WalkRecord> realWalks;
  final WalkDraft? draft;
  final Map<String, String> rewardedPlaces;
  final Map<String, int> dailyRewards;
  final bool backgroundLocation;
  final Map<String, SavedPlace> savedPlaces;
  String get equipped => equipment.firstOrNull ?? 'none';
  int get level => 1 + xp ~/ 100;
  AppData({
    this.pet,
    this.coins = 20,
    this.xp = 0,
    Set<String>? owned,
    String equipped = 'none',
    Set<String>? equipment,
    Map<String, List<double>>? furniture,
    List<WalletEntry>? wallet,
    List<DemoWalk>? walks,
    List<WalkRecord>? realWalks,
    this.draft,
    Map<String, String>? rewardedPlaces,
    Map<String, int>? dailyRewards,
    this.backgroundLocation = false,
    Map<String, SavedPlace>? savedPlaces,
  }) : owned = Set.unmodifiable(owned ?? {}),
       equipment = Set.unmodifiable(
         equipment ?? (equipped == 'none' ? <String>{} : {equipped}),
       ),
       furniture = Map.unmodifiable(
         (furniture ?? {}).map(
           (k, v) => MapEntry(k, List<double>.unmodifiable(v)),
         ),
       ),
       wallet = List.unmodifiable(
         wallet ?? [WalletEntry('시작 선물 · 체험 포인트', 20, DateTime.now())],
       ),
       walks = List.unmodifiable(walks ?? []),
       realWalks = List.unmodifiable(realWalks ?? []),
       rewardedPlaces = Map.unmodifiable(rewardedPlaces ?? {}),
       dailyRewards = Map.unmodifiable(dailyRewards ?? {}),
       savedPlaces = Map.unmodifiable(savedPlaces ?? {});
  AppData copyWith({
    PetProfile? pet,
    int? coins,
    int? xp,
    Set<String>? owned,
    String? equipped,
    Set<String>? equipment,
    Map<String, List<double>>? furniture,
    List<WalletEntry>? wallet,
    List<DemoWalk>? walks,
    List<WalkRecord>? realWalks,
    WalkDraft? draft,
    bool clearDraft = false,
    Map<String, String>? rewardedPlaces,
    Map<String, int>? dailyRewards,
    bool? backgroundLocation,
    Map<String, SavedPlace>? savedPlaces,
  }) => AppData(
    pet: pet ?? this.pet,
    coins: coins ?? this.coins,
    xp: xp ?? this.xp,
    owned: owned ?? this.owned,
    equipment:
        equipment ??
        (equipped == null
            ? this.equipment
            : equipped == 'none'
            ? <String>{}
            : {equipped}),
    furniture: furniture ?? this.furniture,
    wallet: wallet ?? this.wallet,
    walks: walks ?? this.walks,
    realWalks: realWalks ?? this.realWalks,
    draft: clearDraft ? null : draft ?? this.draft,
    rewardedPlaces: rewardedPlaces ?? this.rewardedPlaces,
    dailyRewards: dailyRewards ?? this.dailyRewards,
    backgroundLocation: backgroundLocation ?? this.backgroundLocation,
    savedPlaces: savedPlaces ?? this.savedPlaces,
  );
  Map<String, dynamic> toJson() => {
    'version': 3,
    'savedPlaces': savedPlaces.map((k, v) => MapEntry(k, v.toJson())),
    'pet': pet?.toJson(),
    'coins': coins,
    'xp': xp,
    'owned': owned.toList(),
    'equipped': equipped,
    'equipment': equipment.toList(),
    'furniture': furniture,
    'wallet': wallet.map((e) => e.toJson()).toList(),
    'walks': walks.map((e) => e.toJson()).toList(),
    'realWalks': realWalks.map((e) => e.toJson()).toList(),
    'draft': draft?.toJson(),
    'rewardedPlaces': rewardedPlaces,
    'dailyRewards': dailyRewards,
    'backgroundLocation': backgroundLocation,
  };
  factory AppData.fromJson(Map<String, dynamic> j) {
    if (![1, 2, 3].contains(j['version']))
      throw const FormatException('지원하지 않는 저장 형식');
    final owned = Set<String>.from(j['owned'] as List),
        equipment = j['equipment'] == null
            ? (j['equipped'] == 'none' ? <String>{} : {j['equipped'] as String})
            : Set<String>.from(j['equipment'] as List);
    final coins = j['coins'] as int;
    if (coins < 0 || !owned.containsAll(equipment))
      throw const FormatException('잘못된 지갑 데이터');
    return AppData(
      pet: j['pet'] == null
          ? null
          : PetProfile.fromJson(Map<String, dynamic>.from(j['pet'])),
      coins: coins,
      xp: j['xp'] as int? ?? 0,
      owned: owned,
      equipment: equipment,
      furniture: (j['furniture'] as Map? ?? {}).map(
        (k, v) => MapEntry(
          k as String,
          List<double>.from((v as List).map((e) => (e as num).toDouble())),
        ),
      ),
      wallet: (j['wallet'] as List)
          .map((e) => WalletEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      walks: (j['walks'] as List)
          .map((e) => DemoWalk.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      realWalks: (j['realWalks'] as List? ?? [])
          .map((e) => WalkRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      draft: j['draft'] == null
          ? null
          : WalkDraft.fromJson(Map<String, dynamic>.from(j['draft'])),
      rewardedPlaces: Map<String, String>.from(
        j['rewardedPlaces'] as Map? ?? {},
      ),
      dailyRewards: Map<String, int>.from(j['dailyRewards'] as Map? ?? {}),
      backgroundLocation: j['backgroundLocation'] == true,
      savedPlaces: (j['savedPlaces'] as Map? ?? {}).map((key, value) {
        final saved = SavedPlace.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        if (key != saved.place.id) throw const FormatException('즐겨찾기 식별자 불일치');
        return MapEntry(key as String, saved);
      }),
    );
  }
}
