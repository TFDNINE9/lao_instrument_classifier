# Lao Instrument Classifier App

A Flutter application that can identify traditional Lao musical instruments in real-time using TensorFlow Lite and audio signal processing.

## Features

- **Real-time Audio Classification**: Record and analyze audio to identify Lao musical instruments
- **Unknown Sound Detection**: Detect when sounds don't match known instruments using confidence and entropy thresholds
- **Detailed Analysis**: View confidence scores, spectrograms, and technical details
- **Educational Content**: Learn about traditional Lao instruments and their characteristics

## Supported Instruments

- **Khaen**: A mouth organ made of bamboo pipes
- **So U**: A bowed string instrument with coconut shell resonator
- **Sing**: A small cymbal-like percussion instrument
- **Pin**: A plucked string instrument with coconut shell resonator
- **Khong Wong**: A circular arrangement of small gongs
- **Ranad**: A wooden xylophone with bamboo resonators

## Installation

### Prerequisites

- Flutter SDK (2.10.0 or higher)
- Android Studio / Xcode
- Device with microphone permissions

### Setup

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/lao_instrument_classifier.git
   cd lao_instrument_classifier
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Create assets directory structure:
   ```
   mkdir -p assets/model
   mkdir -p assets/images
   mkdir -p assets/test_audio
   ```

4. Add TensorFlow Lite model to `assets/model/`:
   - Copy `lao_instruments_model_quantized.tflite` to `assets/model/`
   - Create `label_encoder.txt` with instrument names (one per line)

5. Add instrument images to `assets/images/`:
   - Add images for each instrument: `khaen.png`, `so_u.png`, etc.

6. Run the application:
   ```
   flutter run
   ```

## Usage

1. **Start the App**: Launch the app and grant microphone permissions
2. **Record Audio**: Tap the microphone button to start recording
3. **View Results**: See real-time classification results with confidence scores
4. **Explore Details**: Tap on results to see detailed information about the instrument

## Implementation Details

### Audio Processing Pipeline

1. **Audio Capture**: Records audio using the device microphone at 44.1kHz
2. **Feature Extraction**: Computes Mel spectrograms from audio frames
3. **Model Inference**: Feeds features to a TensorFlow Lite model for classification
4. **Unknown Detection**: Uses confidence threshold and entropy to identify unknown sounds
5. **Result Display**: Shows classification results with confidence metrics

### Performance Optimizations

- Uses isolates for computation-intensive tasks
- Implements circular buffer for audio processing
- Quantized TensorFlow Lite model for mobile optimization
- Efficient feature extraction with minimal memory allocation

## Troubleshooting

- **Microphone Permission Issues**: Ensure your device has granted microphone permissions
- **Classification Errors**: Try recording in a quiet environment with minimal background noise
- **Performance Issues**: Close background apps to free up device resources

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the NUOL License - see the LICENSE file for details.