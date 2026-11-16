const koreaSouth = 32.5;
const koreaNorth = 38.7;
const koreaWest = 124.0;
const koreaEast = 132.0;

bool isInKorea(double latitude, double longitude) =>
    latitude >= koreaSouth &&
    latitude <= koreaNorth &&
    longitude >= koreaWest &&
    longitude <= koreaEast;
