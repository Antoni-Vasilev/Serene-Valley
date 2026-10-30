/// A carrot growing on one farmland tile.
///
/// A crop advances one stage after it has been watered and then left to
/// grow for [hoursPerStage] in-game hours. Each stage needs fresh water.
class Crop {
  static const int ripeStage = 3;
  static const double hoursPerStage = 3;

  int stage;
  bool watered;
  // In-game hours grown since the last watering.
  double growth;

  Crop({this.stage = 0, this.watered = false, this.growth = 0});

  bool get isRipe => stage >= ripeStage;

  /// Grows the crop by [hours] in-game hours.
  void advance(double hours) {
    if (!watered || isRipe) return;
    growth += hours;
    if (growth >= hoursPerStage) {
      stage++;
      watered = false;
      growth = 0;
    }
  }

  List<num> toJson() => [stage, watered ? 1 : 0, growth];

  factory Crop.fromJson(List<dynamic> json) => Crop(
        stage: (json[0] as num).toInt(),
        watered: json[1] == 1,
        growth: (json[2] as num).toDouble(),
      );
}
