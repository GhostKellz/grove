class Accumulator {
  private value = 0;

  add(x: number): number {
    this.value += x;
    return this.value;
  }

  reset(): void {
    this.value = 0;
  }
}

export function evaluate(values: number[]): number {
  const acc = new Accumulator();
  let total = 0;
  for (const value of values) {
    total += acc.add(value);
  }
  acc.reset();
  return total / values.length;
}

const series = Array.from({ length: 32 }, (_, i) => i + 1);
console.log(`Average = ${evaluate(series)}`);
