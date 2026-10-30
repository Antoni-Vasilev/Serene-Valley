/// One task in the story, given by Elder Rowan.
class Quest {
  final String id;
  final int chapter;
  final String title;
  // What the elder says when offering the quest.
  final String intro;
  // What the elder says while the quest is in progress.
  final String reminder;
  // What the elder says when the player has done what he asked.
  final String ready;
  // What the elder says when the quest is handed in.
  final String done;
  final Map<String, int> requires;
  // Whether the required items are only shown, and kept.
  final bool keep;
  // Someone the player has to find.
  final String? meet;
  // The tracker's description of [meet].
  final String? meetHint;
  final int xp;

  const Quest({
    required this.id,
    required this.chapter,
    required this.title,
    required this.intro,
    required this.reminder,
    this.ready = 'You brought everything I asked for. Shall we get to work?',
    required this.done,
    this.requires = const {},
    this.keep = false,
    this.meet,
    this.meetHint,
    required this.xp,
  });

  static const bridge = 'bridge';
  static const fire = 'fire';
  static const feast = 'feast';
  static const harvest = 'harvest';
  static const light = 'light';
  static const ore = 'ore';
  static const forge = 'forge';
  static const miner = 'miner';

  static const chapterTitles = {1: 'The Valley Awakens', 2: 'The Old Mine'};

  /// What the player did in each chapter, told at its end.
  static const chapterSummaries = {
    1: 'You rebuilt the bridge, lit the village fire, fed everyone and brought in the first harvest.',
    2: 'You lit the way into the old mine, brought back iron, made the forge ring again and found Bram.',
  };

  static int get chapterCount => chapterTitles.length;

  /// Every quest, in order.
  static const List<Quest> all = [
    // Chapter 1: The Valley Awakens.
    Quest(
      id: bridge,
      chapter: 1,
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
      chapter: 1,
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
      chapter: 1,
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
      chapter: 1,
      title: 'The First Harvest',
      intro: 'Plant the seeds in the field, water them and give them time to grow. '
          'Bring me 5 carrots from your first harvest.',
      reminder: 'Water your crops each time they grow. A good night of sleep helps the field along.',
      done: "Fresh carrots! The valley is waking up again, and it's all thanks to you.",
      requires: {'carrot': 5},
      xp: 100,
    ),

    // Chapter 2: The Old Mine.
    Quest(
      id: light,
      chapter: 2,
      title: 'A Light in the Dark',
      intro: 'Our tools are worn, and the best iron in the valley lies in the old mine in the eastern hills. '
          "It has been boarded up since the storm, and it's pitch dark inside. "
          "Show me 3 torches and I'll give you the key. Pine resin and a stick make two.",
      reminder: 'Chop pine trees in the forest for resin, then craft torches from resin and sticks.',
      ready: 'Three good torches. Those will burn well down there.',
      done: 'Here is the key to the old mine. Its entrance is in the hills east of the river. '
          'Light a torch from your bag when you go in, and bring spares.',
      requires: {'torch': 3},
      keep: true,
      xp: 50,
    ),
    Quest(
      id: ore,
      chapter: 2,
      title: 'Into the Old Mine',
      intro: 'Bring me 5 iron ore from the mine. Look for rocks with rusty streaks in them.',
      reminder: 'Iron ore is deep in the mine. Keep your torches burning.',
      done: 'Real iron! With this, the old forge could ring again.',
      requires: {'iron_ore': 5},
      xp: 70,
    ),
    Quest(
      id: forge,
      chapter: 2,
      title: 'The Village Forge',
      intro: 'The old forge by the plaza needs new stones and wood. Bring 10 stone and 6 wood and we will rebuild it.',
      reminder: 'Stone from the hills, wood from the forest.',
      done: 'The forge is burning again! Smelt iron ore there, and craft iron tools. They make light work.',
      requires: {'stone': 10, 'wood': 6},
      xp: 80,
    ),
    Quest(
      id: miner,
      chapter: 2,
      title: 'The Lost Miner',
      intro: 'Old Bram, our miner, went down before the storm and never came back. '
          'If anyone can find him, it is you. Look in the deepest part of the mine.',
      reminder: 'Bram must be deep in the mine. Cobwebs and fallen rocks may block the way.',
      ready: 'Bram is home! He told me everything. You found him in the dark.',
      done: 'The forge rings, the mine is open, and Bram is safe. The valley owes you a great deal.',
      meet: 'bram',
      meetHint: 'Find Bram deep in the old mine',
      xp: 150,
    ),
  ];

  /// The quests of one chapter.
  static List<Quest> ofChapter(int chapter) => [
        for (final q in all)
          if (q.chapter == chapter) q,
      ];
}
