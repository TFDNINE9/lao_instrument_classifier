class Instrument {
  final String id;
  final String name;
  final String description;
  final String imagePath;
  final bool isUnknown;

  Instrument({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    this.isUnknown = false,
  });

  // Factory to create an unknown instrument
  factory Instrument.unknown() {
    return Instrument(
      id: 'unknown',
      name: 'Unknown',
      description:
          'This sound doesn\'t match any known Lao musical instrument.',
      imagePath: 'assets/images/unknown.png',
      isUnknown: true,
    );
  }

  static List<Instrument> getLaoInstruments() {
    return [
      Instrument(
        id: 'khaen',
        name: 'Khaen',
        description:
            'A mouth organ made of bamboo pipes, each with a metal reed.',
        imagePath: 'assets/images/khaen.png',
      ),
      Instrument(
        id: 'so_u',
        name: 'So U',
        description:
            'A bowed string instrument with a resonator made from a coconut shell.',
        imagePath: 'assets/images/so_u.png',
      ),
      Instrument(
        id: 'sing',
        name: 'Sing',
        description:
            'A small cymbal-like percussion instrument used in ensembles.',
        imagePath: 'assets/images/sing.png',
      ),
      Instrument(
        id: 'pin',
        name: 'Pin',
        description:
            'A plucked string instrument with a resonator made from coconut shell.',
        imagePath: 'assets/images/pin.png',
      ),
      Instrument(
        id: 'khong_wong',
        name: 'Khong Wong',
        description: 'A circular arrangement of small gongs in a wooden frame.',
        imagePath: 'assets/images/khong_wong.png',
      ),
      Instrument(
        id: 'ranad',
        name: 'Ranad',
        description: 'A wooden xylophone with bamboo resonators underneath.',
        imagePath: 'assets/images/ranad.png',
      ),
    ];
  }

  // Find an instrument by ID
  static Instrument? findById(String id) {
    try {
      return getLaoInstruments()
          .firstWhere((instrument) => instrument.id == id);
    } catch (e) {
      return null;
    }
  }
}
