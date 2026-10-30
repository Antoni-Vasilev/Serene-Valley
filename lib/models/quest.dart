/// One task in the chapter's quest chain, given by Elder Rowan.
class Quest {
  final String id;
  final String title;
  // What the elder says when offering the quest.
  final String intro;
  // What the elder says while the quest is in progress.
  final String reminder;
  // What the elder says when the quest is handed in.
  final String done;
  final Map<String, int> requires;
  final int xp;

  const Quest({
    required this.id,
    required this.title,
    required this.intro,
    required this.reminder,
    required this.done,
    required this.requires,
    required this.xp,
  });

  static const bridge = 'bridge';
  static const fire = 'fire';
  static const feast = 'feast';
  static const harvest = 'harvest';

  /// Chapter 1: The Valley Awakens.
  static const List<Quest> chapter = [
    Quest(
      id: bridge,
      title: 'The Broken Bridge',
      intro: 'Welcome home, friend. The great storm swept our bridge away, and the eastern hills are cut off. '
          'Bring me 10 wood and we will rebuild it together.',
      reminder: 'Chop trees with your axe and bring me the wood.',
      done: 'Wonderful! The bridge stands again. The road east is open, and the hills there are full of stone.',
      requires: {'wood': 10},
      xp: 30,
    ),
    Quest(
      id: fire,
      title: 'Warmth for the Village',
      intro: 'The nights are cold and our fire pit lies in ruins. Bring 8 stone from the eastern hills and 5 wood, '
          "and we'll light a fire for everyone.",
      reminder: 'Stone lies in the hills across the bridge. Your pickaxe will do the job.',
      done: 'Feel that warmth! You can cook on the fire, and sleep beside it at night.',
      requires: {'stone': 8, 'wood': 5},
      xp: 40,
    ),
    Quest(
      id: feast,
      title: 'A Meal for Everyone',
      intro: 'Our stores are empty. Catch fish, cook them on the fire and bring me 5 cooked fish, '
          'so the whole village can eat tonight.',
      reminder: 'Stand by the water to fish, then cook your catch on the fire.',
      done: 'What a feast! Take the old farm field south of the plaza. Here is my watering can and some carrot seeds.',
      requires: {'cooked_fish': 5},
      xp: 60,
    ),
    Quest(
      id: harvest,
      title: 'The First Harvest',
      intro: 'Plant the seeds in the field, water them and give them time to grow. '
          'Bring me 5 carrots from your first harvest.',
      reminder: 'Water your crops each time they grow. A good night of sleep helps the field along.',
      done: "Fresh carrots! The valley is waking up again, and it's all thanks to you.",
      requires: {'carrot': 5},
      xp: 100,
    ),
  ];
}
