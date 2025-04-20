import 'dart:typed_data';

// Assuming your Complex class is defined like this:
class Complex {
  final double real;
  final double imag;

  const Complex(this.real, this.imag);
}

List<Complex> convertToComplexList(Float64x2List input) {
  return List.generate(input.length, (i) {
    final real = input[i].x;
    final imag = input[i].y;
    return Complex(real, imag);
  });
}
